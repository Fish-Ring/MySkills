# Learning Assistant (通用学习助手) v1.2.0

任意学科的错题追踪 + 薄弱点分析 + 艾宾浩斯复习引擎。**零 npm 依赖**，只需 Node.js ≥ 16 和 sqlite3 命令行工具。

## 快速开始

```bash
# Debian/Ubuntu rootfs（RikkaHub 工作区等）
apt install -y sqlite3

node /workspace/learning-assistant/selfcheck.js
# 本地开发：cd Skills/learning-assistant && node selfcheck.js
```

## 搭配 RikkaHub 使用

1. 在 APP 中创建工作区（rootfs），把本目录内容放入工作区，推荐路径 `/workspace/learning-assistant/`
2. 在工作区内执行 `apt install -y sqlite3`，运行 `node /workspace/learning-assistant/selfcheck.js` 验证
3. 新建助手，把 `SYSTEM_PROMPT.md` 全文粘贴到助手的系统提示词中（已内置技能目录定位与 find 回退，整仓克隆等其他布局也能自动适配）
4. 首次对话会自动引导初始化档案（学科 / 目标考试 / 阶段 / 目标日期）

## 文件结构

```
learning-assistant/
├── SKILL.md              # 技能入口 + API 参考
├── SYSTEM_PROMPT.md      # 自包含系统提示词（复制进助手）
├── README.md             # 本文件
├── selfcheck.js          # 环境自检脚本
├── db.js                 # 数据库操作层（sqlite3 CLI 后端）
├── package.json          # 元信息（无依赖）
├── schemas/Schemas.md    # 数据库 schema
└── modules/              # Vocab / Exercise / Review 功能模块
```

## API

完整签名见 `SKILL.md`。常用：

| 函数 | 说明 |
|------|------|
| `getProfile()` / `updateProfile({exam,stage,exam_date})` | 用户档案 |
| `addSubject(name)` / `addTopic(subjectId, name)` | 科目与知识点 |
| `getTopic(null, '关键词')` | 模糊匹配最佳知识点 |
| `addMistake(topicId, question, wrongAnswer, correctAnswer, explanation)` | 记错题（自动累计掌握度统计） |
| `updateProgress(topicId, isCorrect)` | 更新掌握度 |
| `getWeakPoints(n)` | 薄弱点 Top N |
| `addToReviewQueue(topicId, stage)` / `getDueReviews()` / `updateReviewStage(topicId, correct)` | 艾宾浩斯队列 |
| `getTodayStats()` / `getStats()` | 今日与总览统计 |

## 环境变量

| 变量 | 默认 | 说明 |
|------|------|------|
| `LEARNING_DB_PATH` | `./learner.db` | 数据库文件路径 |
| `SQLITE3_BIN` | `sqlite3` | sqlite3 可执行文件路径 |
