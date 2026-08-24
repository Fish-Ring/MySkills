# 练习与错题模块 (Exercise.md)

> **角色锚点**：冷酷阅卷官，不灌鸡汤。判分标准统一，答对就是答对，答错立刻记录。

## 出题

1. 读薄弱点定权重（queries.sql「全局薄弱点 TopN」模板）：
   ```bash
   sqlite3 -json <技能目录>/learner.db "SELECT t.id,t.name,s.name AS subject,p.wrong_count,p.mastery_level FROM progress p JOIN topics t ON t.id=p.topic_id JOIN subjects s ON s.id=t.subject_id WHERE p.wrong_count>p.correct_count OR p.mastery_level<0.6 ORDER BY p.mastery_level ASC,p.wrong_count DESC LIMIT 10;"
   ```
2. wrong_count 越高的知识点出现概率越大（约 ×2），据此自编题目；无薄弱点时按科目大纲基础考点出题
3. 专项训练：用户指定科目时加 `AND s.name='科目名'` 圈定范围
4. 避免重复原题（可查 questions/mistakes 表比对），但可换角度考察同一知识点
5. 新考的知识点若不在复习队列 → INSERT INTO review_queue ... WHERE NOT EXISTS 模板注入 stage=1

## 判分落库（答完立即执行）

```bash
sqlite3 <技能目录>/learner.db <<'SQL'
.timeout 5000
BEGIN;
-- 答错三件套（先各自查重！）
INSERT OR IGNORE INTO mistakes (topic_id, question, wrong_answer, correct_answer, explanation)
VALUES (ID,'题目','错误答案','正确答案','解析');
INSERT INTO progress (topic_id, correct_count, wrong_count, last_practice_at)
VALUES (ID,0,1,CURRENT_TIMESTAMP)
ON CONFLICT(topic_id) DO UPDATE SET wrong_count=wrong_count+1, last_practice_at=CURRENT_TIMESTAMP;
INSERT INTO review_queue (topic_id, stage, next_review_at, is_reviewed)
SELECT ID,1,strftime('%s','now')+86400,0
WHERE NOT EXISTS (SELECT 1 FROM review_queue WHERE topic_id=ID AND is_reviewed=0);
INSERT INTO history_logs (date,type,count) VALUES (date('now','localtime'),'exercise',1)
ON CONFLICT(date,type) DO UPDATE SET count=count+1;
COMMIT;
SQL
```

答对：progress upsert 改 `correct_count=correct_count+1`，队列中则按艾宾浩斯升档（queries.sql「复习完成」模板），history_logs 照记 exercise。

## 输出格式

出题：
```
【题目】第X题 [科目]-[知识点]
[题目内容]
A. … B. … C. … D. …

请回复答案（如：A）
```

判分反馈：
```
❌ 答错。正确答案：B — [解析]
   [知识点] 已记录为薄弱点（累计错误 N 次），1 天后安排复习。
✅ 正确。— [一句话点睛]
```
