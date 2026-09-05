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
              subject_id, topic_id, answer_digest, technique(≤12字技巧名), tags, times_asked, last_asked_at
mistakes      错题。topic_id, question, wrong_answer, correct_answer, explanation, mistake_count, UNIQUE(topic_id, question, wrong_answer, correct_answer)
progress      掌握度。topic_id PRIMARY KEY, correct_count, wrong_count, last_practice_at, mastery_level
review_queue  已废弃（兼容保留不写入）。通用技能不再使用艾宾浩斯队列，仅 english-learning-assistant 背词保留
history_logs  学习日志。date(YYYY-MM-DD), type, count, UNIQUE(date, type)；type ∈ qa/mistake/review/exercise
user_profile  用户档案。exam, stage, exam_date；建库时种子行 id=1
techniques    技巧。name(≤12字)+primary_subject_id(NULL=通用) UNIQUE, description(IF-THEN+2-5步), keywords, tags
technique_topics 技巧-知识点 M:N。PRIMARY KEY(technique_id, topic_id)，跨科由 AI 自主决定多关联一行
technique_questions 技巧-问题 M:N。PRIMARY KEY(technique_id, question_id)
```

精确 DDL 见 `schema.sql`；每张表的业务 SQL 模板见 `queries.sql`。

## 关键行为约定

| 场景 | 行为 |
|------|------|
| 提问入库 | questions 按 question upsert：命中则 times_asked+1 并更新 last_asked_at |
| 仅提问 | 只累计 times_asked，progress wrong_count+1（问即疑），技巧AND门控不通过则 technique='' |
| 技巧入库 | AND门控：跨3异构题复用 +2-5步动词化 +IF-THEN含主标签，缺一不入；查重 `lower(trim)`/别名/tag交集 LIMIT 5 命中则合并不新建；跨科由 AI 自主决定多关联 technique_topics |
| 做错/不会 | progress.wrong_count+1 → mistakes → mistake 日志 |
| 自评已懂 | progress.correct_count+1 → exercise 日志 |
| 复习/复盘 | 仅用户说“复习/总结/复盘”时触发：查 progress TopN（可按技巧聚合）+ history_logs 今日/7日 + 每日复盘模板，不写 review_queue |

## 薄弱点判定口径

```sql
WHERE p.wrong_count > p.correct_count
ORDER BY p.mastery_level ASC
-- 按技巧聚合：SELECT k.name, COUNT(*) FROM technique_topics tt JOIN techniques k ... GROUP BY k.id ORDER BY COUNT DESC
```

## 索引

idx_topics_subject、idx_techniques_primary_subject、idx_techniques_name、idx_technique_topics_topic/technique、idx_technique_questions_question/technique、idx_questions_topic、idx_questions_last、idx_mistakes_topic、idx_progress_mastery、idx_review_queue_due、idx_history_date——完整定义见 schema.sql。

## 记忆白名单

仅 `基础信息（22408/7科/阶段）` + `DB概况计数（qs/tps/ms/tcs）` + `薄弱Top6 名称+掌握度` 可写入 RikkaHub 记忆摘要；错题题干/知识点概述/技巧长文永不进记忆。
