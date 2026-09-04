# MySkills

学习类 AI 技能集合 —— 专注提分的硬核工具，为 [RikkaHub](https://github.com/rikkahub/rikkahub) 等支持 Skills + 工作区的客户端设计。

## 技能列表

| 技能 | 描述 | 用途 |
|------|------|------|
| **learning-assistant** | 为任意学科提供答疑、薄弱点记录与复习追踪 | 日常答疑、错题追踪与考前复习 |
| **english-learning-assistant** | 提供查词、阅读与写作批改、精读讲解与生词复习 | 英语查词、阅读/写作辅导与词汇复习 |

## 运行环境

- sqlite3 命令行工具：`apt install -y sqlite3` —— **唯一依赖**
- 零 Node/npm 依赖，无需编译任何原生模块（安卓 rootfs/proot 环境友好）

## 快速开始

### 搭配 RikkaHub

1. 在 APP 中创建工作区（rootfs），把技能目录放入工作区根下：

   ```
   /workspace/
   ├── learning-assistant/          # Skills/learning-assistant 的内容
   └── english-learning-assistant/    # Skills/english-learning-assistant 的内容（共用工作区时）
   ```

2. 在工作区内执行 `apt install -y sqlite3`
3. 新建助手，把对应技能的 `SYSTEM_PROMPT.md` 全文粘贴到助手系统提示词中——提示词已内置技能目录定位与 find 回退
4. 首次对话自动引导初始化（扫旧库 → 建科 → 收集档案）

### 命令行自检

```bash
sh /workspace/learning-assistant/selfcheck.sh
sh /workspace/english-learning-assistant/selfcheck.sh
```

输出 sqlite3 版本、各表行数与档案状态即正常。

## 文件结构

```
MySkills/
├── README.md                  # 本文件
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
