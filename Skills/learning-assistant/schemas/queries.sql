-- 通用学习助手 v1.4.1 - 常用 SQL 模板（限流+自动合并）
-- 用法：sqlite3 -json <技能目录>/learner.db "<语句>"
-- 约定：' 拼入前写成 ''；先查重→相似查→自动合并后写入

-- ============ 查重（INSERT 前必跑，LIMIT 1 防御） ============
SELECT id FROM subjects WHERE name='科目名' LIMIT 1;
SELECT id FROM topics WHERE subject_id=科目ID AND name='知识点' LIMIT 1;
SELECT id, times_asked FROM questions WHERE question='问题原文' LIMIT 1;
SELECT id FROM mistakes WHERE topic_id=知识点ID AND question='题目' AND COALESCE(wrong_answer,'')=COALESCE('错答','') LIMIT 1;

-- ============ 相似自动合并（查不到精确时跑，命中则合并不新建） ============
-- 知识点相似：归一相等或别名交集即视为同一知识点，合并 keywords
SELECT id, keywords FROM topics
WHERE subject_id=科目ID AND (lower(trim(name))=lower(trim('新知识点')) OR (','||COALESCE(keywords,'')||',') LIKE '%,新别名,%')
LIMIT 5;
-- 命中后合并别名（去重）
UPDATE topics SET keywords=CASE WHEN keywords='' OR keywords IS NULL THEN '别名' ELSE '别名,'||keywords END
  WHERE id=命中ID AND (','||COALESCE(keywords,'')||',') NOT LIKE '%,别名,%';
-- 问题相似：同科目且要点重合即复用原行（IN 要点来自预答草拟）
SELECT id, question FROM questions
WHERE subject_id=科目ID AND question LIKE '%核心词%' LIMIT 5;
-- 命中则 times_asked+1，不命中再 INSERT

-- ============ 写入（幂等） ============
INSERT OR IGNORE INTO subjects (name, full_name) VALUES ('数学二','考研数学二');
INSERT OR IGNORE INTO topics (subject_id, name, keywords) VALUES (科目ID,'知识点','别名');
INSERT INTO questions (subject_id, topic_id, question, answer_digest) VALUES (科目ID,知识点ID,'问题','要点')
  ON CONFLICT(question) DO UPDATE SET times_asked=times_asked+1, last_asked_at=CURRENT_TIMESTAMP;
INSERT OR IGNORE INTO mistakes (topic_id, question, wrong_answer, correct_answer, explanation) VALUES (知识点ID,'题','错','对','析');
INSERT INTO progress (topic_id, correct_count, wrong_count, last_practice_at) VALUES (知识点ID,0,1,CURRENT_TIMESTAMP)
  ON CONFLICT(topic_id) DO UPDATE SET wrong_count=wrong_count+1, last_practice_at=CURRENT_TIMESTAMP;
INSERT INTO progress (topic_id, correct_count, wrong_count, last_practice_at) VALUES (知识点ID,1,0,CURRENT_TIMESTAMP)
  ON CONFLICT(topic_id) DO UPDATE SET correct_count=correct_count+1, last_practice_at=CURRENT_TIMESTAMP;

-- ============ 核心检索：预答→精查薄弱点（问答时唯一必查，IN 2-3 要点天然限流） ============
SELECT t.name, COALESCE(p.wrong_count,0) wc, COALESCE(p.correct_count,0) cc
FROM topics t LEFT JOIN progress p ON p.topic_id=t.id
WHERE t.subject_id=(SELECT id FROM subjects WHERE name='判定的科目' LIMIT 1)
  AND t.name IN ('要点1','要点2');

-- ============ 轻量复习（仅用户说复习/总结/薄弱点时，LIMIT 5） ============
SELECT t.name, s.name subject, p.wrong_count, ROUND(COALESCE(p.mastery_level,0),2) m
FROM progress p JOIN topics t ON t.id=p.topic_id JOIN subjects s ON s.id=t.subject_id
WHERE p.wrong_count > p.correct_count ORDER BY m ASC LIMIT 5;

-- ============ 日志 ============
INSERT INTO history_logs (date,type,count) VALUES (date('now','localtime'),'qa',1)
  ON CONFLICT(date,type) DO UPDATE SET count=count+1;
SELECT type, SUM(count) n FROM history_logs WHERE date=date('now','localtime') GROUP BY type;

-- ============ 维护：去重扫描（按需） ============
-- SELECT lower(trim(name)), COUNT(*) c FROM topics GROUP BY 1 HAVING c>1 LIMIT 20;

-- ============ 旧库升级 ============
-- PRAGMA table_info(topics); 无 keywords 列则 ALTER TABLE topics ADD COLUMN keywords TEXT DEFAULT '';
-- 缺表对照 schema.sql 补齐后重跑 schema.sql
