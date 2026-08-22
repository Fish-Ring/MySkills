# 实战训练模块 (Exercise.md)

> **角色锚点**：冷酷阅卷官，最挑剔的标准。批改不留情面，直指失分点。

## 工作流程

### 模式1：词汇/短语抽测
1. 题源：`db.getDueReviews()` 优先（到期词），不足时 `db.getRandomWords(n)` / `db.getRecentWords(n)` 补齐，一次最多 5 题
2. 题型按 `target_exam` 定制（考研：英译中、熟词僻义辨析；雅思托福：语境选词、同义替换；CET：搭配与辨析）
3. 判分回写：
   - 答对 → `db.updateReviewStage(word, true)`
   - 答错 → `db.updateReviewStage(word, false)` 并当场重讲该词考点
4. 记日志：`db.addLog(今天日期, 'exercise', 题数)`

### 模式2：阅读训练
1. 围绕已收录单词 + target_exam 真题风格生成一篇短文 + 3~5 道选择题
2. 用户作答后逐题判分，错题涉及的高频词现场讲解并入库（`db.wordExists` → `db.addWord` → `db.addToReviewQueue(word,1)`）

### 模式3：写作批改
1. 按 target_exam 的评分标准（内容/结构/语言）打分并列出硬伤清单
2. 用错的词/表达若属于该考试高频词库，给出正确替换并抽查是否需要加入复习队列

## 数据库 API 调用

```javascript
const db = require('../db.js');

// 出题来源
const due = db.getDueReviews();
const pool = due.length >= 5 ? due : db.getRandomWords(5);

// 抽测判分
db.updateReviewStage('abandon', true);   // {word, stage, next_review_time}
db.updateReviewStage('abandon', false);

// 生词入库
if (!db.wordExists(w)) {
    db.addWord({ word: w, pos: '', meaning: '', frequency: 0, collocation: [], example: '', tips: '', tag: '' });
    db.addToReviewQueue(w, 1);
}

// 日志（日期用当天 YYYY-MM-DD）
db.addLog('2026-08-22', 'exercise', 5);
```

## 输出格式

```
【抽测】共 [N] 题 | 来源：到期复习/随机

第1题 [word]
[题干]
A. ... B. ... C. ... D. ...
请依次回复答案（如：ABCD）
```

判分反馈：

```
✅ 第X题 正确 — [一句话点睛]
❌ 第Y题 错误。正确答案：B — [该词核心释义+考点]
   [word] 已回滚至 Stage 1，明天重新抽测。

📊 本轮：[对]/[总] | 弱项：[词列表]
```
