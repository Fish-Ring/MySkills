---
name: English_Vocabulary_Coach
description: 本地优先、多考试自适应的英语词汇与听说读写硬核教练（sqlite3 CLI 版）
version: 2.2.0
entrypoint: SKILL.md
---

# 英语词汇教练（English Vocabulary Coach）

> **系统提示词**：`./SYSTEM_PROMPT.md` 是完全自包含的助手提示词，直接复制到 RikkaHub 助手的系统提示词中即可。本文件是技能目录内的说明与 API 参考。

## 环境要求

| 依赖 | 说明 |
|------|------|
| Node.js ≥ 16 | 驱动 db.js |
| sqlite3 CLI | `apt install sqlite3`（Debian/Ubuntu）；db.js 通过命令行操作数据库 |

- **零 npm 依赖**：无需 `npm install`。
- 数据库文件：`./vocabulary.db`（自动建库建表）。
- 可选环境变量：`ENGLISH_DB_PATH`（库路径）、`SQLITE3_BIN`（sqlite3 可执行文件路径）。

## 文件结构

```
English_Vocabulary_Coach/
├── SKILL.md              # 本文件（技能入口 + API 参考）
├── SYSTEM_PROMPT.md      # 自包含系统提示词（复制进助手）
├── README.md             # 使用说明
├── db.js                 # 数据库操作层（sqlite3 CLI 后端）
├── migrate.js            # v1 JSON 数据迁移脚本（可选）
├── package.json          # 元信息（无依赖）
├── schemas/
│   └── Schemas.md        # 数据库 schema
└── modules/
    ├── Vocab.md          # 词汇处理模块
    ├── Exercise.md       # 实战训练模块
    └── Review.md         # 复习引擎模块
```

## 快速自检

```bash
node -e "console.log(JSON.stringify(require('./db.js').getStats(), null, 2))"
```

输出包含 `backend: "sqlite3-cli"`、`target_exam`、到期复习数即正常。

## 数据库 API 参考

### 用户配置

| 函数 | 说明 |
|------|------|
| `getProfile()` | `{target_exam, vocabulary_level, grammar_basis, total_words_count}` |
| `updateProfile({...})` | 更新配置字段（仅允许上列四个字段） |
| `setTargetExam(exam)` | 设置目标考试 |

### 单词

| 函数 | 说明 |
|------|------|
| `getWord(word)` | 查询单词（collocation 自动解析为数组） |
| `wordExists(word)` | 是否已收录 |
| `addWord({word,pos,meaning,frequency,collocation,example,tips,tag})` | 添加/更新单词（collocation 传数组） |
| `getAllWords()` / `getWordsByTag(tag)` | 全量 / 按标签 |
| `getRecentWords(n)` / `getRandomWords(n)` | 最近 / 随机 n 个 |

### 复习队列（艾宾浩斯）

间隔 `[86400, 172800, 345600, 691200, 1382400]` 秒 = 1/2/4/8/16 天。答对升档、答错回 Stage 1；Stage 5 再答对移出队列。

| 函数 | 说明 |
|------|------|
| `addToReviewQueue(word, stage=1)` | 加入队列（next_review_time 自动计算；复用已有行不累积） |
| `getReviewQueue()` / `getDueReviews(currentTime?)` | 待复习 / 到期任务 |
| `updateReviewStage(word, correct, currentTime?)` | 更新阶段；返回 `{word, stage, next_review_time}` 或 null |
| `removeFromReviewQueue(word)` | 移除 |

### 日志与统计

| 函数 | 说明 |
|------|------|
| `addLog(date, type, count=1)` | 记日志（type ∈ vocab_search/exercise/review，同日同类型自动累加） |
| `getLogs()` / `getLogsByDate(date)` | 查询日志 |
| `getTodayStats()` | 今日 `{date, vocab_search, exercise, review}` |
| `getStats()` | 总览（含 backend、due_reviews、today） |
