# 复习模块（仅用户说复习/总结/薄弱点时用）

```bash
# 今日统计
sqlite3 -json <技能目录>/learner.db "SELECT type,SUM(count) n FROM history_logs WHERE date=date('now','localtime') GROUP BY type;"
# 薄弱点 Top5
sqlite3 -json <技能目录>/learner.db "SELECT t.name,s.name subject,p.wrong_count FROM progress p JOIN topics t ON t.id=p.topic_id JOIN subjects s ON s.id=t.subject_id WHERE p.wrong_count>p.correct_count ORDER BY p.mastery_level ASC LIMIT 5;"
```
报 Top5 + 今日统计；正确率=1−mistake/exercise，不做 Stage 自动调度。
