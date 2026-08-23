---
name: learning-assistant
description: 通用学习教练技能：支持任意学科的知识点讲解、出题练习、错题记录与艾宾浩斯复习，通过 SQLite 持久追踪薄弱点，随用户提问自动采集知识漏洞。当用户想学习或查询知识点、做题练习、记录错题、分析薄弱点或安排复习总结时使用。
version: 1.2.0
entrypoint: SKILL.md
---

# 通用学习助手（Learning Assistant）

> **系统提示词**：`./SYSTEM_PROMPT.md` 是完全自包含的助手提示词，直接复制到 RikkaHub 助手的系统提示词中即可。本文件是技能目录内的说明与 API 参考。

## 环境要求

| 依赖 | 说明 |
|------|------|
| Node.js ≥ 16 | 驱动 db.js |
| sqlite3 CLI | `apt install sqlite3`（Debian/Ubuntu）；db.js 通过命令行操作数据库 |

- **零 npm 依赖**：无需 `npm install`。
- 数据库文件：`./learner.db`（自动建库建表）。
- 可选环境变量：`LEARNING_DB_PATH`（库路径）、`SQLITE3_BIN`（sqlite3 可执行文件路径）。

## 文件结构

```
learning-assistant/
├── SKILL.md              # 本文件（技能入口 + API 参考）
├── SYSTEM_PROMPT.md      # 自包含系统提示词（复制进助手）
├── README.md             # 使用说明
├── selfcheck.js          # 环境自检脚本（node selfcheck.js）
├── db.js                 # 数据库操作层（sqlite3 CLI 后端）
├── package.json          # 元信息（无依赖）
├── schemas/
│   └── Schemas.md        # 数据库 schema
└── modules/
    ├── Vocab.md          # 知识点讲解模块
    ├── Exercise.md       # 练习模块
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
└── learning-assistant/     # 本目录内容原样放入
```

- 工作区内执行 `apt install -y sqlite3`，然后 `node /workspace/learning-assistant/selfcheck.js` 验证
- 若克隆整仓（技能实际位于 `/workspace/MySkills/Skills/learning-assistant`），无需改任何文件：SYSTEM_PROMPT 内置 find 定位回退，助手首次调用报错时会自动定位真实目录并固定

## 数据库 API 参考

### 用户档案

| 函数 | 说明 |
|------|------|
| `getProfile()` | 获取用户档案 `{exam, stage, exam_date}` |
| `updateProfile({exam, stage, exam_date})` | 更新档案（仅允许这三个字段） |
| `setExam(exam)` / `setStage(stage)` / `setExamDate(date)` | 单字段便捷写入 |

### 科目 / 知识点

| 函数 | 说明 |
|------|------|
| `addSubject(name, fullName?, weight?)` | 添加科目，幂等；返回 `{id, created}` |
| `getAllSubjects()` / `getSubject(id)` | 查询科目 |
| `addTopic(subjectId, name, parentId?, examWeight?)` | 添加知识点；返回 `{id, created}` |
| `getTopics(subjectId?, keyword?)` | 模糊搜索知识点列表 |
| `getTopic(idOrKeyword, keywordHint?)` | 按 id 查询；传字符串或 `(null,'关键词')` 时模糊匹配返回最佳单个结果 |

### 错题 / 掌握度

| 函数 | 说明 |
|------|------|
| `addMistake(topicId, question, wrongAnswer, correctAnswer, explanation)` | 记错题（同题重复自动累计 mistake_count），同步累计 progress.wrong_count 并写日志 |
| `updateProgress(topicId, isCorrect)` | 更新掌握度（首答保守起步，不会一答对就 100%），自动写练习日志 |
| `getMistakesByTopic(topicId)` | 该知识点错题列表 |
| `getWeakPoints(n)` | 错误最多的 n 个知识点（出题加权依据） |

### 复习队列（艾宾浩斯）

间隔 `[1, 2, 4, 8, 16]` 天。答对升档、答错回 Stage 1；Stage 5 再答对移出队列。

| 函数 | 说明 |
|------|------|
| `addToReviewQueue(topicId, stage=1)` | 加入/重置队列（复用已有行，不累积） |
| `getReviewQueue()` | 全部待复习 |
| `getDueReviews(currentTime?)` | 到期任务（启动时必须检查并提醒） |
| `updateReviewStage(topicId, correct)` | 更新阶段；返回 `{topic_id, stage, next_review_at}` 或 `null` |
| `removeFromReviewQueue(topicId)` | 移除 |

### 日志与统计

`history_logs` 按 `(date, type)` 去重累加，type ∈ `vocab_search / exercise / mistake / review`。

| 函数 | 说明 |
|------|------|
| `addLog(type, count=1, date?=今天)` | 手动记日志（查词记 vocab_search；练习/错题/复习接口已自动记录） |
| `getLogsByDate(date)` / `getLogs()` | 查询日志 |
| `getTodayStats()` | `{date, vocab_search, exercise, mistake, review, accuracy}` |
| `getStats()` | 总览（含 backend、due_reviews、today） |
