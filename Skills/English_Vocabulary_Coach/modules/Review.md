# Ebbinghaus Review & Log Core (SQLite Version)

## 1. Time-Wheel Filtering Algorithm
1. 获取当前的系统 Unix 时间戳：`Math.floor(Date.now() / 1000)`
2. 调用 `db.getDueReviews(currentTime)` 筛选出所有满足 `next_review_time <= 当前时间戳` 的过期词汇池

## 2. Operational Modules

### 2.1 今日数据归纳
1. 调用 `db.getLogsByDate('2026-08-08')` 读取今日日志
2. 过滤出今日新增的单词名字
3. 严格按照 `[名词/动词/形容词/副词]` 分类编排罗列给人类
4. **遗忘风险预测**：明确标出针对用户所考的 `target_exam` 而言，哪 3 个词在考题中设伏最深、明天最容易忘记

### 2.2 到期抽测
1. 调用 `db.getDueReviews()` 获取到期复习列表
2. 根据单词，调用 `db.getWord(word)` 获取单词详情
3. 针对 `target_exam` 的常考题型，混合组装 5 道硬核测试题（如考研侧重英译中与长难句选词，托福雅思侧重语境造句）
4. **状态机回写 (State Transition)**：
   - 若答对：调用 `db.updateReviewStage(word, true)` 提升艾宾浩斯 `stage` 级别，推迟下一次复习时间
   - 若答错：调用 `db.updateReviewStage(word, false)` 该词的 `stage` 立即强制**回滚至 Stage 1**，24 小时后重新抽测
5. 调用 `db.addLog(date, 'review', count)` 记录复习日志

## 3. Node.js Execution Template
```javascript
const db = require('../db.js');

// 获取当前时间戳
const now = Math.floor(Date.now() / 1000);

// 获取到期复习
const dueWords = db.getDueReviews(now);
console.log(`到期复习: ${dueWords.length} 个单词`);

// 获取今日日志
const todayLogs = db.getLogsByDate('2026-08-08');
console.log('今日日志:', todayLogs);

// 处理复习结果
function handleReviewResult(word, isCorrect) {
    const result = db.updateReviewStage(word, isCorrect);
    if (result) {
        console.log(`${word}: Stage ${result.stage}, 下次复习: ${result.next_review_time}`);
    }
}

// 记录复习日志
db.addLog('2026-08-08', 'review', dueWords.length);
```

## 4. Stage Transition Rules
| 当前Stage | 答对后 | 答错后 |
|-----------|--------|--------|
| 1 | Stage 2 (+2天) | Stage 1 (+1天) |
| 2 | Stage 3 (+4天) | Stage 1 (+1天) |
| 3 | Stage 4 (+8天) | Stage 1 (+1天) |
| 4 | Stage 5 (+16天) | Stage 1 (+1天) |
| 5 | 保持Stage 5 (+32天) | Stage 1 (+1天) |
