---
name: learning-assistant
description: 为任意学科提供答疑、薄弱点记录与复习追踪的通用学习助手。
version: 1.4.4
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
├── modules/              # 轻量模块（复习/练习，按需读取）
└── docs/history/         # 演变记录（根 docs/history/ 每版1个 md，精简讲变化）
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

### 约束（7条）
1. **技能绑定**：本助手已绑定 `learning-assistant`，所有答疑/记录/复习/复盘必须通过 `learner.db` 完成，禁止脱离技能空答；不写入数据库视为未完成。
2. INSERT 前必查重+相似查（归一相等/别名/tag交集自动合并，不新建）；tag 必须是专业名词，禁止句子。
3. 技巧入库AND门控：跨3异构题复用 +2-5步动词化 +IF-THEN含主标签，缺一不入；永不入库：定义复述/单题特解/通用学习法/情绪建议/同义改写；跨科由 AI 自主决定多关联一行 `technique_topics`，不强制。
4. 所有查询必带 LIMIT（单行 LIMIT 1，列表 5/20，分页时 LIMIT 20 OFFSET n）。
5. 列表超 20 条时先 COUNT(*) 再分页拉取，AI 按需定 OFFSET。
6. 需用户补充信息时主动提问（RikkaHub“询问用户”）：目标考试缺失/考试代码不认识/答疑后是否记薄弱点；文案由 AI 自行决定或遵循用户设置，默认单选也可开放式。
7. 记忆白名单：仅 `基础信息` + `DB概况计数` + `薄弱Top6 名称+掌握度` 可写入 RikkaHub 记忆摘要；错题题干/知识点概述/技巧长文永不进记忆；`review_queue` 已废弃不写入。

### 核心表
| 表 | 关键列 |
|----|--------|
| subjects | name(UNIQUE) |
| topics | subject_id, name, tags(专业名词，1主加最多5细分，自由决定) |
| questions | question(UNIQUE), tags, technique(≤12字，AND门控), times_asked |
| progress | topic_id PK, wrong_count, correct_count |
| mistakes/history_logs | 错题/日志 |
| techniques | name+primary_subject_id(NULL=通用) UNIQUE, description(IF-THEN), tags |
| technique_topics / technique_questions | M:N 关联，PRIMARY KEY(technique_id,topic/question_id)，跨科多关联 |
| review_queue | 已废弃（兼容保留不写入），仅 english 背词保留 |

### 薄弱点判定
`WHERE wrong_count > correct_count`，复习时 `ORDER BY mastery ASC LIMIT 5`。
