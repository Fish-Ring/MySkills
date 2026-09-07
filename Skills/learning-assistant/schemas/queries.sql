-- 通用学习助手 v1.5.3 - 常用 SQL 模板（分页+统计+tag专业名词+技巧+三实体+见解+合并）
-- 要求 SQLite ≥3.24（UPSERT）；表达式索引需 ≥3.9（Debian10 默认 3.27 可用，3.24+ 部分可用）
-- 用法：sqlite3 -json <技能目录>/learner.db "<语句>"；写入一律 heredoc 内联事务，禁落文件
-- 约定：中文文本里的撇号一律用 ′(U+2032)，禁英文 '；SQL 内英文引号写成 ''；先查重→相似查→自动合并后写入；tag 必须是专业名词（禁止句子），1主加最多5细分，自由决定
-- 三实体：progress=Mastery长期状态 / misconceptions=可复用认知模式 / mistakes=单次错误事件，三者不混

-- ============ 查重（INSERT 前必跑，LIMIT 1） ============
SELECT id FROM subjects WHERE name='科目名' LIMIT 1;
SELECT id, tags FROM topics WHERE subject_id=科目ID AND name='知识点' LIMIT 1;
SELECT id, times_asked, tags FROM questions WHERE question='问题原文' LIMIT 1;
SELECT id, mistake_count FROM mistakes WHERE COALESCE(topic_id,-1)=COALESCE(知识点ID,-1) AND question='题目' AND COALESCE(wrong_answer,'')='错答' AND COALESCE(correct_answer,'')='对答' LIMIT 1;
SELECT id, type FROM misconceptions WHERE lower(trim(title))=lower(trim('错误名')) AND type='concept' LIMIT 1;
SELECT question_id, topic_id FROM question_topics WHERE question_id=问题ID AND topic_id=副知识点ID LIMIT 1;
SELECT id, primary_subject_id FROM techniques WHERE name='技巧名' AND COALESCE(primary_subject_id,-1)=COALESCE(科目ID,-1) LIMIT 1;

-- ============ 相似自动合并（查不到精确时跑，命中则合并不新建） ============
-- 知识点相似：归一相等或别名交集即同一知识点，合并 keywords/tags（去重）
SELECT id, keywords, tags FROM topics
WHERE subject_id=科目ID AND (lower(trim(name))=lower(trim('新知识点')) OR (','||COALESCE(keywords,'')||',') LIKE '%,新别名,%' OR (','||COALESCE(tags,'')||',') LIKE '%,主标签,%')
LIMIT 5;
UPDATE topics SET keywords=CASE WHEN keywords='' OR keywords IS NULL THEN '别名' ELSE '别名,'||keywords END WHERE id=命中ID AND (','||COALESCE(keywords,'')||',') NOT LIKE '%,别名,%';
UPDATE topics SET tags=CASE WHEN COALESCE(tags,'')='' THEN '主标签' WHEN (','||tags||',') LIKE '%,主标签,%' THEN tags ELSE tags||',主标签' END WHERE id=命中ID;
-- 问题相似：同科目要点/tag 重合即复用旧行（命中则直接用旧 id 写 question_topics / times_asked+1，不 INSERT；阈值：question LIKE 命中或主标签相同）
SELECT id, question, tags FROM questions WHERE subject_id=科目ID AND (question LIKE '%核心词%' OR (','||COALESCE(tags,'')||',') LIKE '%,主标签,%') LIMIT 5;
-- 技巧相似：同主归属下归一相等或别名/tag交集即同一技巧，合并 keywords/tags
SELECT id, keywords, tags FROM techniques
WHERE COALESCE(primary_subject_id,-1)=COALESCE(科目ID,-1) AND (lower(trim(name))=lower(trim('新技巧')) OR (','||COALESCE(keywords,'')||',') LIKE '%,新别名,%' OR (','||COALESCE(tags,'')||',') LIKE '%,主标签,%')
LIMIT 5;

