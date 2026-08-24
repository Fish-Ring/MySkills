#!/bin/sh
# learning-assistant 环境自检：验证 sqlite3 可用、库可读写、输出核心统计
# 用法: sh selfcheck.sh   （可选环境变量 LEARNING_DB 指定库路径）

set -e

case "$0" in */*) SCRIPT_DIR=$(CDPATH= cd -- "${0%/*}" && pwd) ;; *) SCRIPT_DIR=. ;; esac
DB="${LEARNING_DB:-$SCRIPT_DIR/learner.db}"

echo "== learning-assistant selfcheck =="

command -v sqlite3 >/dev/null 2>&1 || { echo "[FAIL] 未找到 sqlite3，请先执行: apt install sqlite3"; exit 1; }
set -- $(sqlite3 --version)
echo "[OK] sqlite3 $1"

[ -f "$SCRIPT_DIR/schemas/schema.sql" ] || { echo "[FAIL] 缺少 schemas/schema.sql"; exit 1; }

# 幂等建库建表
sqlite3 "$DB" < "$SCRIPT_DIR/schemas/schema.sql"
echo "[OK] 数据库就绪: $DB"

sqlite3 -header -column "$DB" "
SELECT 'subjects' AS item, COUNT(*) AS n FROM subjects
UNION ALL SELECT 'topics', COUNT(*) FROM topics
UNION ALL SELECT 'questions', COUNT(*) FROM questions
UNION ALL SELECT 'mistakes', COUNT(*) FROM mistakes
UNION ALL SELECT 'due_reviews', COUNT(*) FROM review_queue WHERE is_reviewed=0 AND next_review_at <= strftime('%s','now');
SELECT 'profile(exam/stage/date)' AS item, COALESCE(exam,'')||' / '||COALESCE(stage,'')||' / '||COALESCE(exam_date,'') AS n FROM user_profile WHERE id=1;
"

echo "== selfcheck passed =="
