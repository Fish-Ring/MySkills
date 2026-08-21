# MySkills

Hermes Agent 技能集合 —— 专注学习提分的硬核工具。

## 技能列表

| 技能 | 描述 | 用途 |
|------|------|------|
| **English_Vocabulary_Coach** | 英语词汇硬核教练 | CET4/6、考研、雅思、托福词汇记忆与实战训练 |
| **Learning_Assistant** | 通用学习助手 | 任意学科错题追踪、薄弱点复习、艾宾浩斯复习引擎 |

## 快速开始

```bash
cd MySkills
npm install
```

### 使用英语词汇教练
```bash
cd Skills/English_Vocabulary_Coach
node -e "const db = require('./db.js'); db.setTargetExam('CET6');"
```

### 使用学习助手
```bash
cd Skills/Learning_Assistant
node -e "const db = require('./db.js'); db.updateProfile({exam: '考研 22408', stage: '基础'});"
```

## 文件结构

```
MySkills/
├── README.md                  # 本文件
├── LICENSE
├── .gitignore
└── Skills/
    ├── English_Vocabulary_Coach/
    │   ├── SKILL.md           # 技能入口（AI 路由）
    │   ├── SYSTEM_PROMPT.md   # 系统提示词（全局角色定义）
    │   ├── README.md          # 使用说明
    │   ├── db.js              # 数据库操作层
    │   ├── migrate.js         # 数据迁移脚本
    │   ├── package.json
    │   ├── schemas/
    │   │   └── Schemas.md     # 数据库 schema
    │   └── modules/
    │       ├── Vocab.md       # 词汇处理模块
    │       ├── Exercise.md    # 实战训练模块
    │       └── Review.md      # 复习引擎模块
    │
    └── Learning_Assistant/
        ├── SKILL.md
        ├── SYSTEM_PROMPT.md
        ├── README.md
        ├── db.js
        ├── package.json
        ├── schemas/
        │   └── Schemas.md
        └── modules/
            ├── Vocab.md
            ├── Exercise.md
            └── Review.md
```

## 技能开发规范

### 目录结构
每个技能必须包含：
- `SKILL.md` —— 技能主入口，定义路由逻辑和输出格式
- `SYSTEM_PROMPT.md` —— 系统提示词，定义 AI 全局角色行为（放在根目录）
- `README.md` —— 使用说明文档
- `db.js` —— 数据库操作层（可选，但推荐）
- `modules/` —— 功能模块（按职责拆分）
- `schemas/` —— 数据库 schema 定义

### SYSTEM_PROMPT.md 说明
此文件用于给 AI 助手设置全局提示词，定义：
- 角色定位与说话风格
- 环境自检逻辑
- 核心行为准则
- 工作流程
- 输出格式规范
- 约束条件

加载技能时，AI 会同时读取 `SKILL.md` 和 `SYSTEM_PROMPT.md`。

## 技术栈
- Node.js ≥ 16
- better-sqlite3（本地 SQLite 数据库）
- Hermes Agent 技能协议

## License
MIT