-- ============ 写入（幂等） ============
INSERT OR IGNORE INTO subjects (name, full_name) VALUES ('数学二','考研数学二');
INSERT OR IGNORE INTO topics (subject_id, name, keywords, tags) VALUES (科目ID,'知识点','别名','主标签,细分1,细分2');
INSERT INTO questions (subject_id, topic_id, question, answer_digest, technique, tags, source, difficulty, last_asked_at) VALUES (科目ID,知识点ID,'问题','要点','技巧名','主标签,细分1','真题',3,CURRENT_TIMESTAMP) ON CONFLICT(question) DO UPDATE SET times_asked=times_asked+1, last_asked_at=CURRENT_TIMESTAMP, tags=CASE WHEN COALESCE(tags,'')='' THEN '主标签' WHEN (','||tags||',') LIKE '%,主标签,%' THEN tags ELSE tags||',主标签' END;
-- 档案写入（启动建档用；id=1 种子行已存在）
INSERT INTO user_profile (id, exam, stage, exam_date) VALUES (1,'考试','阶段','日期') ON CONFLICT(id) DO UPDATE SET exam=excluded.exam, stage=excluded.stage, exam_date=excluded.exam_date;
UPDATE user_profile SET exam='考试', stage='阶段', exam_date='日期' WHERE id=1;
-- 错题复犯累加（命中 UNIQUE 则 mistake_count+1；与 occurrence 模板同理）
INSERT INTO mistakes (topic_id, question, wrong_answer, correct_answer, explanation) VALUES (知识点ID,'题','错','对','析') ON CONFLICT(topic_id,question,wrong_answer,correct_answer) DO UPDATE SET mistake_count=mistake_count+1, last_mistake_at=CURRENT_TIMESTAMP;
-- 注意：UNIQUE 含可空列，NULL 行永不冲突；此类行靠应用层查重（上段 COALESCE 模板），命中后 UPDATE mistake_count+1
-- progress 建行+计数（含连击维护；之后必接 Mastery 重算；与下段 :45/46 快捷更新互斥，二选一）
INSERT INTO progress (topic_id, correct_count, wrong_count, consecutive_correct, last_practice_at) VALUES (知识点ID,0,1,0,CURRENT_TIMESTAMP) ON CONFLICT(topic_id) DO UPDATE SET wrong_count=wrong_count+1, consecutive_correct=0, last_practice_at=CURRENT_TIMESTAMP;
INSERT INTO progress (topic_id, correct_count, wrong_count, consecutive_correct, last_practice_at) VALUES (知识点ID,1,0,1,CURRENT_TIMESTAMP) ON CONFLICT(topic_id) DO UPDATE SET correct_count=correct_count+1, consecutive_correct=consecutive_correct+1, last_practice_at=CURRENT_TIMESTAMP;
-- Misconception 写入（错题判型后执行；复用时 occurrence_count+1；severity 1-5）
INSERT INTO misconceptions (title, type, description, confidence) VALUES ('错误名','concept','描述',0.7) ON CONFLICT(title,type) DO UPDATE SET occurrence_count=occurrence_count+1;
INSERT OR IGNORE INTO knowledge_misconception (topic_id, misconception_id, severity) VALUES (知识点ID,错误模式ID,4);
INSERT OR IGNORE INTO mistake_misconceptions (mistake_id, misconception_id) VALUES (错题ID,错误模式ID);
-- 副知识点关联（一道题多个知识点时，主知识点仍走 questions.topic_id）
INSERT OR IGNORE INTO question_topics (question_id, topic_id, weight) VALUES (问题ID,副知识点ID,0.8);
-- 取刚写入行的 id（先查重→无则 INSERT→再 SELECT；不用 RETURNING，照顾旧版 sqlite3）：
-- SELECT id FROM misconceptions WHERE lower(trim(title))=lower(trim('错误名')) AND type='concept' LIMIT 1;
-- Mastery 重算（同一事务内执行：答错连击清零，答对连击+1；score=100*(cc+连击加成)/(cc+wc)；status 派生）
-- 快捷更新（行已存在时用，与上段建行模板互斥；之后必接重算）
-- 答错：UPDATE progress SET wrong_count=wrong_count+1, consecutive_correct=0, last_practice_at=CURRENT_TIMESTAMP WHERE topic_id=知识点ID;
-- 答对：UPDATE progress SET correct_count=correct_count+1, consecutive_correct=consecutive_correct+1, last_practice_at=CURRENT_TIMESTAMP WHERE topic_id=知识点ID;
-- 重算（分母 NULLIF 防零，consecutive COALESCE 防 NULL）：
-- UPDATE progress SET mastery_score=ROUND(100.0*(correct_count+MIN(COALESCE(consecutive_correct,0),5))/NULLIF(correct_count+wrong_count+MIN(COALESCE(consecutive_correct,0),5),0),1), status=CASE WHEN wrong_count>correct_count THEN 'weak' WHEN correct_count>=3 AND 1.0*correct_count/NULLIF(correct_count+wrong_count,0)>=0.8 THEN 'mastered' WHEN correct_count>0 THEN 'familiar' ELSE 'learning' END WHERE topic_id=知识点ID;
-- 技巧写入（AND门控通过后才执行；跨科由 AI 自主决定多关联一行 technique_topics）
INSERT OR IGNORE INTO techniques (name, primary_subject_id, description, keywords, tags) VALUES ('技巧名',科目ID,'IF触发条件 THEN 2-5步','别名','主标签,细分1');
UPDATE techniques SET keywords=CASE WHEN (','||COALESCE(keywords,'')||',') NOT LIKE '%,新别名,%' THEN COALESCE(keywords,'')||',新别名' ELSE keywords END, tags=CASE WHEN (','||COALESCE(tags,'')||',') NOT LIKE '%,主标签,%' THEN COALESCE(tags,'')||',主标签' ELSE tags END WHERE id=命中ID;
INSERT OR IGNORE INTO technique_topics (technique_id, topic_id) VALUES (技巧ID,知识点ID);
INSERT OR IGNORE INTO technique_questions (technique_id, question_id) VALUES (技巧ID,问题ID);

