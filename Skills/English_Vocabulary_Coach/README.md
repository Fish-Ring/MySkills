# English Vocabulary Coach (SQLite Edition v2.0)

## Version
2.0.0 - 去掉分块逻辑，简化设计

## Description
本地优先、多考试自适应的英语词汇与听说读写硬核教练，使用 SQLite 数据库存储学习数据。

## Requirements
- Node.js v18+ (已内置 child_process 支持)
- SQLite3 CLI 工具 (系统已安装)
- 无需额外 npm 依赖

## File Structure
```
English_Vocabulary_Coach/
├── SKILL.md              # 技能主入口
├── README.md             # 本文件
├── db.js                 # SQLite 数据库操作层
├── migrate.js            # JSON 数据迁移脚本
├── vocabulary.db         # SQLite 数据库文件（运行后生成）
├── schemas/
│   └── Schemas.md        # 数据库 schema 定义
└── modules/
    ├── Vocab.md          # 词汇处理模块
    ├── Exercise.md       # 实战训练模块
    └── Review.md         # 复习引擎模块
```

## Quick Start
1. 将技能目录复制到你的工作区
2. 运行 `node migrate.js` 迁移旧版 JSON 数据（如有）
3. 在 SKILL.md 中配置你的目标考试
4. 开始使用

## Database Schema
- `user_profile`: 用户配置（目标考试、词汇水平等）
- `words`: 单词表（统一存储，无需分块）
- `review_queue`: 艾宾浩斯复习队列
- `history_logs`: 学习历史日志

## API Reference
所有数据库操作通过 `db.js` 模块：
```javascript
const db = require('./db.js');

// 用户配置
db.getProfile()                    // 获取用户配置
db.updateProfile({...})            // 更新配置字段
db.setTargetExam('考研英语')        // 设置目标考试

// 单词操作
db.getWord('abandon')             // 查询单词
db.wordExists('abandon')          // 检查单词是否存在
db.addWord({...})                 // 添加/更新单词
db.getAllWords()                  // 获取所有单词
db.getWordsByTag('阅读高频词')     // 按标签筛选
db.getRecentWords(5)              // 获取最近添加的5个
db.getRandomWords(5)              // 随机获取5个

// 复习队列
db.addToReviewQueue('word', 1, timestamp)  // 加入复习队列
db.getReviewQueue()               // 获取全部复习队列
db.getDueReviews()                // 获取到期复习
db.updateReviewStage('word', true/false)  // 更新复习状态
db.removeFromReviewQueue('word')  // 从队列移除

// 日志
db.addLog('2026-08-08', 'vocab_search', 5)  // 添加日志
db.getLogs()                      // 获取所有日志
db.getLogsByDate('2026-08-08')    // 获取指定日期日志

// 统计
db.getStats()                     // 获取学习统计
```
