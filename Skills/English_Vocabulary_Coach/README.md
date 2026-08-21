# English Vocabulary Coach (SQLite Edition v2.1)

## 快速开始

```bash
cd Skills/English_Vocabulary_Coach
npm install
```

## 文件结构

```
English_Vocabulary_Coach/
├── SKILL.md              # 技能入口（AI路由）
├── SYSTEM_PROMPT.md      # 全局提示词
├── README.md             # 本文件
├── db.js                 # 数据库操作层
├── migrate.js            # 数据迁移脚本
├── package.json          # 依赖声明
├── schemas/
│   └── Schemas.md        # 数据库schema
└── modules/
    ├── Vocab.md          # 词汇模块
    ├── Exercise.md       # 练习模块
    └── Review.md         # 复习引擎
```

## 使用

### 命令行
```javascript
const db = require('./db.js');

// 设置目标考试
db.setTargetExam('CET6');

// 查词
console.log(db.getWord('abandon'));

// 统计
console.log(db.getStats());
```

### AI集成
将 `Skills/English_Vocabulary_Coach/` 放入 Hermes Agent 技能目录，AI自动读取 `SKILL.md`。

## API

| 函数 | 说明 |
|------|------|
| `getProfile()` | 获取用户配置 |
| `setTargetExam(exam)` | 设置目标考试 |
| `getWord(word)` | 查询单词 |
| `addWord(data)` | 添加/更新单词 |
| `addToReviewQueue(word, stage)` | 加入复习队列 |
| `getDueReviews()` | 获取到期复习 |
| `updateReviewStage(word, correct)` | 更新复习阶段 |
| `getStats()` | 获取统计信息 |