-- ============ 核心检索：预答→精查薄弱点（tag-aware，IN 2-3 要点 + tag 兜底） ============
SELECT t.name, t.tags, COALESCE(p.wrong_count,0) wc, COALESCE(p.status,'learning') st, COALESCE(p.mastery_score,0) score
FROM topics t LEFT JOIN progress p ON p.topic_id=t.id
WHERE t.subject_id=(SELECT id FROM subjects WHERE name='判定的科目' LIMIT 1)
  AND (t.name IN ('要点1','要点2') OR (','||COALESCE(t.tags,'')||',') LIKE '%,主标签,%')
LIMIT 5;
-- 技巧感知（合并进同一查询或复盘时查，不单独破2次封顶）：
SELECT k.name, k.description FROM technique_topics tt JOIN techniques k ON k.id=tt.technique_id JOIN topics t ON t.id=tt.topic_id LEFT JOIN progress p ON p.topic_id=t.id WHERE t.subject_id=(SELECT id FROM subjects WHERE name='科目' LIMIT 1) AND t.name IN ('要点1','要点2') LIMIT 5;

-- ============ 分页 ============
SELECT COUNT(*) FROM subjects;
SELECT COUNT(*) FROM topics WHERE subject_id=科目ID;
SELECT COUNT(*) FROM questions WHERE subject_id=科目ID;
SELECT COUNT(*) FROM techniques WHERE COALESCE(primary_subject_id,-1)=COALESCE(科目ID,-1);
SELECT name FROM subjects ORDER BY id LIMIT 20 OFFSET 0;
SELECT id, name, tags FROM topics WHERE subject_id=科目ID ORDER BY id DESC LIMIT 20 OFFSET 0;
SELECT id, question, tags, times_asked FROM questions WHERE subject_id=科目ID ORDER BY id DESC LIMIT 20 OFFSET 0;
SELECT id, name, tags FROM techniques WHERE COALESCE(primary_subject_id,-1)=COALESCE(科目ID,-1) ORDER BY id DESC LIMIT 20 OFFSET 0;

-- ============ 统计总览 + 薄弱综合（六计数 qs/tps/tracked/ms/subs/tcs，白名单只取计数） ============
SELECT (SELECT COUNT(*) FROM questions) qs, (SELECT COUNT(*) FROM topics) tps, (SELECT COUNT(*) FROM progress) tracked, (SELECT COUNT(*) FROM mistakes) ms, (SELECT COUNT(*) FROM subjects) subs, (SELECT COUNT(*) FROM techniques) tcs;
-- 兼容口径（旧 status 未回填时用）：
SELECT t.name, s.name subject, t.tags, p.wrong_count, p.correct_count, ROUND(COALESCE(p.mastery_level,0),2) m, (julianday('now')-julianday(p.last_practice_at)) d FROM progress p JOIN topics t ON t.id=p.topic_id JOIN subjects s ON s.id=t.subject_id WHERE p.wrong_count>0 ORDER BY p.wrong_count DESC, d DESC LIMIT 10;
SELECT k.name, s.name subject, k.tags, COUNT(DISTINCT tt.topic_id) topics, COUNT(DISTINCT tq.question_id) qs FROM techniques k LEFT JOIN technique_topics tt ON tt.technique_id=k.id LEFT JOIN technique_questions tq ON tq.technique_id=k.id LEFT JOIN subjects s ON s.id=k.primary_subject_id GROUP BY k.id ORDER BY qs DESC LIMIT 10;
SELECT type, SUM(count) n FROM history_logs WHERE date=date('now','localtime') GROUP BY type;
SELECT type, SUM(count) n FROM history_logs WHERE date>=date('now','-7 days','localtime') GROUP BY type;

