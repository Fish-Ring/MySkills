# 知识问答模块（兼容保留，新版逻辑见 SYSTEM_PROMPT）
> 新版问答仅用“预答→批量 IN 精查薄弱点”1条查询 + 探针确认后精记；本文件仅作复习时补查薄弱点 TopN 参考。

```bash
# 复习时薄弱点 TopN
sqlite3 -json <技能目录>/learner.db "SELECT t.name,s.name subject,p.wrong_count FROM progress p JOIN topics t ON t.id=p.topic_id JOIN subjects s ON s.id=t.subject_id WHERE p.wrong_count>p.correct_count ORDER BY p.mastery_level ASC LIMIT 5;"
```
