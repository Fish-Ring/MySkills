-- 通用学习助手 v1.3.1 - 常用 SQL 模板
-- 用法：sqlite3 -json <技能目录>/learner.db "<语句>"
-- 约定：KW = 关键词；NOW = strftime('%s','now')；间隔秒数 [86400,172800,345600,691200,1382400]
--       mastery_level = -1（COALESCE 兜底）表示从未练习
-- 铁律：任何 INSERT 前必须先跑对应查重语句；
--       文本值中的单引号必须写成两个 '' 再拼入 SQL（It's → 'It''s'）

-- ============ 查重三件套（INSERT 前必跑） ============
-- ① 科目查重
SELECT id, name, full_name FROM subjects WHERE name = '科目名';
-- ② 知识点查重（含关键词模糊命中）
SELECT t.id, t.name, s.name AS subject
FROM topics t JOIN subjects s ON s.id = t.subject_id
WHERE (t.subject_id = 科目ID AND t.name LIKE '%知识点%')
   OR t.keywords LIKE '%关键词%'
ORDER BY t.exam_weight DESC LIMIT 5;
-- ③ 问题查重
SELECT id, times_asked FROM questions WHERE question = '问题原文';

-- ============ 幂等写入模板 ============
-- 建科目（已存在则忽略）
INSERT OR IGNORE INTO subjects (name, full_name, weight) VALUES ('数学二', '考研数学二', 1.5);
-- 建知识点（同科目同名唯一，冲突自动忽略）
INSERT OR IGNORE INTO topics (subject_id, name, keywords, exam_weight)
VALUES (科目ID, '知识点名', '别名1,别名2', 3.0);
-- 记问题：冲突则次数+1并刷新时间（SQLite ≥ 3.24）
INSERT INTO questions (subject_id, topic_id, question, answer_digest, technique)
VALUES (科目ID, 知识点ID, '问题原文', '解答要点', '答题技巧')
ON CONFLICT(question) DO UPDATE SET
    times_asked = times_asked + 1,
    last_asked_at = CURRENT_TIMESTAMP,
    answer_digest = excluded.answer_digest;
-- 补充知识点关键词（幂等：已含则不动；兼容空串不产生尾逗号）
UPDATE topics SET keywords = CASE WHEN keywords = '' OR keywords IS NULL THEN '新别名' ELSE '新别名,' || keywords END
WHERE id = 知识点ID AND (',' || COALESCE(keywords,'') || ',') NOT LIKE '%,新别名,%';
-- 错题查重（UNIQUE 含可空列，NULL 互不相等，必须先查后插）
SELECT id, mistake_count FROM mistakes
WHERE topic_id = 知识点ID AND question = '题目'
  AND COALESCE(wrong_answer,'') = COALESCE('错误答案','')
  AND COALESCE(correct_answer,'') = COALESCE('正确答案','');
-- 记错题（查重无命中再插入）
INSERT OR IGNORE INTO mistakes (topic_id, question, wrong_answer, correct_answer, explanation)
VALUES (知识点ID, '题目', '错误答案', '正确答案', '解析');
-- 掌握度 upsert·做错（wrong_count+1；首次自动建行）
INSERT INTO progress (topic_id, correct_count, wrong_count, last_practice_at)
VALUES (知识点ID, 0, 1, CURRENT_TIMESTAMP)
ON CONFLICT(topic_id) DO UPDATE SET
    wrong_count = wrong_count + 1, last_practice_at = CURRENT_TIMESTAMP;
-- 掌握度 upsert·自评已懂（correct_count+1）
INSERT INTO progress (topic_id, correct_count, wrong_count, last_practice_at)
VALUES (知识点ID, 1, 0, CURRENT_TIMESTAMP)
ON CONFLICT(topic_id) DO UPDATE SET
    correct_count = correct_count + 1, last_practice_at = CURRENT_TIMESTAMP;

-- ============ 检索（回答前必跑） ============
-- 相似历史问题（含次数，命中说明问过）
SELECT q.id, q.question, q.times_asked, q.answer_digest, t.name AS topic
FROM questions q LEFT JOIN topics t ON t.id = q.topic_id
WHERE q.question LIKE '%KW%' ORDER BY q.times_asked DESC, q.last_asked_at DESC LIMIT 10;
-- 相关薄弱点 TopN（错误多/掌握度低优先）
SELECT t.id, t.name, s.name AS subject,
       COALESCE(p.wrong_count, 0) AS wc, COALESCE(p.correct_count, 0) AS cc,
       ROUND(COALESCE(p.mastery_level, 0), 2) AS mastery
