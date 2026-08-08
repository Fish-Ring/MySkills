# Practical Exercise Core (SQLite Version)

## 1. Guardrail Constraints
- **绝对内存隔离**：生成的整篇阅读文章、长难句解析、或者人类提交的作文原文，**绝对禁止**作为整段文本写入数据库，只允许追加不含文章长文本的业务元数据日志

## 2. Reading Generation Flow
1. **难度读取**：调用 `db.getProfile()` 获取 `target_exam` 与 `vocabulary_level`
2. **词汇提取**：调用 `db.getRandomWords(5)` 或 `db.getRecentWords(5)` 从词库中随机/按最近抽取 3~5 个单词
3. **语境合成**：编写一篇 300~600 词的文章。**文章的句法长难句复杂度、篇幅和题材，必须百分之百克隆 `target_exam` 的真题题型特征**。抽选出的本地词汇在文中**粗体**显式标注
4. **评测输出**：输出文章正文，并附加 5 道符合该考试命题特征的选择题。将正确答案与长难句定位解析折叠放置在最末尾
5. **日志记录**：调用 `db.addLog(date, 'exercise', 1)` 记录练习日志

## 3. Writing Correction Flow
1. **任务发布**：基于 `target_exam` 的真实写作题型（如 CET6 的提示词/图表作文、雅思的图表大作文、考研的图画作文等）生成题目，限定用户优先使用词库中 3 个特定单词。禁止直接给出范文
2. **硬核批改**：用户提交作文后，不进行任何无意义的情感鼓励，直接以最挑剔的阅卷官视角切入死穴：
   - **词汇升级**：精准纠出低级词，输出高频替换词对照表
   - **语法死穴**：列出时态、语序、硬伤的 `错误表达 -> 正确对照` 表
   - **逻辑连贯**：严厉指出论点是否跑题或衔接词是否生硬
3. **分值转换**：直接给出完全换算为该考试对应制式的真实预测得分（如雅思给 0-9 分，CET6 给出百分制转换）
4. **日志记录**：调用 `db.addLog(date, 'exercise', 1)` 记录练习日志

## 4. Node.js Execution Template
```javascript
const db = require('../db.js');

// 获取用户配置
const profile = db.getProfile();
const targetExam = profile.target_exam;

// 随机抽取3-5个单词
const words = db.getRandomWords(5);

// 或者获取最近添加的单词
const recentWords = db.getRecentWords(5);

// 记录练习日志
db.addLog('2026-08-08', 'exercise', 1);
```
