---
name: learning-assistant
description: 为任意学科提供答疑、薄弱点记录与复习追踪的通用学习助手。
version: 1.5.2
entrypoint: SKILL.md
---

# 通用学习助手（Learning Assistant）

> **系统提示词**：`./SYSTEM_PROMPT.md` 是开箱即用的助手提示词，直接复制到 RikkaHub 助手的系统提示词中即可（执行前须先读技能目录 `schemas/queries.sql` 模板与仓库根 `docs/history/`）。本文件是技能目录内的说明与 SQL 操作参考。

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
├── modules/              # Review/Exercise/Vocab 三轻量模块（复习/练习/问答兼容，按需读取）
└── docs/history/         # 演变记录（仓库根 docs/history/，技能目录内无此目录）
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
`'` 拼入 SQL 前写成 `''`；中文撇号一律 `′`(U+2032)；写入一律 heredoc 内联事务，禁落文件。完整模板见 `schemas/queries.sql`。

### 约束（8条）
1. **技能绑定**：本助手已绑定 `learning-assistant`，所有答疑/记录/复习/复盘必须通过 `learner.db` 完成，禁止脱离技能空答；不写入数据库视为未完成。
2. INSERT 前必查重+相似查（归一相等/别名/tag交集自动合并，不新建）；tag 必须是专业名词，禁止句子。
3. 技巧入库AND门控：跨3异构题复用 +2-5步动词化 +IF-THEN含主标签，缺一不入；永不入库：定义复述/单题特解/通用学习法/情绪建议/同义改写；跨科由 AI 自主决定多关联一行 `technique_topics`，不强制。
4. 所有查询必带 LIMIT（单行1/列表5/聚合10/分页20+OFFSET）。
5. 列表超 20 条时先 COUNT(*) 再分页拉取，AI 按需定 OFFSET。
6. 需用户补充信息时主动提问（RikkaHub“询问用户”）：目标考试缺失/考试代码不认识/答疑后是否记薄弱点；根据实际情况决定形式，能开放式问清用 `text`，单选必须带“以上都不是/我自己说”兜底；文案由 AI 自行决定或遵循用户设置。
7. 记忆白名单：仅 `基础信息` + `DB概况计数` + `薄弱Top6 名称+掌握度` 可写入 RikkaHub 记忆摘要；错题题干/知识点概述/技巧长文永不进记忆；`review_queue` 已废弃不写入。
8. 三实体不混：`progress`=Mastery长期状态 / `misconceptions`=可复用认知模式（concept/formula/calculation/thinking/careless）/ `mistakes`=单次错误事件；错题判型后关联双M:N，同一事务重算 `mastery_score/status`。表格禁裸 `|`（绝对值 `\lvert x \rvert`，或写中文）、禁 `\|`、`\sum` 必带上下限、输出表格前自查有无 `|`。

### 核心表
| 表 | 关键列 |
|----|--------|
| subjects | name(UNIQUE) |
| topics | subject_id, name, tags(专业名词，1主加最多5细分，自由决定) |
| questions | question(UNIQUE), tags, technique(≤12字，AND门控), source/difficulty(出题加权), times_asked |
| question_topics | 副知识点 M:N，PRIMARY KEY(question_id,topic_id), weight |
| progress | topic_id PK, wrong/correct_count, consecutive_correct, mastery_score(0-100), status |
| mistakes | 单次错误事件；关联 misconceptions 走 mistake_misconceptions M:N |
| misconceptions | title+type UNIQUE, occurrence_count, resolved, confidence |
| knowledge_misconception | 知识点-错误 M:N，severity 1-5 |
| history_logs | 日志（qa/mistake/review/exercise；通用技能不写 vocab_search） |
| user_profile | exam/stage/exam_date，种子行 id=1 |
| techniques | name+primary_subject_id(NULL=通用) UNIQUE, description(IF-THEN), tags |
| technique_topics / technique_questions | M:N 关联，PRIMARY KEY(technique_id,topic/question_id)，跨科多关联 |
| review_queue | 已废弃（兼容保留不写入），仅 english 背词保留 |

### 薄弱点判定
`WHERE status='weak' ORDER BY mastery_score ASC LIMIT 5`（兼容口径 `wrong_count>correct_count`）。
