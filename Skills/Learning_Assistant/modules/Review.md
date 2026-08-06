# 复习引擎模块 (Review.md)

## 工作流程

### 今日总结
查询 history_logs 中今日记录，按科目统计。

### 到期抽测
查询 review_queue 中 next_review_at <= now 且 is_reviewed = 0 的任务。

### 薄弱点报告
统计各科目错误总数，按错误次数排序输出。

## 数据库操作
```bash
# 查询到期复习任务
sqlite3 -json /workspace/learner.db "SELECT r.id, r.stage, t.name as topic, s.name as subject FROM review_queue r JOIN topics t ON t.id = r.topic_id JOIN subjects s ON s.id = t.subject_id WHERE r.next_review_at <= datetime('now') AND r.is_reviewed = 0 ORDER BY (SELECT COALESCE(SUM(mistake_count),0) FROM mistakes WHERE topic_id = r.topic_id) DESC;"

# 更新复习阶段（答对）
sqlite3 /workspace/learner.db "UPDATE review_queue SET is_reviewed = 1, stage = stage + 1, next_review_at = datetime('now', '+' || CASE stage WHEN 1 THEN '1' WHEN 2 THEN '1' WHEN 3 THEN '2' WHEN 4 THEN '4' WHEN 5 THEN '7' WHEN 6 THEN '15' ELSE '7' END || ' days') WHERE id = ?;"

# 更新复习阶段（答错）
sqlite3 /workspace/learner.db "UPDATE review_queue SET stage = 1, is_reviewed = 0, next_review_at = datetime('now', '+1 day') WHERE id = ?;"
```

## 艾宾浩斯间隔
| Stage | 间隔 |
|-------|------|
| 1 | 1天 |
| 2 | 1天 |
| 3 | 2天 |
| 4 | 4天 |
| 5 | 7天 |
| 6 | 15天 |

答错重置 Stage=1。