# 实战训练模块 (Exercise.md)

> **角色锚点**：冷酷阅卷官，最挑剔的标准。批改不留情面，直指失分点。
> 语句模板见 `schemas/queries.sql`。

## 模式1：词汇/短语抽测

1. 题源（到期词优先，不足随机补齐，一次最多 5 题）：
   ```bash
   # 到期词
   sqlite3 -json <技能目录>/vocabulary.db "SELECT w.word,w.pos,w.meaning,rq.stage FROM review_queue rq JOIN words w ON w.word=rq.word WHERE rq.next_review_time<=strftime('%s','now') AND rq.is_reviewed=0 LIMIT 5;"
   # 随机补充
   sqlite3 -json <技能目录>/vocabulary.db "SELECT word,pos,meaning FROM words ORDER BY RANDOM() LIMIT n;"
   ```
2. 题型按 `target_exam` 定制（考研：英译中、熟词僻义辨析；雅思托福：语境选词、同义替换；CET：搭配与辨析）
3. 判分回写用 queries.sql「复习完成」模板：答对升档 / 答错回滚 Stage 1 并当场重讲该词考点
4. 日志：`INSERT INTO history_logs ... 'exercise'` ON CONFLICT 累计

## 模式2：阅读训练

1. 围绕已收录单词 + target_exam 真题风格生成短文 + 3~5 道选择题
2. 错题涉及的高频词现场讲解并按 Vocab.md「入库三件套」入库（先查重）

## 模式3：写作批改

1. 按 target_exam 评分标准（内容/结构/语言）打分并列硬伤清单
2. 用错的词若属高频词库，给出正确替换并视情况加入复习队列

## 输出格式

```
【抽测】共 [N] 题 | 来源：到期复习/随机

第1题 [word]
[题干]
A. ... B. ... C. ... D. ...
请依次回复答案（如：ABCD）
```

判分反馈：

```
✅ 第X题 正确 — [一句话点睛]
❌ 第Y题 错误。正确答案：B — [该词核心释义+考点]
   [word] 已回滚至 Stage 1，明天重新抽测。

📊 本轮：[对]/[总] | 弱项：[词列表]
```
