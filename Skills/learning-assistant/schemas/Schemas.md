# 数据库模式 (Schemas)

> 本文件与 `schema.sql` 保持一致。`schema.sql` 幂等可重复执行，是唯一的建库入口。

## 设计原则

1. **幂等**：全部 `IF NOT EXISTS`，重复执行无副作用；旧库缺列时按 `queries.sql` 末尾「旧库升级」段 `ALTER TABLE ... ADD COLUMN` 升级。
2. **查重靠约束**：`subjects.name`、`questions.question`、`techniques(name,primary_subject_id)`、`(date,type)` 等均有 UNIQUE 约束，写入一律 `INSERT OR IGNORE` 或 upsert。
3. **日志自动累计**：同一 `(date, type)` 重复写入时 count+1（ON CONFLICT upsert）。

## 表结构

```sql
subjects      科目。name UNIQUE, full_name, weight
topics        知识点。subject_id→subjects.id, name, parent_id(层级),
              keywords(检索别名, DEFAULT ''), tags(1主加最多5细分, DEFAULT ''), exam_weight,
              UNIQUE(subject_id, name)
questions     提问记录（问答流水线核心）。question TEXT NOT NULL UNIQUE,
              subject_id, topic_id, answer_digest, technique(≤12字技巧名), tags, source(真题/模拟/教材), difficulty(1-5), times_asked, last_asked_at
question_topics 题目-副知识点 M:N。PRIMARY KEY(question_id, topic_id), weight；主知识点仍走 questions.topic_id
mistakes      错题事件（单次错误）。topic_id, question, wrong_answer, correct_answer, explanation, mistake_count, UNIQUE(topic_id, question, wrong_answer, correct_answer)
progress      Mastery长期状态。topic_id PRIMARY KEY, correct/wrong_count, consecutive_correct, mastery_score(0-100), status(learning/familiar/mastered/weak), last_practice_at；mastery_level 旧列保留兼容
misconceptions 认知错误模式（可复用）。title+type(concept/formula/calculation/thinking/careless) UNIQUE, description, occurrence_count, resolved, confidence
knowledge_misconception 知识点-错误 M:N。PRIMARY KEY(topic_id, misconception_id), severity 1-5
mistake_misconceptions 错题-错误 M:N。PRIMARY KEY(mistake_id, misconception_id)
insights      用户见解。topic_id→topics.id, content（原文照录禁改写）；精查子查询带回最新1条引用
review_queue  已废弃（兼容保留不写入）。通用技能不再使用艾宾浩斯队列，仅 english-learning-assistant 背词保留
history_logs  学习日志。date(YYYY-MM-DD), type, count, UNIQUE(date, type)；type ∈ qa/mistake/review/exercise（通用技能不写 vocab_search）
user_profile  用户档案。exam, stage, exam_date；建库时种子行 id=1
techniques    技巧。name(≤12字)+primary_subject_id(NULL=通用) UNIQUE, description(IF-THEN+2-5步), keywords, tags
technique_topics 技巧-知识点 M:N。PRIMARY KEY(technique_id, topic_id)，跨科由 AI 自主决定多关联一行
technique_questions 技巧-问题 M:N。PRIMARY KEY(technique_id, question_id)
```

精确 DDL 见 `schema.sql`；每张表的业务 SQL 模板见 `queries.sql`。

## 关键行为约定

| 场景 | 行为 |
|------|------|
| 提问入库 | questions 按 question upsert：命中则 times_asked+1 并更新 last_asked_at；追问按上一 id 直接累加，不新建行 |
| 用户见解 | 两道门（正确+有价值）才入 insights，疑问情绪永不入；错理解只纠正不入库 |
| 仅提问 | 只累计 times_asked，progress wrong_count+1（问即疑），技巧AND门控不通过则 technique='' |
| 技巧入库 | AND门控：跨3异构题复用 +2-5步动词化 +IF-THEN含主标签，缺一不入；查重 `lower(trim)`/别名/tag交集 LIMIT 5 命中则合并不新建；跨科由 AI 自主决定多关联 technique_topics |
| 做错/不会 | progress.wrong_count+1（连击清零）→ mistakes → 判定类型入 misconceptions → 双M:N关联 → 同一事务重算 mastery_score/status → mistake 日志 |
| 自评已懂 | progress.correct_count+1（连击+1）→ 重算 mastery_score/status → exercise 日志 |
| 复习/复盘 | 仅用户说“复习/总结/复盘”时触发：查 progress TopN（可按技巧聚合）+ history_logs 今日/7日 + 每日复盘模板，不写 review_queue |

## 薄弱点判定口径（v1.5.0：status/score 为准）

```sql
WHERE p.status='weak' ORDER BY p.mastery_score ASC
-- 兼容口径：WHERE p.wrong_count > p.correct_count ORDER BY p.mastery_level ASC
-- 按技巧聚合：SELECT k.name, COUNT(*) FROM technique_topics tt JOIN techniques k ... GROUP BY k.id ORDER BY COUNT DESC
-- 按错误类型聚合：SELECT type, SUM(occurrence_count) FROM misconceptions GROUP BY type ORDER BY 2 DESC
```

## 索引（v1.5.3，共 18 个；v1.5.2 删 8 冗余（含退役 1 废弃）+ 补 3 表达式；本版 +insights 索引 1 个）

```
idx_topics_subject_id             topics(subject_id, id DESC)
idx_techniques_primary_subject    techniques(primary_subject_id)
idx_techniques_name               techniques(name)
idx_techniques_name_subject       UNIQUE techniques(name, COALESCE(primary_subject_id,-1))（防 NULL 通用重名）
idx_techniques_subject_coalesce   techniques(COALESCE(primary_subject_id,-1))（COALESCE 查询走索引）
idx_technique_topics_topic        technique_topics(topic_id)（正向走主键自带索引）
idx_technique_questions_question  technique_questions(question_id)
idx_misconceptions_type           misconceptions(type)
idx_misconceptions_title_nocase   UNIQUE misconceptions(lower(trim(title)), type)（大小写归一）
idx_knowledge_mis_mis             knowledge_misconception(misconception_id)
idx_mistake_mis_mis               mistake_misconceptions(misconception_id)
idx_question_topics_topic         question_topics(topic_id)
idx_insights_topic                insights(topic_id, id DESC)（带回最新见解）
idx_progress_status_score         progress(status, mastery_score)（薄弱 Top5 热点）
idx_questions_subject_topic       questions(subject_id, topic_id, id DESC)
idx_mistakes_count                mistakes(mistake_count DESC)（错题本 TopN）
idx_questions_topic               questions(topic_id)
idx_questions_last                questions(last_asked_at DESC)
```
已删：M:N 正向 5（主键自带）、idx_topics_subject（被复合覆盖）、idx_history_date 与 idx_mistakes_topic（UNIQUE 左前缀覆盖）、idx_progress_mastery/status（被复合替代）、idx_review_queue_due（废弃表退役）。

## 记忆白名单

仅 `基础信息（考试/科目数/阶段）` + `DB概况计数（qs/tps/tracked/ms/subs/tcs 六计数）` + `薄弱Top6 名称+掌握度` 可写入 RikkaHub 记忆摘要；错题题干/知识点概述/技巧长文永不进记忆。
