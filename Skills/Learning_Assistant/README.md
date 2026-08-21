# Learning Assistant (通用学习助手) v1.0.1

## 快速开始

```bash
cd Skills/Learning_Assistant
npm install
```

## 文件结构

```
Learning_Assistant/
├── SKILL.md              # 技能入口（AI路由）
├── SYSTEM_PROMPT.md      # 全局提示词
├── README.md             # 本文件
├── db.js                 # 数据库操作层
├── package.json          # 依赖声明
├── schemas/
│   └── Schemas.md        # 数据库schema
└── modules/
    ├── Vocab.md          # 知识点模块
    ├── Exercise.md       # 练习模块
    └── Review.md         # 复习引擎
```

## 使用

### 命令行
```javascript
const db = require('./db.js');

// 初始化用户档案
db.updateProfile({
    exam: '考研22408',
    stage: '基础',
    exam_date: '2026-12-26'
});

// 统计
console.log(db.getStats());
```

### AI集成
将 `Skills/Learning_Assistant/` 放入 Hermes Agent 技能目录，AI自动读取 `SKILL.md`。

## API

| 函数 | 说明 |
|------|------|
| `getProfile()` | 获取用户配置 |
| `updateProfile(data)` | 更新用户配置 |
| `addSubject(name)` | 添加科目 |
| `addTopic(data)` | 添加知识点 |
| `getWeakPoints(n)` | 获取薄弱知识点 |
| `addMistake(data)` | 记录错题 |
| `updateProgress(topicId, correct)` | 更新掌握度 |
| `getDueReviews()` | 获取到期复习 |
