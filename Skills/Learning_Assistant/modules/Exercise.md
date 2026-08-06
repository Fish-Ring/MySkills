# 练习与错题模块 (Exercise.md)

## 工作流程

### 模式1：用户提问（自动记录）
用户提出问题，若回答错误则记录到 mistakes 表，并添加到 review_queue。

### 模式2：主动做题
1. 读取薄弱点（mistakes 表统计）
2. 按错误次数加权随机出题
3. 用户作答后记录结果

### 模式3：专项训练
用户指定科目或知识点，针对性出题。

## 数据库操作
```bash
# 记录错题
sqlite3 /workspace/learner.db "INSERT INTO mistakes (topic_id, question, wrong_answer, correct_answer, explanation) VALUES (?, ?, ?, ?, ?);"
sqlite3 /workspace/learner.db "INSERT INTO review_queue (topic_id, stage, next_review_at, is_reviewed) VALUES (?, 1, datetime('now','+1 day'), 0);"

# 更新掌握度
sqlite3 /workspace/learner.db "INSERT INTO progress (topic_id, correct_count, wrong_count, mastery_level, last_practice_at) VALUES (?, ?, ?, ?, datetime('now')) ON CONFLICT(topic_id) DO UPDATE SET correct_count = correct_count + ?, mastery_level = MIN(1.0, mastery_level + 0.1);"

# 薄弱点查询
sqlite3 -json /workspace/learner.db "SELECT t.name, s.name as subject, COALESCE(SUM(m.mistake_count),0) as errors FROM topics t JOIN subjects s ON s.id = t.subject_id LEFT JOIN mistakes m ON m.topic_id = t.id GROUP BY t.id HAVING errors > 0 ORDER BY errors DESC LIMIT 5;"
```

## 输出格式
```
【题目】第X题 [科目]-[知识点]
[题目内容]

A. [选项A]
B. [选项B]
C. [选项C]
D. [选项D]

请回复答案（如：A）
```