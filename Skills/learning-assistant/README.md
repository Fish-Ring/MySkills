# Learning Assistant (通用学习助手) v1.4.0

预答→精查薄弱点，2次查库封顶。**零 Node/npm 依赖**，只需 sqlite3。

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
└── modules/              # 轻量模块（复习/练习，按需）
```

## 核心机制

| 机制 | 说明 |
|------|------|
| 问答 | 预答草拟2-3个要点 → 批量 IN 精查本科目薄弱点 → 薄弱点感知作答 → 探针确认后才记 wrong_count |
| 记录 | questions 总是 times_asked+1；仅确认不会时 progress wrong_count+1 |
| 复习 | 仅用户说复习/总结时查 progress TopN，不做 Stage 自动调度 |

## 数据操作约定

- 建库唯一入口：`sqlite3 <技能目录>/learner.db < schemas/schema.sql`（幂等）
- 业务 SQL 全部在 `schemas/queries.sql` 中，AI 执行前先读它
- 铁律：INSERT 前必 SELECT 查重；写入用事务 + `.timeout 5000`
- 环境变量：`LEARNING_DB`（仅 selfcheck.sh 用，指定库路径）
