# 知识点查询模块 (Vocab.md)

## 工作流程
1. 解析用户问题，提取关键词
2. 查询 topics 表，匹配知识点
3. 若有对应讲解内容，输出结构化讲解
4. 若无，询问是否要记录新知识点

## 数据库查询
```bash
# 搜索知识点
sqlite3 -json /workspace/learner.db "SELECT t.id, t.name, s.name as subject, t.exam_weight FROM topics t JOIN subjects s ON s.id = t.subject_id WHERE t.name LIKE '%关键词%' ORDER BY t.exam_weight DESC LIMIT 10;"

# 查询错题
sqlite3 -json /workspace/learner.db "SELECT question, mistake_count, last_mistake_at FROM mistakes WHERE topic_id = ?;"
```

## 输出格式
```
【知识点】[科目] - [知识点名]
【重要度】★ × [1-5]
【错题记录】[N] 道

【核心概念】
  • [概念1]
  • [概念2]

【常见考法】
  • [考法1]
  • [考法2]

【易错点】
  • [易错点]

【掌握度】[X]% — [建议]
```