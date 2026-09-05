# MySkills

学习类 AI 技能集合 —— 专注提分的硬核工具，为 [RikkaHub](https://github.com/rikkahub/rikkahub) 等支持 Skills + 工作区的客户端设计。

## 技能列表

| 技能 | 描述 | 用途 |
|------|------|------|
| **learning-assistant** | 为任意学科提供答疑、薄弱点记录与复习追踪 | 日常答疑、错题追踪与考前复习 |
| **english-learning-assistant** | 提供查词、阅读与写作批改、精读讲解与生词复习 | 英语查词、阅读/写作辅导与词汇复习 |

> 建议不同技能分不同助手使用，数据更干净、记忆不串台。
>
> 工作区占存储较大，推荐在不干扰的情况下多个助手共用同一个工作区（本仓库技能之间不会互相干扰）。

> 技能演变与历史数据兼容：`docs/history/` 每版1个 md（精简记录变更与表结构影响），需回溯时先读它。

## 运行环境

- sqlite3 命令行工具：`apt install -y sqlite3` —— **唯一依赖**
- 零 Node/npm 依赖，无需编译任何原生模块（安卓 rootfs/proot 环境友好）

## 搭配 RikkaHub 使用（推荐流程）

1. **安装技能**：`设置 → 扩展管理 → Agent Skills`，点左下角 `+` 选择“从 GitHub 导入”，粘入本仓库对应技能目录链接后导入。

2. **创建工作区**：`设置 → 扩展管理 → 工作区 → 创建工作区 → 安装 Rootfs`。建议在下方关闭“工具审批”所有开关（否则每次工具调用都要手动确认）。工作区创建完成后，点右上角进入“终端”。

3. **安装依赖并验证**：终端内依次执行
   ```bash
   apt update && apt install -y sqlite3
   # 按需选择其一或全部验证
   sh /workspace/learning-assistant/selfcheck.sh
   sh /workspace/english-learning-assistant/selfcheck.sh
   ```
   输出 sqlite3 版本、各表行数与档案状态即正常。工作区目录建议：
   ```
   /workspace/
   ├── learning-assistant/            # Skills/learning-assistant 的内容
   └── english-learning-assistant/    # Skills/english-learning-assistant 的内容（可共用同一工作区）
   ```

4. **新建助手并绑定**：新建助手，将对应技能的 `SYSTEM_PROMPT.md` 全文粘贴到系统提示词中；为助手绑定上一步的工作区、开启对应技能，并在“记忆”中开启全部功能。建议先在记忆中补充个人信息，例如“我是张三，正在备考考研数学二”。

5. **开始使用**：首次对话会自动扫描旧库并引导初始化，缺信息时助手会主动向你提问（单选或开放式，按你的设置）。初始化完成后即可直接提问、做题或让其总结复习，相关数据会持久化到数据库与记忆中，切换对话无需重复配置。

### 命令行自检（本地/工作区通用）

```bash
sh /workspace/learning-assistant/selfcheck.sh
sh /workspace/english-learning-assistant/selfcheck.sh
```

## 文件结构

```
MySkills/
├── README.md                  # 本文件
├── docs/history/              # 演变记录（每版1个 md，精简）
├── LICENSE
├── .gitignore
└── Skills/
    ├── english-learning-assistant/
    │   ├── SKILL.md           # 技能入口（SQL 操作参考）
    │   ├── SYSTEM_PROMPT.md   # 自包含系统提示词（复制进助手）
    │   ├── README.md
    │   ├── selfcheck.sh       # 环境自检脚本
    │   ├── package.json       # 元信息（无依赖）
    │   ├── schemas/
    │   │   ├── schema.sql     # 表结构（幂等）
    │   │   ├── queries.sql    # 业务 SQL 模板
    │   │   └── Schemas.md
    │   └── modules/           # Vocab / Exercise / Review
    └── learning-assistant/
        ├── SKILL.md
        ├── SYSTEM_PROMPT.md
        ├── README.md
        ├── selfcheck.sh       # 环境自检脚本
        ├── package.json
        ├── schemas/
        │   ├── schema.sql     # 表结构（幂等）
        │   ├── queries.sql    # 业务 SQL 模板
        │   └── Schemas.md
        └── modules/           # Vocab / Exercise / Review
```

## 技能开发规范

每个技能必须包含：

- `SKILL.md` —— 技能主入口：环境要求、文件结构、SQL 操作参考（带 frontmatter：name/description/version/entrypoint）
- `SYSTEM_PROMPT.md` —— **完全自包含**的系统提示词，直接粘贴到助手的系统提示词中使用；内置技能目录定位与 find 回退；末尾保留 `{{locale}}`、`{{cur_date}}` 占位符
- `README.md` —— 使用说明
- `selfcheck.sh` —— 环境自检脚本（sh 即可运行）
- `schemas/schema.sql` —— 幂等表结构，建库唯一入口
- `schemas/queries.sql` —— 全部业务 SQL 模板（AI 执行前先读它，不凭记忆写 SQL）
- `modules/` —— 功能模块（按职责拆分，含可直接执行的 SQL 步骤）

数据操作铁律：任何 INSERT 前先 SELECT 查重；写入用事务 + `.timeout 5000`。

## License

MIT
