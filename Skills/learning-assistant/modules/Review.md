# 复习/复盘模块（仅用户说复习/总结/薄弱点/复盘时用）

```bash
# 今日统计 + 总览
sqlite3 -json <技能目录>/learner.db "SELECT type,SUM(count) n FROM history_logs WHERE date=date('now','localtime') GROUP BY type; SELECT (SELECT COUNT(*) FROM questions) qs, (SELECT COUNT(*) FROM topics) tps, (SELECT COUNT(*) FROM techniques) tcs, (SELECT COUNT(*) FROM subjects) subs;"
# 薄弱 Top5（可按技巧聚合）
sqlite3 -json <技能目录>/learner.db "SELECT t.name,s.name subject,p.wrong_count FROM progress p JOIN topics t ON t.id=p.topic_id JOIN subjects s ON s.id=t.subject_id WHERE p.wrong_count>p.correct_count ORDER BY p.mastery_level ASC LIMIT 5;"
sqlite3 -json <技能目录>/learner.db "SELECT k.name,s.name subject,COUNT(DISTINCT tt.topic_id) topics FROM techniques k LEFT JOIN technique_topics tt ON tt.technique_id=k.id LEFT JOIN subjects s ON s.id=k.primary_subject_id GROUP BY k.id ORDER BY topics DESC LIMIT 10;"
# 每日复盘（用户主动发起）
sqlite3 -json <技能目录>/learner.db "SELECT date,type,SUM(count) n FROM history_logs WHERE date=date('now','localtime') GROUP BY type; SELECT question,technique,tags,times_asked FROM questions WHERE date(last_asked_at)=date('now','localtime') ORDER BY id DESC LIMIT 20 OFFSET 0; SELECT t.name topic,k.name technique FROM progress p JOIN topics t ON t.id=p.topic_id LEFT JOIN technique_topics tt ON tt.topic_id=t.id LEFT JOIN techniques k ON k.id=tt.technique_id WHERE p.wrong_count>0 ORDER BY p.wrong_count DESC LIMIT 10;"
```
- 复习：报 Top5/按技巧聚合 + 今日统计 + 总览；正确率=1−mistake/qa。
- 复盘：报今日提问/技巧命中/薄弱Top10，仅对话框展示；记忆仅刷新白名单计数+Top6。
- 已废弃艾宾浩斯队列（review_queue 兼容保留不写入）。
