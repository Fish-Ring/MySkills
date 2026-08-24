# 数据库模式 (Schemas)

> 本文件与 `schema.sql` 保持一致。`schema.sql` 幂等可重复执行，是唯一的建库入口。

## 设计原则

1. **幂等**：全部 `IF NOT EXISTS`，重复执行无副作用；旧库缺列时用 `ALTER TABLE ... ADD COLUMN keywords` 升级（见 schema.sql 末段）。
2. **查重靠约束**：`subjects.name`、`questions.question`、`(date,type)` 等均有 UNIQUE 约束，写入一律 `INSERT OR IGNORE` 或 upsert。
3. **日志自动累计**：同一 `(date, type)` 重复写入时 count+1（ON CONFLICT upsert）。

## 表结构

```sql
subjects      科目。name UNIQUE, full_name, weight
topics        知识点。subject_id→subjects.id, name, parent_id(层级),
              keywords(检索别名, DEFAULT ''), exam_weight,
              UNIQUE(subject_id, name)
questions     提问记录（问答流水线核心）。question TEXT NOT NULL UNIQUE,
              subject_id, topic_id, answer_digest(答案要点摘要),
              technique(答题技巧), times_asked(DEFAULT 1), last_asked_at
mistakes      错题。topic_id, question, wrong_answer, correct_answer,
              explanation, mistake_count, last_mistake_at,
              UNIQUE(topic_id, question, wrong_answer, correct_answer)
progress      掌握度。topic_id PRIMARY KEY, correct_count, wrong_count,
              last_practice_at, mastery_level(REAL)
review_queue  艾宾浩斯队列。topic_id, stage(1~5), next_review_at(UNIX秒),
              is_reviewed
history_logs  学习日志。date(TEXT YYYY-MM-DD), type, count,
              UNIQUE(date, type)；type ∈ qa / exercise / mistake / review
user_profile  用户档案。exam, stage(基础/强化/冲刺/自学), exam_date；
              建库时种子行 id=1
```

精确 DDL 见 `schema.sql`；每张表的业务 SQL 模板见 `queries.sql`。

## 关键行为约定

| 场景 | 行为 |
|------|------|
| 提问入库 | questions 按 question upsert：命中则 times_asked+1 并更新 last_asked_at |
| 仅提问 | 只累计 times_asked，不动 progress 掌握度 |
| 做错/不会 | progress.wrong_count+1 → mistakes 记录（先查重）→ review_queue 注入 stage=1 → mistake 日志 |
| 自评已懂 | progress.correct_count+1 → exercise 日志 |
| 复习完成 | 答对升档、答错回 Stage1；Stage5 答对 is_reviewed=1 移出队列 → review 日志 |

## 薄弱点判定口径

```sql
WHERE p.wrong_count > p.correct_count OR p.mastery_level < 0.6
ORDER BY p.mastery_level ASC, p.wrong_count DESC
```

错题越多的知识点出题概率越高（约 ×2）。

## 索引

idx_topics_subject、idx_topics_keywords、idx_questions_topic、idx_questions_last_asked、idx_mistakes_topic、idx_mistakes_count、idx_progress_mastery、idx_review_queue_due(next_review_at, is_reviewed)、idx_history_date——完整定义见 schema.sql。
