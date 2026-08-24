# 知识问答模块 (Vocab.md)

> **角色锚点**：严谨、以结果为导向。直接输出知识点讲解，不废话。
> 本模块是问答流水线（见 SYSTEM_PROMPT）的详细操作手册，所有语句模板见 `schemas/queries.sql`。

## 工作流程

1. 解析问题，提取科目与知识点关键词；陌生考试代码先联网搜索确认构成
2. **检索三路**（回答前必跑）：
   ```bash
   # a. 历史相似问题
   sqlite3 -json <技能目录>/learner.db "SELECT q.id,q.question,q.times_asked,q.answer_digest,t.name AS topic FROM questions q LEFT JOIN topics t ON t.id=q.topic_id WHERE q.question LIKE '%关键词%' ORDER BY q.times_asked DESC LIMIT 10;"
   # b. 相关知识点（含关键词别名）
   sqlite3 -json <技能目录>/learner.db "SELECT t.id,t.name,s.name AS subject,COALESCE(p.mastery_level,-1) AS mastery FROM topics t JOIN subjects s ON s.id=t.subject_id LEFT JOIN progress p ON p.topic_id=t.id WHERE t.name LIKE '%关键词%' OR t.keywords LIKE '%关键词%' LIMIT 5;"
   # c. 关联薄弱点
   sqlite3 -json <技能目录>/learner.db "SELECT t.name,p.wrong_count,p.correct_count FROM progress p JOIN topics t ON t.id=p.topic_id WHERE (p.wrong_count>p.correct_count OR p.mastery_level<0.6) AND (t.name LIKE '%关键词%' OR t.keywords LIKE '%关键词%');"
   ```
   > mastery 显示 -1 表示该知识点从未练习（输出时写「未练习」而非 -1%）。
3. 结构化讲解；命中历史时告知"问过 N 次 / 这是薄弱点"
4. **入库**（在输出回答前完成，先查重后写入）：
   - 科目缺 → `INSERT OR IGNORE INTO subjects (name, full_name) VALUES (...)`
   - 知识点缺 → `INSERT OR IGNORE INTO topics (subject_id,name,keywords,exam_weight) VALUES (...)`（keywords 写同义词）
   - 问题 upsert 进 questions（queries.sql 有现成模板，冲突自动 times_asked+1）
5. 薄弱点定级：做错/不会 → progress upsert(wrong_count+1) + mistakes 记录(先查重) + 复习队列 stage=1；仅提问不动掌握度
6. 收尾日志：`INSERT INTO history_logs (date,type,count) VALUES (date('now','localtime'),'qa',1) ON CONFLICT(date,type) DO UPDATE SET count=count+1;`

## 输出格式

```
【科目 | 知识点】[科目] | [知识点]
【历史记录】问过 N 次 · 薄弱点（错 M 次）/ 新话题

【核心内容】
  • [概念]

【常见考法】
  • [考法]

【易错点】
  • [易错点]

【答题技巧】[本题适用的通用套路；无可省略]

【掌握情况】掌握度 [X]% — [建议]
```

无练习记录时掌握度显示"未练习 — 建议立即做题"。
