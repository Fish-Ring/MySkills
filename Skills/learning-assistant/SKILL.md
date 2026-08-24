---
name: learning-assistant
description: 通用学习教练技能：支持任意学科的知识点讲解、出题练习、错题记录与艾宾浩斯复习，通过 SQLite 持久追踪薄弱点，随用户提问自动采集知识漏洞。当用户想学习或查询知识点、做题练习、记录错题、分析薄弱点或安排复习总结时使用。
version: 1.3.1
entrypoint: SKILL.md
---

# 通用学习助手（Learning Assistant）

> **系统提示词**：`./SYSTEM_PROMPT.md` 是完全自包含的助手提示词，直接复制到 RikkaHub 助手的系统提示词中即可。本文件是技能目录内的说明与 SQL 操作参考。

## 环境要求

| 依赖 | 说明 |
|------|------|
| sqlite3 CLI | 唯一依赖，`apt install sqlite3`（Debian/Ubuntu） |

- **零 Node/npm 依赖**：所有数据操作通过 sqlite3 命令行完成。
- 数据库文件：`<技能目录>/learner.db`（首次用 schema.sql 幂等建库建表）。

## 文件结构

```
learning-assistant/
├── SKILL.md              # 本文件（技能入口 + SQL 参考）
├── SYSTEM_PROMPT.md      # 自包含系统提示词（复制进助手）
├── README.md             # 使用说明
├── selfcheck.sh          # 环境自检脚本（sh selfcheck.sh）
├── package.json          # 元信息（无依赖）
├── schemas/
│   ├── schema.sql        # 表结构（幂等，可重复执行）
│   ├── queries.sql       # 全部业务 SQL 模板
│   └── Schemas.md        # 数据库设计说明
└── modules/
    ├── Vocab.md          # 知识问答模块（检索三路+入库+定级）
    ├── Exercise.md       # 练习模块（出题加权+判分落库模板）
    └── Review.md         # 复习引擎模块（今日总结+到期抽测）
```

## 快速自检

```bash
sh ./selfcheck.sh
```

输出 sqlite3 版本、各表行数、到期复习数、档案状态即正常；缺 sqlite3 时给出安装命令。

## 部署到 RikkaHub 工作区

推荐布局——技能目录直接位于工作区根下：

```
/workspace/
└── learning-assistant/     # 本目录内容原样放入
```

- 工作区内执行 `apt install -y sqlite3`，然后 `sh /workspace/learning-assistant/selfcheck.sh` 验证
- 若克隆整仓（技能实际位于 `/workspace/MySkills/Skills/learning-assistant`），无需改任何文件：SYSTEM_PROMPT 内置 find 定位回退，助手首次调用报错时会自动定位真实目录并固定

## SQL 操作参考

### 数据库操作三式

```bash
# 1. 查询（结构化 JSON 输出）
sqlite3 -json <技能目录>/learner.db "SELECT ..."

# 2. 写入（多条语句包事务，.timeout 防锁）
sqlite3 <技能目录>/learner.db <<'SQL'
.timeout 5000
BEGIN;
...;
COMMIT;
SQL

# 3. 建库/补表/旧库升级（幂等）
sqlite3 <技能目录>/learner.db < <技能目录>/schemas/schema.sql
```

完整模板见 `schemas/queries.sql`；表契约见 `schemas/Schemas.md`。执行前先读它们，不要凭记忆写 SQL。

### 三铁律

1. 任何 INSERT 前先 SELECT 查重：科目按 `subjects.name`、知识点按 `subject_id+name`、问题按 `questions.question`；命中即复用。文本值中的单引号写成 `''`。
2. 遇到陌生考试代码（如 408、396）先联网搜索构成，禁止瞎猜；无法联网时直接询问用户该代码包含哪些科目。
3. 分科硬规则：代码 ≠ 课程名——408 是专业课代码（计算机学科专业基础综合），内含数据结构、计算机组成原理、操作系统、计算机网络四门；完整考研科目为 政治 + 英语 + 数学 + 408。数学需确认数一/数二/数三再建科（范围不同）。

### 核心表速览

| 表 | 用途 | 关键列 |
|----|------|--------|
| user_profile | 用户档案 | exam, stage, exam_date |
| subjects | 科目 | name(UNIQUE), full_name, weight |
| topics | 知识点 | subject_id, name, keywords, UNIQUE(subject_id,name) |
| questions | 提问记录 | question(UNIQUE), times_asked, answer_digest, technique |
| mistakes | 错题 | topic_id, question, UNIQUE(topic_id,question,wrong_answer,correct_answer) |
| progress | 掌握度 | topic_id(PK), correct_count, wrong_count, mastery_level |
| review_queue | 艾宾浩斯队列 | topic_id, stage(1~5), next_review_at, is_reviewed |
| history_logs | 学习日志 | date, type(qa/exercise/mistake/review), count, UNIQUE(date,type) |

### 薄弱点判定

`WHERE wrong_count > correct_count OR mastery_level < 0.6`，按 `mastery_level ASC` 排序；错题多的知识点出题概率约 ×2。

### 艾宾浩斯规则

间隔 `[86400, 172800, 345600, 691200, 1382400]` 秒 = 1/2/4/8/16 天。答对升档、答错回 Stage 1；Stage 5 再答对移出队列。回写模板见 queries.sql「复习完成」。
