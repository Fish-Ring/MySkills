---
name: learning-assistant
description: 通用学习教练技能：答疑时自动感知本科目薄弱点并针对性讲解，相似知识点/问题自动合并，查询全限流，通过 SQLite 持久追踪。
version: 1.4.1
entrypoint: SKILL.md
---

# 通用学习助手（Learning Assistant）

> **系统提示词**：`./SYSTEM_PROMPT.md` 是完全自包含的助手提示词，直接复制到 RikkaHub 助手的系统提示词中即可。本文件是技能目录内的说明与 SQL 操作参考。

## 环境要求

| 依赖 | 说明 |
|------|------|
| sqlite3 CLI | 唯一依赖，`apt install sqlite3` |

- 数据库文件：`<技能目录>/learner.db`（首次用 `schemas/schema.sql` 幂等建库）。

## 文件结构

```
learning-assistant/
├── SKILL.md              # 本文件（技能入口 + SQL 参考）
├── SYSTEM_PROMPT.md      # 自包含系统提示词（复制进助手）
├── README.md
├── selfcheck.sh          # 环境自检脚本（sh selfcheck.sh）
├── package.json
├── schemas/
│   ├── schema.sql        # 表结构（幂等）
│   ├── queries.sql       # 业务 SQL 模板（精简版）
│   └── Schemas.md
└── modules/              # 轻量模块（复习/练习，按需读取）
```

## 快速自检

```bash
sh ./selfcheck.sh
```

## 部署到 RikkaHub 工作区

```
 /workspace/learning-assistant/     # 推荐，整仓克隆也能通过 find 自动适配
```
`apt install -y sqlite3` 后 `sh /workspace/learning-assistant/selfcheck.sh` 验证。

## SQL 操作参考

```bash
# 查询
sqlite3 -json <技能目录>/learner.db "SELECT ..."
# 写入（事务）
sqlite3 <技能目录>/learner.db <<'SQL'
.timeout 5000
BEGIN; ...; COMMIT;
SQL
# 建库
sqlite3 <技能目录>/learner.db < <技能目录>/schemas/schema.sql
```
`'` 拼入 SQL 前写成 `''`。完整模板见 `schemas/queries.sql`。

### 约束（3条）
1. INSERT 前必查重+相似查（归一相等/别名交集自动合并，不新建）。
2. 所有查询必带 LIMIT（单行 LIMIT 1，列表 5/20/50）。
3. 不认识的考试代码直接问用户包含哪些科目。

### 核心表
| 表 | 关键列 |
|----|--------|
| subjects | name(UNIQUE) |
| topics | subject_id, name, UNIQUE(subject_id,name) |
| questions | question(UNIQUE), times_asked |
| progress | topic_id PK, wrong_count, correct_count |
| mistakes/history_logs | 错题/日志 |
| review_queue | 兼容保留，新版仅轻量复习用 progress TopN |

### 薄弱点判定
`WHERE wrong_count > correct_count`，复习时 `ORDER BY mastery ASC LIMIT 5`。
