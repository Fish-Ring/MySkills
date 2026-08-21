# Learning Assistant (通用学习助手) v1.0.1

## 版本
1.0.1 - SQLite 错题追踪与艾宾浩斯复习引擎

## 描述
通用学习辅助系统，支持任意学科。基于 SQLite 记录错题、追踪薄弱点、提供艾宾浩斯复习提醒。适合考研 22408、各专业课、职业技能考试等场景。

## 要求
- Node.js ≥ 16
- `better-sqlite3` 依赖（运行 `npm install` 自动安装）
- 无需 SQLite3 CLI 工具

## 文件结构
```
Learning_Assistant/
├── SKILL.md              # 技能主入口（AI 使用）
├── README.md             # 本文件
├── SYSTEM_PROMPT.md      # 系统提示词（全局角色定义）
├── db.js                 # SQLite 数据库操作层
├── learner.db            # SQLite 数据库文件（首次运行自动生成）
├── package.json          # 依赖声明
├── schemas/
│   └── Schemas.md        # 数据库 schema 定义
└── modules/
    ├── Vocab.md          # 知识点查询模块
    ├── Exercise.md       # 练习题生成模块
    └── Review.md         # 复习引擎模块
```

## 快速开始

### 安装
```bash
# 进入技能目录
cd MySkills/Skills/Learning_Assistant

# 安装依赖
npm install
```

### 使用（Node.js 脚本）
```javascript
const db = require('./db.js');

// 获取用户档案
const profile = db.getProfile();

// 初始化用户档案（首次使用）
db.updateProfile({
    exam: '考研 22408',
    stage: '基础',
    exam_date: '2026-12-26'
});

// 添加知识点
db.addTopic({
    subject: '数据结构',
    name: '线性表',
    content: '顺序存储与链式存储...',
    difficulty: 3
});

// 记录错题
db.addMistake(topicId, question, wrongAnswer, correctAnswer, explanation);

// 获取薄弱点
const weakPoints = db.getWeakPoints(5);
```

### 使用（AI 助手集成）
将 `Skills/Learning_Assistant/` 目录放入 Hermes Agent 技能目录，AI 会自动读取 `SKILL.md` 并路由到对应模块。

## 数据库 Schema
- `user_profile`: 用户配置（目标考试、阶段、日期）
- `subjects`: 科目表
- `topics`: 知识点表
- `mistakes`: 错题记录表
- `progress`: 掌握度进度表
- `review_queue`: 艾宾浩斯复习队列（1d/2d/4d/8d/16d）
- `history_logs`: 学习历史日志

## API 参考
```javascript
const db = require('./db.js');

// 用户配置
db.getProfile()                     // 获取用户配置
db.updateProfile({...})             // 更新配置字段

// 科目与知识点
db.addSubject(name)                 // 添加科目
db.getSubjects()                    // 获取所有科目
db.addTopic({subject, name, content, difficulty})  // 添加知识点
db.getTopic(id)                     // 查询知识点
db.searchTopics(keyword)            // 模糊搜索知识点

// 错题管理
db.addMistake(topicId, question, wrongAnswer, correctAnswer, explanation)
db.getMistakes()                    // 获取所有错题
db.getMistakesByTopic(topicId)      // 按知识点筛选错题

// 进度与薄弱点
db.updateProgress(topicId, passed)  // 更新掌握度
db.getWeakPoints(5)                 // 获取薄弱知识点 Top5
db.getStats()                       // 获取学习统计

// 复习队列
db.addToReviewQueue(topicId, stage)  // 加入复习队列
db.getDueReviews()                   // 获取到期复习任务
db.updateReviewStage(topicId, passed)// 更新复习状态
```

## 环境变量
| 变量 | 说明 | 默认值 |
|------|------|--------|
| `LEARNER_DB_PATH` | 数据库文件路径 | `./learner.db` |
