# English Learning Assistant (英语学习助手) v2.5.1

本地优先、多考试自适应的英语学习助手。**零 Node/npm 依赖**，只需 sqlite3 命令行工具。

## 快速开始

```bash
# Debian/Ubuntu rootfs（RikkaHub 工作区等）
apt update && apt install -y sqlite3

sh /workspace/english-learning-assistant/selfcheck.sh
# 本地开发：cd Skills/english-learning-assistant && sh selfcheck.sh
# 自定义库路径：VOCAB_DB=/tmp/test.db sh selfcheck.sh
```

## 搭配 RikkaHub 使用（推荐流程）

1. **安装技能**：`设置 → 扩展管理 → Agent Skills`，点左下角 `+` 选择“从 GitHub 导入”，粘入本仓库或 `english-learning-assistant` 目录链接后导入。

2. **创建工作区**：`设置 → 扩展管理 → 工作区 → 创建工作区 → 安装 Rootfs`。建议关闭下方“工具审批”所有开关。建好后点右上角进入“终端”。

3. **安装依赖并验证**：终端内执行
   ```bash
   apt update && apt install -y sqlite3
   sh /workspace/english-learning-assistant/selfcheck.sh
   ```

4. **新建助手**：将 `SYSTEM_PROMPT.md` 全文粘贴到助手系统提示词中；绑定工作区、开启本技能，并在“记忆”中开启全部功能。建议补充个人信息与目标考试，例如“考研英语一，词汇量约5000”。

5. **开始使用**：首次对话会扫描旧库并在缺信息时主动提问（目标考试、是否入库生词等）。完成后即可查词、发阅读/作文求批改与精读，数据持久化到数据库与记忆中。

> 不同学习技能建议分不同助手使用，避免记忆串台。
>
> 工作区占存储较大，推荐在不干扰的情况下多个助手共用同一个工作区（本仓库技能之间不会互相干扰）。
>
> 演变记录：技能目录 `docs/history/` 每版1个 md（v2.3.0 起全量归档），需回溯时先读它。

## 文件结构

```
english-learning-assistant/
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
| 绑定 | 已绑定 english-learning-assistant，禁止脱离技能空答 |
| 考试适配 | target_exam 未设置前不回答词汇问题；频率/例句/考点全部对齐目标考试大纲 |
| 入库三件套 | 先查重 → INSERT words → UPDATE total_words_count → review_queue 注入 stage=1 → vocab_search 日志 |
| 艾宾浩斯 | 1/2/4/8/16 天五档；答错回 Stage 1，Stage 5 答对移出队列 |

## 数据操作约定

- 建库唯一入口：`sqlite3 <技能目录>/vocabulary.db < schemas/schema.sql`（幂等）
- 业务 SQL 全部在 `schemas/queries.sql` 中，AI 执行前先读它
- 铁律：INSERT 前必 SELECT 查重（按 `words.word`）；写入用事务 + `.timeout 5000`
- 环境变量：`VOCAB_DB`（仅 selfcheck.sh 用，指定库路径）
