# Learning Assistant (通用学习助手) v1.3.1

任意学科的错题追踪 + 薄弱点分析 + 艾宾浩斯复习引擎。**零 Node/npm 依赖**，只需 sqlite3 命令行工具。

## 快速开始

```bash
# Debian/Ubuntu rootfs（RikkaHub 工作区等）
apt install -y sqlite3

sh /workspace/learning-assistant/selfcheck.sh
# 本地开发：cd Skills/learning-assistant && sh selfcheck.sh
# 自定义库路径：LEARNING_DB=/tmp/test.db sh selfcheck.sh
```

## 搭配 RikkaHub 使用

1. 在 APP 中创建工作区（rootfs），把本目录内容放入工作区，推荐路径 `/workspace/learning-assistant/`
2. 在工作区内执行 `apt install -y sqlite3`，运行 `sh /workspace/learning-assistant/selfcheck.sh` 验证
3. 新建助手，把 `SYSTEM_PROMPT.md` 全文粘贴到助手的系统提示词中（已内置技能目录定位与 find 回退，整仓克隆等其他布局也能自动适配）
4. 首次对话会自动扫描旧库并引导初始化（考试代码确认 → 分科建档 → 档案收集）

## 文件结构

```
learning-assistant/
├── SKILL.md              # 技能入口 + SQL 操作参考
├── SYSTEM_PROMPT.md      # 自包含系统提示词（复制进助手）
├── README.md             # 本文件
├── selfcheck.sh          # 环境自检脚本
├── package.json          # 元信息（无依赖）
├── schemas/
│   ├── schema.sql        # 表结构（幂等，建库唯一入口）
│   ├── queries.sql       # 全部业务 SQL 模板
│   └── Schemas.md        # 数据库设计说明
└── modules/              # Vocab / Exercise / Review 功能模块（含 SQL 步骤）
```

## 核心机制

| 机制 | 说明 |
|------|------|
| 问答流水线 | 提问 → 检索三路（历史相似问题/相关知识点/关联薄弱点）→ 作答 → 先查重入库 → 薄弱点定级 |
| questions 表 | 记录每个问题及 times_asked——问过的问题重复提问会被识别为薄弱信号 |
| 薄弱点口径 | `wrong_count > correct_count OR mastery_level < 0.6`；错题多的知识点出题概率约 ×2 |
| 艾宾浩斯 | 1/2/4/8/16 天五档；答错回 Stage 1，Stage 5 答对移出队列 |

## 数据操作约定

- 建库唯一入口：`sqlite3 <技能目录>/learner.db < schemas/schema.sql`（幂等）
- 业务 SQL 全部在 `schemas/queries.sql` 中，AI 执行前先读它
- 铁律：INSERT 前必 SELECT 查重；写入用事务 + `.timeout 5000`
- 环境变量：`LEARNING_DB`（仅 selfcheck.sh 用，指定库路径）
