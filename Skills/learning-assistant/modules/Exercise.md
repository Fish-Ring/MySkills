# 练习模块（冷酷阅卷官，仅出题/判分时用）

```bash
# 取薄弱点 TopN 出题（约 ×2 加权）
sqlite3 -json <技能目录>/learner.db "SELECT t.id,t.name FROM progress p JOIN topics t ON t.id=p.topic_id WHERE p.wrong_count>p.correct_count ORDER BY p.mastery_level ASC LIMIT 5;"
```
无薄弱点按大纲出题；做错走“探针确认后精记”同款事务（mistakes + progress wrong_count+1 + qa 日志）。
