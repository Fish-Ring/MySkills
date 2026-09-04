-- 通用学习助手 v1.4.2 - 常用 SQL 模板（分页+统计+tag专业名词）
-- 用法：sqlite3 -json <技能目录>/learner.db "<语句>"
-- 约定：' 拼入前写成 ''；先查重→相似查→自动合并后写入；tag 必须是专业名词（禁止句子），1主加最多5细分，自由决定

-- ============ 查重（INSERT 前必跑，LIMIT 1） ============
SELECT id FROM subjects WHERE name='科目名' LIMIT 1;
SELECT id, tags FROM topics WHERE subject_id=科目ID AND name='知识点' LIMIT 1;
SELECT id, times_asked, tags FROM questions WHERE question='问题原文' LIMIT 1;
SELECT id FROM mistakes WHERE topic_id=知识点ID AND question='题目' AND COALESCE(wrong_answer,'')=COALESCE('错答','') LIMIT 1;

-- ============ 相似自动合并（查不到精确时跑，命中则合并不新建） ============
-- 知识点相似：归一相等或别名交集即同一知识点，合并 keywords/tags（去重）
SELECT id, keywords, tags FROM topics
WHERE subject_id=科目ID AND (lower(trim(name))=lower(trim('新知识点')) OR (','||COALESCE(keywords,'')||',') LIKE '%,新别名,%' OR (','||COALESCE(tags,'')||',') LIKE '%,主标签,%')
LIMIT 5;
UPDATE topics SET keywords=CASE WHEN keywords='' OR keywords IS NULL THEN '别名' ELSE '别名,'||keywords END WHERE id=命中ID AND (','||COALESCE(keywords,'')||',') NOT LIKE '%,别名,%';
UPDATE topics SET tags=CASE WHEN tags='' OR tags IS NULL THEN '主标签' WHEN (','||tags||',') LIKE '%,主标签,%' THEN tags ELSE tags||',主标签' END WHERE id=命中ID;
-- 问题相似：同科目要点/tag 重合即复用原行
SELECT id, question, tags FROM questions WHERE subject_id=科目ID AND (question LIKE '%核心词%' OR (','||COALESCE(tags,'')||',') LIKE '%,主标签,%') LIMIT 5;

-- ============ 写入（幂等） ============
INSERT OR IGNORE INTO subjects (name, full_name) VALUES ('数学二','考研数学二');
INSERT OR IGNORE INTO topics (subject_id, name, keywords, tags) VALUES (科目ID,'知识点','别名','主标签,细分1,细分2');
INSERT INTO questions (subject_id, topic_id, question, answer_digest, tags) VALUES (科目ID,知识点ID,'问题','要点','主标签,细分1') ON CONFLICT(question) DO UPDATE SET times_asked=times_asked+1, last_asked_at=CURRENT_TIMESTAMP, tags=CASE WHEN (','||COALESCE(tags,'')||',') LIKE '%,主标签,%' THEN tags ELSE COALESCE(tags,'')||',主标签' END;
INSERT OR IGNORE INTO mistakes (topic_id, question, wrong_answer, correct_answer, explanation) VALUES (知识点ID,'题','错','对','析');
INSERT INTO progress (topic_id, correct_count, wrong_count, last_practice_at) VALUES (知识点ID,0,1,CURRENT_TIMESTAMP) ON CONFLICT(topic_id) DO UPDATE SET wrong_count=wrong_count+1, last_practice_at=CURRENT_TIMESTAMP;
INSERT INTO progress (topic_id, correct_count, wrong_count, last_practice_at) VALUES (知识点ID,1,0,CURRENT_TIMESTAMP) ON CONFLICT(topic_id) DO UPDATE SET correct_count=correct_count+1, last_practice_at=CURRENT_TIMESTAMP;

-- ============ 核心检索：预答→精查薄弱点（tag-aware，IN 2-3 要点 + tag 兜底） ============
SELECT t.name, t.tags, COALESCE(p.wrong_count,0) wc, COALESCE(p.correct_count,0) cc
FROM topics t LEFT JOIN progress p ON p.topic_id=t.id
WHERE t.subject_id=(SELECT id FROM subjects WHERE name='判定的科目' LIMIT 1)
  AND (t.name IN ('要点1','要点2') OR (','||COALESCE(t.tags,'')||',') LIKE '%,主标签,%');

-- ============ 分页 ============
SELECT COUNT(*) FROM subjects;
SELECT COUNT(*) FROM topics WHERE subject_id=科目ID;
SELECT COUNT(*) FROM questions WHERE subject_id=科目ID;
SELECT name FROM subjects ORDER BY id LIMIT 20 OFFSET 0;
SELECT id, name, tags FROM topics WHERE subject_id=科目ID ORDER BY id DESC LIMIT 20 OFFSET 0;
SELECT id, question, tags, times_asked FROM questions WHERE subject_id=科目ID ORDER BY id DESC LIMIT 20 OFFSET 0;

-- ============ 统计总览 + 薄弱综合 ============
SELECT (SELECT COUNT(*) FROM questions) qs, (SELECT COUNT(*) FROM topics) tps, (SELECT COUNT(*) FROM progress) tracked, (SELECT COUNT(*) FROM mistakes) ms, (SELECT COUNT(*) FROM subjects) subs;
SELECT t.name, s.name subject, t.tags, p.wrong_count, p.correct_count, ROUND(COALESCE(p.mastery_level,0),2) m, (julianday('now')-julianday(p.last_practice_at)) d FROM progress p JOIN topics t ON t.id=p.topic_id JOIN subjects s ON s.id=t.subject_id WHERE p.wrong_count>0 ORDER BY p.wrong_count DESC, d DESC LIMIT 10;
SELECT type, SUM(count) n FROM history_logs WHERE date=date('now','localtime') GROUP BY type;
SELECT type, SUM(count) n FROM history_logs WHERE date>=date('now','-7 days','localtime') GROUP BY type;

-- ============ 轻量复习（仅用户说复习/总结/薄弱点时） ============
SELECT t.name, s.name subject, t.tags, p.wrong_count, ROUND(COALESCE(p.mastery_level,0),2) m FROM progress p JOIN topics t ON t.id=p.topic_id JOIN subjects s ON s.id=t.subject_id WHERE p.wrong_count > p.correct_count ORDER BY m ASC LIMIT 5;

-- ============ 日志 ============
INSERT INTO history_logs (date,type,count) VALUES (date('now','localtime'),'qa',1) ON CONFLICT(date,type) DO UPDATE SET count=count+1;
INSERT INTO history_logs (date,type,count) VALUES (date('now','localtime'),'mistake',1) ON CONFLICT(date,type) DO UPDATE SET count=count+1;

-- ============ 维护：去重扫描（按需） ============
-- SELECT lower(trim(name)), COUNT(*) c FROM topics GROUP BY 1 HAVING c>1 LIMIT 20;

-- ============ 旧库升级 ============
-- PRAGMA table_info(topics); 无 keywords 则 ALTER TABLE topics ADD COLUMN keywords TEXT DEFAULT '';
-- PRAGMA table_info(topics); 无 tags 则 ALTER TABLE topics ADD COLUMN tags TEXT DEFAULT '';
-- PRAGMA table_info(questions); 无 tags 则 ALTER TABLE questions ADD COLUMN tags TEXT DEFAULT '';
-- 缺表/缺索引对照 schema.sql 补齐后重跑 schema.sql
