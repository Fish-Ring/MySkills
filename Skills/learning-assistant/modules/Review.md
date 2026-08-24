# 复习引擎模块 (Review.md)

> **角色锚点**：数据驱动，直击问题。只报事实和行动建议，不灌鸡汤。

## 今日总结

```bash
# 今日日志
sqlite3 -json <技能目录>/learner.db "SELECT type,SUM(count) AS n FROM history_logs WHERE date=date('now','localtime') GROUP BY type;"
# 薄弱点 Top5
sqlite3 -json <技能目录>/learner.db "SELECT t.name,s.name AS subject,p.wrong_count,p.correct_count,ROUND(p.mastery_level,2) AS mastery FROM progress p JOIN topics t ON t.id=p.topic_id JOIN subjects s ON s.id=t.subject_id WHERE p.wrong_count>p.correct_count OR p.mastery_level<0.6 ORDER BY p.mastery_level ASC LIMIT 5;"
```

正确率 = 1 − mistake/exercise（qa 类型不计入）；练习量为 0 时显示「—」不显示百分比。输出练习量、分科统计、薄弱点 Top3 与明确行动建议。

## 到期抽测

1. 取到期任务：
   ```bash
   sqlite3 -json <技能目录>/learner.db "SELECT rq.id,rq.topic_id,rq.stage,t.name AS 知识点,s.name AS 科目 FROM review_queue rq JOIN topics t ON t.id=rq.topic_id JOIN subjects s ON s.id=t.subject_id WHERE rq.is_reviewed=0 AND rq.next_review_at<=strftime('%s','now') ORDER BY rq.next_review_at ASC;"
   ```
2. 结合 mistakes 表该知识点的历史错题逐个抽测
3. 判分回写用 queries.sql「复习完成」模板：答对升档、答错回 Stage1 并补记 mistakes；Stage5 答对移出队列
4. 回写后记 review 日志（ON CONFLICT 累计）

## 薄弱点报告

薄弱点 TopN（同今日总结第二条查询，LIMIT 可调大），每条附掌握度与针对性建议。

## 艾宾浩斯间隔

| Stage | 间隔 |
|-------|------|
| 1 | 1 天 |
| 2-5 | 2/4/8/16 天 |

答错重置 Stage=1；Stage 5 再答对 is_reviewed=1 移出队列。秒数：86400/172800/345600/691200/1382400。

## 输出格式

```
📊 今日学习概况
  练习：[N] 道 | 错误：[N] | 正确率：[X]% | 提问：[N] 次

📚 分科统计
  [科目]：[N]题 [X]% ✓

⏰ 到期复习 [N] 个：[知识点列表]

⚠️ 薄弱点 Top 5
1. [知识点] — [科目]
   错误次数：[N] | 掌握度：[X]%
   建议：[针对性建议]

💡 行动建议：今天复习 X 个弱点，明天目标 Y 道题
```
