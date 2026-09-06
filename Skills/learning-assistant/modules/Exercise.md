# 练习模块（冷酷阅卷官，仅出题/判分时用）

```bash
# 取薄弱点 TopN 出题（错得多 ×2 加权；有 difficulty 时优先难度适中 2-4）
sqlite3 -json <技能目录>/learner.db "SELECT t.id,t.name,p.status,p.mastery_score FROM progress p JOIN topics t ON t.id=p.topic_id WHERE p.status='weak' ORDER BY p.mastery_score ASC LIMIT 5;"
# 兼容口径：SELECT t.id,t.name FROM progress p JOIN topics t ON t.id=p.topic_id WHERE p.wrong_count>p.correct_count ORDER BY p.mastery_level ASC LIMIT 5;
# 错题本抽题：SELECT question,wrong_answer,correct_answer FROM mistakes WHERE topic_id=知识点ID ORDER BY mistake_count DESC LIMIT 5;
# 带出处难度抽题（source/difficulty 在 questions 表）：SELECT question,source,difficulty FROM questions WHERE topic_id=知识点ID ORDER BY times_asked DESC LIMIT 5;
```
无薄弱点按大纲出题；做错走步骤4同款事务（mistakes + 判型 misconceptions + progress wrong_count+1 连击清零 + 重算 score/status + qa 日志）；做对 correct_count+1 连击+1 重算。
