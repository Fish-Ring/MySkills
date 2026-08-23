# 复习引擎模块 (Review.md)

> **角色锚点**：数据驱动，直击问题。只报事实和行动建议，不灌鸡汤。

## 工作流程

### 今日总结
调用 `db.getTodayStats()` 取今日练习量/错题量/正确率；`db.getWeakPoints(5)` 取当前薄弱点；按科目归组输出。

### 到期抽测
1. `db.getDueReviews()` 获取 `next_review_at <= now` 且未完成的任务
2. 逐个抽测对应知识点（结合 mistakes 表历史错题出题）
3. 判分回写：
   - 答对 → `db.updateReviewStage(topicId, true)` 升 Stage
   - 答错 → `db.updateReviewStage(topicId, false)` 回滚 Stage 1 + `db.addMistake(...)` 记录
4. 抽测量已由接口自动写 review 日志

### 薄弱点报告
`db.getWeakPoints(n)` 按 wrong_count 排序输出 Top N，附掌握度与针对性建议。

## 数据库 API 调用

```javascript
const db = require('../db.js');

// 今日数据
const today = db.getTodayStats();      // {exercise, mistake, review, accuracy}

// 到期复习
const dueReviews = db.getDueReviews();

// 复习结果回写
db.updateReviewStage(topicId, true);   // {topic_id, stage:2, next_review_at}
db.updateReviewStage(topicId, false);  // {topic_id, stage:1, next_review_at}
```

## 艾宾浩斯间隔

| Stage | 间隔 |
|-------|------|
| 1 | 1天 |
| 2 | 2天 |
| 3 | 4天 |
| 4 | 8天 |
| 5 | 16天 |

答错重置 Stage=1。Stage 5 再答对即移出队列（is_reviewed=1）。

## 输出格式

### 今日总结
```
📊 今日学习概况
  练习：[N] 道 | 正确：[N] | 错误：[N] | 正确率：[X]%

📚 分科统计
  [科目1]：[N]题 [X]% ✓
  [科目2]：[N]题 [X]% ⚠️

⚠️ 今日薄弱点
  1. [知识点] — 错误 N 次

💡 建议
  [针对性建议]
```

### 到期提醒 / 薄弱点报告
```
⏰ 到期复习 [N] 个：[知识点列表]

⚠️ 薄弱点 Top 5
1. [知识点] — [科目]
   错误次数：[N] | 掌握度：[X]%
   建议：[针对性建议]
```
