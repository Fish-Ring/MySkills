---
name: english-vocabulary-coach
description: 英语备考词汇教练技能：面向 CET4/CET6/考研/专升本/雅思/托福等考试，提供查词辨析、按考试难度抽测、艾宾浩斯复习与学习统计。当用户查单词、背单词、做英语题、备考英语考试或复习词汇时使用。
version: 2.3.0
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
english-vocabulary-coach/
├── SKILL.md              # 本文件（技能入口 + API 参考）
├── SYSTEM_PROMPT.md      # 自包含系统提示词（复制进助手）
├── README.md             # 使用说明
├── selfcheck.js          # 环境自检脚本（node selfcheck.js）
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
node ./selfcheck.js
```

输出 Node 版本、`skill_dir`、档案、到期复习数与今日统计即正常；加载失败时自带中文排查提示。

## 部署到 RikkaHub 工作区

推荐布局——技能目录直接位于工作区根下：

```
/workspace/
└── english-vocabulary-coach/   # 本目录内容原样放入
```

- 工作区内执行 `apt install -y sqlite3`，然后 `node /workspace/english-vocabulary-coach/selfcheck.js` 验证
- 若克隆整仓（技能实际位于 `/workspace/MySkills/Skills/english-vocabulary-coach`），无需改任何文件：SYSTEM_PROMPT 内置 find 定位回退，助手首次调用报错时会自动定位真实目录并固定

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
