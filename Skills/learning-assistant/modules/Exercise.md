# 练习模块（v1.5.3，冷酷阅卷官，仅用户说练题/出题时用，不主动出题）
> 铁律：中文撇号用 ′、SQL 引号 doubling；出题表单元格禁裸 `|`，单元格内数学符号用 Unicode（禁 `$` `\` 命令，正文 LaTeX 可用），见 SYSTEM_PROMPT §8。

```bash
# 取薄弱点 TopN 出题（错得多 ×2 加权；默认难度1-2单知识点，尽量简单）
sqlite3 -json <技能目录>/learner.db "SELECT t.id,t.name,p.status,p.mastery_score FROM progress p JOIN topics t ON t.id=p.topic_id WHERE p.status='weak' ORDER BY p.mastery_score ASC LIMIT 5;"
# 兼容口径：SELECT t.id,t.name FROM progress p JOIN topics t ON t.id=p.topic_id WHERE p.wrong_count>p.correct_count ORDER BY p.mastery_level ASC LIMIT 5;
# 错题本抽题：SELECT question,wrong_answer,correct_answer FROM mistakes WHERE topic_id=知识点ID ORDER BY mistake_count DESC LIMIT 5;
# 带出处难度抽题（source/difficulty 在 questions 表）：SELECT question,source,difficulty FROM questions WHERE topic_id=知识点ID ORDER BY times_asked DESC LIMIT 5;
```
无薄弱点按大纲出题；做错走 SYSTEM_PROMPT §5 步骤4同款事务（mistakes + 判定类型入 misconceptions + progress wrong_count+1 连击清零 + 重算 mastery_score/status + mistake 日志）；做对 correct_count+1 连击+1 重算 + exercise 日志。
