# 知识问答模块（v1.5.3，兼容保留，新版逻辑见 SYSTEM_PROMPT §5）
> 新版问答仅用“预答→批量 IN 精查薄弱点”1条查询（queries.sql 核心检索段，LIMIT 5）+ 答疑后确认再记录；本文件仅作复习时补查薄弱点 TopN 参考。
> 铁律：中文撇号用 ′、SQL 引号 doubling；出表单元格禁裸 `|`，单元格内数学符号用 Unicode（禁 `$` `\` 命令，正文 LaTeX 可用），见 SYSTEM_PROMPT §8。

```bash
# 复习时薄弱点 TopN（新口径；兼容口径见 queries.sql）
sqlite3 -json <技能目录>/learner.db "SELECT t.name,s.name subject,p.status,p.mastery_score FROM progress p JOIN topics t ON t.id=p.topic_id JOIN subjects s ON s.id=t.subject_id WHERE p.status='weak' ORDER BY p.mastery_score ASC LIMIT 5;"
```
