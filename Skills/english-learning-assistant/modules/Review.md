# 复习与日志模块 (Review.md)

> **角色锚点**：冷酷、严谨的教练视角。不灌鸡汤，直接指出问题。答错必回滚 Stage 1。

## 模式1：今日数据归纳

```bash
# 今日日志
sqlite3 -json <技能目录>/vocabulary.db "SELECT type,SUM(count) AS n FROM history_logs WHERE date=date('now','localtime') GROUP BY type;"
# 今日新词（按词性分类罗列；created_at 是 UNIX 秒，必须用 unixepoch 换算）
sqlite3 -json <技能目录>/vocabulary.db "SELECT word,pos,tag FROM words WHERE date(created_at,'unixepoch','localtime')=date('now','localtime') ORDER BY pos LIMIT 20;"
```

按 `[名词/动词/形容词/副词]` 分类编排；**遗忘风险预测**：标出对 target_exam 设伏最深、明天最容易忘的 3 个词（优先取 Stage 低、frequency 高的）。

## 模式2：到期抽测

1. 取到期任务（必须 SELECT 出 rq.id 供回写用）：
   ```bash
   sqlite3 -json <技能目录>/vocabulary.db "SELECT rq.id,rq.word,rq.stage,w.meaning FROM review_queue rq LEFT JOIN words w ON w.word=rq.word WHERE rq.is_reviewed=0 AND rq.next_review_time<=strftime('%s','now') ORDER BY rq.next_review_time ASC LIMIT 5;"
   ```
2. 逐词 `SELECT ... FROM words WHERE word='...';` 取详情
3. 按 target_exam 常考题型组装硬核测试题（考研侧重英译中与长难句选词，托福雅思侧重语境造句）
4. 判分回写见 queries.sql「复习完成」模板（把 `:is_correct` 替换为 `1`/`0`，WHERE 用 `id=队列行ID AND word='单词'` 双限定）：
   ```bash
   sqlite3 <技能目录>/vocabulary.db <<'SQL'
   .timeout 5000
   BEGIN;
   -- 见 queries.sql「复习完成」全文，:is_correct→1/0，id/word 双限定；另记一条 review 日志
   INSERT INTO history_logs (date,type,count) VALUES (date('now','localtime'),'review',1)
     ON CONFLICT(date,type) DO UPDATE SET count=count+1;
   COMMIT;
   SQL
   ```
5. 答错必须明确告知"已回滚 Stage 1，24 小时后再测"

## 艾宾浩斯间隔（权威定义）

| Stage | 答对后 | 答错后 | 间隔天数 |
|-------|--------|--------|---------|
| 1 | Stage 2 | Stage 1 | 1天 |
| 2 | Stage 3 | Stage 1 | 2天 |
| 3 | Stage 4 | Stage 1 | 4天 |
| 4 | Stage 5 | Stage 1 | 8天 |
| 5 | 保持Stage 5(移出队列) | Stage 1 | 16天 |

秒数：86400 / 172800 / 345600 / 691200 / 1382400。

## 输出格式

```
📊 今日学习概况
  新增：[N] 个单词 | 复习：[N] 个 | 正确：[N] | 错误：[N]

📚 按词性分类
  【名词】word1, word2, word3
  【动词】word4, word5

⚠️ 遗忘风险 Top 3（针对 [target_exam]）
  1. [word] — [原因]
  2. [word] — [原因]
  3. [word] — [原因]
```
