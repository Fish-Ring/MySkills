# English Vocabulary Coach (英语词汇教练) v2.3.0

本地优先、多考试自适应的英语词汇教练。**零 npm 依赖**，只需 Node.js ≥ 16 和 sqlite3 命令行工具。

## 快速开始

```bash
# Debian/Ubuntu rootfs（RikkaHub 工作区等）
apt install -y sqlite3

node /workspace/english-vocabulary-coach/selfcheck.js
# 本地开发：cd Skills/english-vocabulary-coach && node selfcheck.js
```

## 搭配 RikkaHub 使用

1. 在 APP 中创建工作区（rootfs），把本目录内容放入工作区，推荐路径 `/workspace/english-vocabulary-coach/`
2. 在工作区内执行 `apt install -y sqlite3`，运行 `node /workspace/english-vocabulary-coach/selfcheck.js` 验证
3. 新建助手，把 `SYSTEM_PROMPT.md` 全文粘贴到助手的系统提示词中（已内置技能目录定位与 find 回退，整仓克隆等其他布局也能自动适配）
4. 首次对话会要求设置目标考试（CET4 / CET6 / 考研英语 / 雅思 / 托福等）

## 文件结构

```
english-vocabulary-coach/
├── SKILL.md              # 技能入口 + API 参考
├── SYSTEM_PROMPT.md      # 自包含系统提示词（复制进助手）
├── README.md             # 本文件
├── selfcheck.js          # 环境自检脚本
├── db.js                 # 数据库操作层（sqlite3 CLI 后端）
├── migrate.js            # v1 JSON 数据迁移脚本（可选）
├── package.json          # 元信息（无依赖）
├── schemas/Schemas.md    # 数据库 schema
└── modules/              # Vocab / Exercise / Review 功能模块
```

## API

完整签名见 `SKILL.md`。常用：

| 函数 | 说明 |
|------|------|
| `getProfile()` / `setTargetExam(exam)` | 用户配置 |
| `getWord(word)` / `wordExists(word)` | 查词（collocation 自动解析为数组） |
| `addWord({word,pos,meaning,frequency,collocation,example,tips,tag})` | 收录单词 |
| `getRandomWords(n)` / `getRecentWords(n)` / `getWordsByTag(tag)` | 取词出题 |
| `addToReviewQueue(word, stage)` / `getDueReviews()` / `updateReviewStage(word, correct)` | 艾宾浩斯队列 |
| `addLog(date, type, count)` / `getTodayStats()` / `getStats()` | 日志与统计 |

## 环境变量

| 变量 | 默认 | 说明 |
|------|------|------|
| `ENGLISH_DB_PATH` | `./vocabulary.db` | 数据库文件路径 |
| `SQLITE3_BIN` | `sqlite3` | sqlite3 可执行文件路径 |

## 从 v1 JSON 数据迁移

```bash
node migrate.js --state ./path/user_state.json
```