-- ============ 轻量复习 + 每日复盘（仅用户说复习/总结/薄弱点/复盘时） ============
-- 薄弱Top（按技巧聚合可选；v1.5.0 优先用 status/score）
SELECT t.name, s.name subject, t.tags, p.status, p.mastery_score, p.wrong_count FROM progress p JOIN topics t ON t.id=p.topic_id JOIN subjects s ON s.id=t.subject_id WHERE p.status='weak' ORDER BY p.mastery_score ASC LIMIT 5;
SELECT t.name, s.name subject, t.tags, p.wrong_count, ROUND(COALESCE(p.mastery_level,0),2) m FROM progress p JOIN topics t ON t.id=p.topic_id JOIN subjects s ON s.id=t.subject_id WHERE p.wrong_count > p.correct_count ORDER BY m ASC LIMIT 5;
-- 认知错误聚合（哪类错最多 + 未解决优先）
SELECT type, SUM(occurrence_count) n, SUM(CASE WHEN resolved=0 THEN 1 ELSE 0 END) open FROM misconceptions GROUP BY type ORDER BY n DESC;
SELECT mc.title, mc.type, km.severity, mc.occurrence_count FROM knowledge_misconception km JOIN misconceptions mc ON mc.id=km.misconception_id JOIN topics t ON t.id=km.topic_id WHERE t.subject_id=科目ID AND mc.resolved=0 ORDER BY km.severity DESC, mc.occurrence_count DESC LIMIT 10;
-- 副知识点反查（一题多知识点）
SELECT t.name FROM question_topics qt JOIN topics t ON t.id=qt.topic_id WHERE qt.question_id=问题ID ORDER BY qt.weight DESC;
-- 每日复盘（用户主动发起）
SELECT date, type, SUM(count) n FROM history_logs WHERE date=date('now','localtime') GROUP BY type;
SELECT question, technique, tags, times_asked FROM questions WHERE date(last_asked_at)=date('now') ORDER BY id DESC LIMIT 20 OFFSET 0;
-- 注意：last_asked_at 存 UTC（CURRENT_TIMESTAMP），故用 date('now') 不用 localtime；history_logs 用 date('now','localtime') 读写一致，配对使用
SELECT t.name topic, k.name technique FROM progress p JOIN topics t ON t.id=p.topic_id LEFT JOIN technique_topics tt ON tt.topic_id=t.id LEFT JOIN techniques k ON k.id=tt.technique_id WHERE p.wrong_count>0 ORDER BY p.wrong_count DESC LIMIT 10;
SELECT COUNT(DISTINCT technique) c FROM questions WHERE technique!='';

-- ============ 日志 ============
INSERT INTO history_logs (date,type,count) VALUES (date('now','localtime'),'qa',1) ON CONFLICT(date,type) DO UPDATE SET count=count+1;
INSERT INTO history_logs (date,type,count) VALUES (date('now','localtime'),'mistake',1) ON CONFLICT(date,type) DO UPDATE SET count=count+1;

-- ============ 用户见解（原文照录禁改写；精查已用子查询带回最新1条，此处为写入与补查） ============
SELECT id FROM insights WHERE topic_id=知识点ID AND content='用户原话' LIMIT 1;
INSERT INTO insights (topic_id, content) VALUES (知识点ID,'用户原话理解');
SELECT content FROM insights WHERE topic_id=知识点ID ORDER BY id DESC LIMIT 2;

