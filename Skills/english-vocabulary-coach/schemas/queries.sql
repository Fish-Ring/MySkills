-- 英语词汇教练 v2.4.1 - 常用 SQL 模板
-- 用法：sqlite3 -json <技能目录>/vocabulary.db "<语句>"
-- 铁律：任何 INSERT 前必须先跑对应查重语句；
--       文本值中的单引号必须写成两个 '' 再拼入 SQL（It's → 'It''s'，英语例句撇号高频）

-- ============ 查重（INSERT 前必跑） ============
SELECT id, word, pos, meaning FROM words WHERE word = '单词';
SELECT id, word, pos, meaning FROM words WHERE word LIKE '%词根%' LIMIT 10;

-- ============ 幂等写入 ============
-- 收录单词（UNIQUE 冲突自动忽略；已存在但内容要更新时改用 UPDATE）
INSERT OR IGNORE INTO words (word, pos, meaning, frequency, collocation, example, tips, tag)
VALUES ('abandon', 'v.', '放弃；遗弃', 5,
        '["abandon hope","abandon a plan"]', '例句', '记忆技巧', '阅读高频词');
-- 更新已有单词的释义/标签
UPDATE words SET meaning = '新释义', tag = '新标签' WHERE word = '单词';
-- 维护总词数（收录成功后执行）
UPDATE user_profile SET total_words_count = (SELECT COUNT(*) FROM words) WHERE id = 1;
-- 记日志（当日同类型累计）
INSERT INTO history_logs (date, type, count)
VALUES (date('now','localtime'), 'vocab_search', 1)
ON CONFLICT(date, type) DO UPDATE SET count = count + 1;

-- ============ 检索 ============
-- 按标签取词（抽测出题）
SELECT word, meaning, tag FROM words WHERE tag = '标签' ORDER BY RANDOM() LIMIT 10;
-- 最近收录
SELECT word, meaning, created_at FROM words ORDER BY id DESC LIMIT 10;
-- 高频优先
SELECT word, meaning FROM words ORDER BY frequency DESC LIMIT 10;

-- ============ 艾宾浩斯复习队列 ============
-- 间隔：Stage 1-5 = 1/2/4/8/16 天 = 86400/172800/345600/691200/1382400 秒
-- 加入队列（复用未完成行防累积）
INSERT INTO review_queue (word, stage, next_review_time, is_reviewed)
SELECT '单词', 1, strftime('%s','now') + 86400, 0
WHERE NOT EXISTS (SELECT 1 FROM review_queue WHERE word = '单词' AND is_reviewed = 0);
-- 到期任务
SELECT rq.id, rq.word, rq.stage, w.meaning
FROM review_queue rq LEFT JOIN words w ON w.word = rq.word
WHERE rq.is_reviewed = 0 AND rq.next_review_time <= strftime('%s','now')
ORDER BY rq.next_review_time ASC;
-- 复习完成（把 1/0 替换为答对与否）：答对升档、答错回 Stage1；Stage5 答对标记完成
UPDATE review_queue SET
    stage = CASE WHEN 答对 THEN MIN(stage + 1, 5) ELSE 1 END,
    is_reviewed = CASE WHEN stage >= 5 AND 答对 THEN 1 ELSE 0 END,
    next_review_time = CASE
        WHEN stage >= 5 AND 答对 THEN next_review_time
        WHEN NOT 答对 THEN strftime('%s','now') + 86400
        ELSE strftime('%s','now') + CASE MIN(stage + 1, 5)
             WHEN 2 THEN 172800 WHEN 3 THEN 345600 WHEN 4 THEN 691200 WHEN 5 THEN 1382400
             ELSE 86400 END
    END
WHERE id = 队列行ID AND word = '单词';

-- ============ 统计 ============
-- 今日统计
SELECT type, SUM(count) AS n FROM history_logs WHERE date = date('now','localtime') GROUP BY type;
-- 总览
SELECT (SELECT COUNT(*) FROM words) AS words,
       (SELECT COUNT(*) FROM review_queue WHERE is_reviewed = 0) AS queue_size,
       (SELECT target_exam FROM user_profile WHERE id = 1) AS target_exam;
