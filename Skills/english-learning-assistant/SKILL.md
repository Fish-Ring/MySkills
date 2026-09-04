---
name: english-learning-assistant
description: 提供查词、阅读与写作批改、精读讲解与生词复习的英语学习助手。
version: 2.5.0
entrypoint: SKILL.md
---

# 英语学习助手（English Learning Assistant）

> **系统提示词**：`./SYSTEM_PROMPT.md` 是完全自包含的助手提示词，直接复制到 RikkaHub 助手的系统提示词中即可。本文件是技能目录内的说明与 SQL 操作参考。

## 环境要求

| 依赖 | 说明 |
|------|------|
| sqlite3 CLI | 唯一依赖，`apt install sqlite3`（Debian/Ubuntu） |

- **零 Node/npm 依赖**：所有数据操作通过 sqlite3 命令行完成。
- 数据库文件：`<技能目录>/vocabulary.db`（首次用 schema.sql 幂等建库建表）。

## 文件结构

```
english-learning-assistant/
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
    ├── Vocab.md          # 词汇解析模块（含入库三件套）
    ├── Exercise.md       # 实战训练模块
    └── Review.md         # 复习与日志模块
```

## 快速自检

```bash
sh ./selfcheck.sh
```

输出 sqlite3 版本、各表行数、到期复习数、target_exam 即正常；缺 sqlite3 时给出安装命令。

## 部署到 RikkaHub 工作区

推荐布局——技能目录直接位于工作区根下：

```
/workspace/
└── english-learning-assistant/   # 本目录内容原样放入
```

- 工作区内执行 `apt install -y sqlite3`，然后 `sh /workspace/english-learning-assistant/selfcheck.sh` 验证
- 若克隆整仓（技能实际位于 `/workspace/MySkills/Skills/english-learning-assistant`），无需改任何文件：SYSTEM_PROMPT 内置 find 定位回退，助手首次调用报错时会自动定位真实目录并固定

## SQL 操作参考

### 数据库操作三式

```bash
# 1. 查询（结构化 JSON 输出）
sqlite3 -json <技能目录>/vocabulary.db "SELECT ..."

# 2. 写入（多条语句包事务，.timeout 防锁）
sqlite3 <技能目录>/vocabulary.db <<'SQL'
.timeout 5000
BEGIN;
...;
COMMIT;
SQL

# 3. 建库/补表（幂等）
sqlite3 <技能目录>/vocabulary.db < <技能目录>/schemas/schema.sql
```

完整模板见 `schemas/queries.sql`；表契约见 `schemas/Schemas.md`。执行前先读它们，不要凭记忆写 SQL。

### 铁律

1. **技能绑定**：本助手已绑定 `english-learning-assistant`，所有查词/精读/批改/复习必须通过 `vocabulary.db` 完成，禁止脱离技能空答；不写入数据库视为未完成。
2. 任何 INSERT 前先 SELECT 查重（单词按 `words.word`）；命中即复用。例句/释义中的单引号写成 `''` 再拼 SQL。
3. 数据库报错时原样告知用户并重试一次，再失败给修复命令。
4. 需用户补充信息时主动提问（RikkaHub“询问用户”）：档案缺失/是否入库生词/是否逐段精读；文案由 AI 自行决定或遵循用户设置，默认单选也可开放式。

### 核心表速览

| 表 | 用途 | 关键列 |
|----|------|--------|
| user_profile | 用户配置 | target_exam, vocabulary_level, grammar_basis, total_words_count |
| words | 词库 | word(UNIQUE), pos, meaning, frequency, collocation(JSON), tag, created_at |
| review_queue | 艾宾浩斯队列 | word, stage(1~5), next_review_time, is_reviewed |
| history_logs | 学习日志 | date, type(vocab_search/exercise/review), count, UNIQUE(date,type) |

### 艾宾浩斯规则

间隔 `[86400, 172800, 345600, 691200, 1382400]` 秒 = 1/2/4/8/16 天。答对升档、答错回 Stage 1；Stage 5 再答对移出队列。回写模板见 queries.sql「复习完成」。
