# MySkills

学习类 AI 技能集合 —— 专注提分的硬核工具，为 [RikkaHub](https://github.com/rikkahub/rikkahub) 等支持 Skills + 工作区的客户端设计。

## 技能列表

| 技能 | 描述 | 用途 |
|------|------|------|
| **English_Vocabulary_Coach** | 英语词汇硬核教练 | CET4/6、考研、雅思、托福词汇记忆与实战训练 |
| **Learning_Assistant** | 通用学习助手 | 任意学科错题追踪、薄弱点分析、艾宾浩斯复习引擎 |

## 运行环境

- Node.js ≥ 16（apt 安装即可）
- sqlite3 命令行工具：`apt install -y sqlite3`
- **零 npm 依赖**：db.js 直接通过 sqlite3 CLI 操作数据库，无需编译任何原生模块（安卓 rootfs/proot 友好）

## 快速开始

### 搭配 RikkaHub

1. 在 APP 中创建工作区（rootfs），把技能目录整个放入工作区
2. 在工作区内执行 `apt install -y sqlite3`
3. 新建助手，把对应技能的 `SYSTEM_PROMPT.md` 全文粘贴到助手系统提示词中
4. 首次对话自动引导初始化

### 命令行自检

```bash
cd Skills/Learning_Assistant
node -e "console.log(JSON.stringify(require('./db.js').getStats(), null, 2))"

cd ../English_Vocabulary_Coach
node -e "console.log(JSON.stringify(require('./db.js').getStats(), null, 2))"
```

## 文件结构

```
MySkills/
├── README.md                  # 本文件
├── LICENSE
├── .gitignore
└── Skills/
    ├── English_Vocabulary_Coach/
    │   ├── SKILL.md           # 技能入口（API 参考）
    │   ├── SYSTEM_PROMPT.md   # 自包含系统提示词（复制进助手）
    │   ├── README.md
    │   ├── db.js              # 数据库操作层（sqlite3 CLI 后端）
    │   ├── migrate.js         # v1 JSON 数据迁移（可选）
    │   ├── package.json
    │   ├── schemas/Schemas.md
    │   └── modules/           # Vocab / Exercise / Review
    └── Learning_Assistant/
        ├── SKILL.md
        ├── SYSTEM_PROMPT.md
        ├── README.md
        ├── db.js
        ├── package.json
        ├── schemas/Schemas.md
        └── modules/           # Vocab / Exercise / Review
```

## 技能开发规范

每个技能必须包含：

- `SKILL.md` —— 技能主入口：环境要求、文件结构、完整 API 参考（带 frontmatter：name/description/version/entrypoint）
- `SYSTEM_PROMPT.md` —— **完全自包含**的系统提示词，直接粘贴到助手的系统提示词中使用，不依赖运行时读取其他文件；末尾保留 `{{locale}}`、`{{cur_date}}` 占位符
- `README.md` —— 使用说明
- `db.js` —— 数据库操作层（sqlite3 CLI 后端，同步 API）
- `modules/` —— 功能模块（按职责拆分）
- `schemas/` —— 数据库 schema 定义

## License

MIT