FROM topics t JOIN subjects s ON s.id = t.subject_id
LEFT JOIN progress p ON p.topic_id = t.id
WHERE t.name LIKE '%KW%' OR t.keywords LIKE '%KW%' OR s.name LIKE '%KW%'
ORDER BY COALESCE(p.wrong_count, -1) DESC, COALESCE(p.mastery_level, 99) ASC LIMIT 10;
-- 全局薄弱点 TopN（复习/总结用；把 10 改成想要的条数）
SELECT t.name AS 知识点, s.name AS 科目, p.wrong_count, p.correct_count,
       ROUND(p.mastery_level, 2) AS mastery
FROM progress p JOIN topics t ON t.id = p.topic_id JOIN subjects s ON s.id = t.subject_id
WHERE p.wrong_count > p.correct_count OR p.mastery_level < 0.6
ORDER BY p.mastery_level ASC, p.wrong_count DESC LIMIT 10;

-- ============ 艾宾浩斯复习队列 ============
-- 加入队列（复用未完成行防累积）
INSERT INTO review_queue (topic_id, stage, next_review_at, is_reviewed)
SELECT 知识点ID, 1, strftime('%s','now') + 86400, 0
WHERE NOT EXISTS (SELECT 1 FROM review_queue WHERE topic_id = 知识点ID AND is_reviewed = 0);
-- 到期任务
SELECT rq.id, rq.topic_id, t.name AS 知识点, s.name AS 科目, rq.stage
FROM review_queue rq JOIN topics t ON t.id = rq.topic_id JOIN subjects s ON s.id = t.subject_id
WHERE rq.is_reviewed = 0 AND rq.next_review_at <= strftime('%s','now')
ORDER BY rq.next_review_at ASC;
-- 复习完成（把 1/0 替换为答对与否）：答对升档、答错回 Stage1；Stage5 答对标记完成
-- 新间隔按新阶段取值：1天/2天/4天/8天/16天 = 86400/172800/345600/691200/1382400 秒
UPDATE review_queue SET
    stage = CASE WHEN 答对 THEN MIN(stage + 1, 5) ELSE 1 END,
    is_reviewed = CASE WHEN stage >= 5 AND 答对 THEN 1 ELSE 0 END,
    next_review_at = CASE
        WHEN stage >= 5 AND 答对 THEN next_review_at
        WHEN NOT 答对 THEN strftime('%s','now') + 86400
        ELSE strftime('%s','now') + CASE MIN(stage + 1, 5)
             WHEN 2 THEN 172800 WHEN 3 THEN 345600 WHEN 4 THEN 691200 WHEN 5 THEN 1382400
             ELSE 86400 END
    END
WHERE id = 队列行ID;

-- 可选清理：完成超过 90 天的旧队列行删除，防表膨胀（按需执行）
-- DELETE FROM review_queue WHERE is_reviewed = 1 AND next_review_at < strftime('%s','now') - 7776000;

-- ============ 日志与统计 ============
-- 记一笔（当日同类型自动累计）
INSERT INTO history_logs (date, type, count) VALUES (date('now','localtime'), 'qa', 1)
ON CONFLICT(date, type) DO UPDATE SET count = count + 1;
-- 今日统计
SELECT type, SUM(count) AS n FROM history_logs WHERE date = date('now','localtime') GROUP BY type;
-- 总览
SELECT (SELECT COUNT(*) FROM subjects) AS subjects,
       (SELECT COUNT(*) FROM topics) AS topics,
       (SELECT COUNT(*) FROM questions) AS questions,
       (SELECT COUNT(*) FROM mistakes) AS mistakes,
       (SELECT COUNT(*) FROM review_queue WHERE is_reviewed = 0) AS queue_size;

-- ============ 旧库升级（初始化扫描到旧 learner.db 时按需执行） ============
-- 检测缺列：PRAGMA table_info(topics);  若无 keywords 列：
ALTER TABLE topics ADD COLUMN keywords TEXT DEFAULT '';
-- 检测缺表：对照 schemas/schema.sql，缺哪张补哪张（questions/history_logs 最常见）；
-- 全部补齐后再跑一次 schema.sql 确认索引齐全。