-- ============ 主动合并（先总结释义写保留行，再转关联，最后删旧行；同一事务） ============
-- 知识点合并（progress 两行并一行：计数相加，连击取保留行，之后必接 Mastery 重算；M:N 用 UPDATE OR IGNORE 跳过重复关联）
UPDATE questions SET topic_id=保留ID WHERE topic_id=旧ID;
UPDATE mistakes SET topic_id=保留ID WHERE topic_id=旧ID;
UPDATE progress SET correct_count=correct_count+(SELECT correct_count FROM progress WHERE topic_id=旧ID), wrong_count=wrong_count+(SELECT wrong_count FROM progress WHERE topic_id=旧ID) WHERE topic_id=保留ID;
DELETE FROM progress WHERE topic_id=旧ID;
UPDATE OR IGNORE question_topics SET topic_id=保留ID WHERE topic_id=旧ID;
UPDATE OR IGNORE technique_topics SET topic_id=保留ID WHERE topic_id=旧ID;
UPDATE OR IGNORE knowledge_misconception SET topic_id=保留ID WHERE topic_id=旧ID;
UPDATE insights SET topic_id=保留ID WHERE topic_id=旧ID;
DELETE FROM topics WHERE id=旧ID;
-- 问题合并（times_asked 相加；mistakes 按题干文本关联，无需转）
UPDATE OR IGNORE technique_questions SET question_id=保留ID WHERE question_id=旧ID;
UPDATE OR IGNORE question_topics SET question_id=保留ID WHERE question_id=旧ID;
UPDATE questions SET times_asked=times_asked+(SELECT times_asked FROM questions WHERE id=旧ID) WHERE id=保留ID;
DELETE FROM questions WHERE id=旧ID;

-- ============ 维护：去重扫描（按需） ============
-- SELECT lower(trim(name)), COUNT(*) c FROM topics GROUP BY 1 HAVING c>1 LIMIT 20;
-- SELECT lower(trim(name)), primary_subject_id, COUNT(*) c FROM techniques GROUP BY 1,2 HAVING c>1 LIMIT 20;

-- ============ 旧库升级（顺序不可换——先 ALTER 补列，再重跑 schema.sql 补新表+索引） ============
-- 原因有二：CREATE TABLE IF NOT EXISTS 不补列；末尾索引引用新列，先重跑索引段会报 no such column（新表本身在索引段之前，已建好，不受影响）
-- v1.5.2 索引调整（删 6 冗余+退役 1 废弃+补 3 表达式）重跑即生效，无需手动操作
-- v1.5.x 新增表清单（缺表即重跑 schema.sql）：techniques/technique_topics/technique_questions/misconceptions/knowledge_misconception/mistake_misconceptions/question_topics/insights（v1.5.3）
-- PRAGMA table_info(topics); 无 keywords 则 ALTER TABLE topics ADD COLUMN keywords TEXT DEFAULT '';
-- PRAGMA table_info(topics); 无 tags 则 ALTER TABLE topics ADD COLUMN tags TEXT DEFAULT '';
-- PRAGMA table_info(questions); 无 tags 则 ALTER TABLE questions ADD COLUMN tags TEXT DEFAULT '';
-- PRAGMA table_info(questions); 无 source 则 ALTER TABLE questions ADD COLUMN source TEXT DEFAULT '';
-- PRAGMA table_info(questions); 无 difficulty 则 ALTER TABLE questions ADD COLUMN difficulty INTEGER DEFAULT 3;
-- PRAGMA table_info(progress); 无 consecutive_correct 则 ALTER TABLE progress ADD COLUMN consecutive_correct INTEGER DEFAULT 0;
-- PRAGMA table_info(progress); 无 mastery_score 则 ALTER TABLE progress ADD COLUMN mastery_score REAL DEFAULT 0.0;
-- PRAGMA table_info(progress); 无 status 则 ALTER TABLE progress ADD COLUMN status TEXT DEFAULT 'learning';
-- PRAGMA table_info(techniques); 缺表对照 schema.sql 幂等重跑
-- 更早旧库（v1.4 前）另需：mistakes.mistake_count、questions.last_asked_at
-- PRAGMA table_info(mistakes); 无 mistake_count 则 ALTER TABLE mistakes ADD COLUMN mistake_count INTEGER DEFAULT 1;
-- PRAGMA table_info(questions); 无 last_asked_at 则 ALTER TABLE questions ADD COLUMN last_asked_at TIMESTAMP;（禁 DEFAULT CURRENT_TIMESTAMP，SQLite 不允许 ADD COLUMN 带非常量默认值）
