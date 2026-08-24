# English Vocabulary Coach (英语词汇教练) v2.4.0

本地优先、多考试自适应的英语词汇教练。**零 Node/npm 依赖**，只需 sqlite3 命令行工具。

## 快速开始

```bash
# Debian/Ubuntu rootfs（RikkaHub 工作区等）
apt install -y sqlite3

sh /workspace/english-vocabulary-coach/selfcheck.sh
# 本地开发：cd Skills/english-vocabulary-coach && sh selfcheck.sh
# 自定义库路径：VOCAB_DB=/tmp/test.db sh selfcheck.sh
```

## 搭配 RikkaHub 使用

1. 在 APP 中创建工作区（rootfs），把本目录内容放入工作区，推荐路径 `/workspace/english-vocabulary-coach/`
2. 在工作区内执行 `apt install -y sqlite3`，运行 `sh /workspace/english-vocabulary-coach/selfcheck.sh` 验证
3. 新建助手，把 `SYSTEM_PROMPT.md` 全文粘贴到助手的系统提示词中（已内置技能目录定位与 find 回退，整仓克隆等其他布局也能自动适配）
4. 首次对话会扫描旧库并要求设置目标考试（CET4 / CET6 / 考研英语 / 专升本 / 雅思 / 托福）

## 文件结构

```
english-vocabulary-coach/
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
| 考试适配 | target_exam 未设置前不回答词汇问题；频率/例句/考点全部对齐目标考试大纲 |
| 入库三件套 | 先查重 → INSERT words → UPDATE total_words_count → review_queue 注入 stage=1 → vocab_search 日志 |
| 艾宾浩斯 | 1/2/4/8/16 天五档；答错回 Stage 1，Stage 5 答对移出队列 |

## 数据操作约定

- 建库唯一入口：`sqlite3 <技能目录>/vocabulary.db < schemas/schema.sql`（幂等）
- 业务 SQL 全部在 `schemas/queries.sql` 中，AI 执行前先读它
- 铁律：INSERT 前必 SELECT 查重（按 `words.word`）；写入用事务 + `.timeout 5000`
- 环境变量：`VOCAB_DB`（仅 selfcheck.sh 用，指定库路径）
