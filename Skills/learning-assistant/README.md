# Learning Assistant (通用学习助手) v1.5.2

预答→精查薄弱点，2次查库封顶；三实体分立（Mastery/Misconception/Mistake）+ 出题加权。**零 Node/npm 依赖**，只需 sqlite3。

## 快速开始

```bash
# Debian/Ubuntu rootfs（RikkaHub 工作区等，要求 sqlite3 ≥3.24）
apt update && apt install -y sqlite3

sh /workspace/learning-assistant/selfcheck.sh   # 幂等建库+各表行数+档案
# 本地开发：cd Skills/learning-assistant && sh selfcheck.sh
# 自定义库路径：LEARNING_DB=/tmp/test.db sh selfcheck.sh
# 回溯演变：cat docs/history/v1.5.2.md（仓库根目录下执行；工作区内无 docs 目录时手动复制）
```

## 搭配 RikkaHub 使用（推荐流程）

1. **安装技能**：`设置 → 扩展管理 → Agent Skills`，点左下角 `+` 选择“从 GitHub 导入”，粘入本仓库或 `learning-assistant` 目录链接后导入。

2. **创建工作区**：`设置 → 扩展管理 → 工作区 → 创建工作区 → 安装 Rootfs`。建议关闭下方“工具审批”所有开关（否则每次调用都要确认）。建好后点右上角进入“终端”。

3. **安装依赖并验证**：终端内执行
   ```bash
   apt update && apt install -y sqlite3
   sh /workspace/learning-assistant/selfcheck.sh
   ```

4. **新建助手**：将 `SYSTEM_PROMPT.md` 全文粘贴到助手系统提示词中；绑定上一步的工作区、开启本技能，并在“记忆”中开启全部功能。建议补充个人信息，例如“我是张三，正在备考考研数学二”。

5. **开始使用**：首次对话会自动扫描旧库并引导初始化，缺信息时助手会主动提问（单选或开放式）。完成后即可直接提问、做题或总结复习，数据持久化到数据库与记忆中。

> 不同学习技能建议分不同助手使用，避免记忆串台。
>
> 工作区占存储较大，推荐在不干扰的情况下多个助手共用同一个工作区（本仓库技能之间不会互相干扰）。
>
> 演变记录：`docs/history/` 每版1个 md，需回溯时先读它。

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
| 绑定 | 已绑定 learning-assistant，禁止脱离技能空答，不写库视为未完成 |
| 问答 | 预答草拟2-3个要点 → 批量 IN 精查薄弱点（含技巧感知）→ 薄弱点感知作答 |
| 记录 | 问即疑：questions 总是 times_asked+1，progress wrong_count+1（连击清零）；错题判型入 misconceptions + 双M:N，同事务重算 score/status |
| 三实体 | progress=Mastery状态 / misconceptions=认知模式（5类）/ mistakes=单次事件，三者不混 |
| 出题 | 薄弱 `status='weak'` + `mastery_score ASC`，`source/difficulty` 加权（难度适中优先） |
| 技巧 | 主归属 `primary_subject_id`（NULL=通用）+ `technique_topics` M:N 跨科，AI 自主决定是否多关联，不强制 |
| 复习 | 仅“复习/总结”时查 progress TopN（可按技巧/错误类型聚合），不做 Stage 调度 |
| 复盘 | 仅“复盘”时触发：今日提问/技巧命中/薄弱Top10（`history_logs` 聚合） |
| 记忆 | 仅基础信息+DB概况计数+薄弱Top6 名称+掌握度可进 RikkaHub 记忆，其余永不进 |

## 数据操作约定

- 建库唯一入口：`sqlite3 <技能目录>/learner.db < schemas/schema.sql`（幂等）
- 业务 SQL 全部在 `schemas/queries.sql` 中，AI 执行前先读它
- 铁律：INSERT 前必 SELECT 查重；写入用事务 + `.timeout 5000`
- 环境变量：`LEARNING_DB`（仅 selfcheck.sh 用，指定库路径）
