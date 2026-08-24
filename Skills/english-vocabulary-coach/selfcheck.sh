#!/bin/sh
# english-vocabulary-coach 环境自检：验证 sqlite3 可用、库可读写、输出核心统计
# 用法: sh selfcheck.sh   （可选环境变量 VOCAB_DB 指定库路径）

set -e

case "$0" in */*) SCRIPT_DIR=$(CDPATH= cd -- "${0%/*}" && pwd) ;; *) SCRIPT_DIR=. ;; esac
DB="${VOCAB_DB:-$SCRIPT_DIR/vocabulary.db}"

echo "== english-vocabulary-coach selfcheck =="

command -v sqlite3 >/dev/null 2>&1 || { echo "[FAIL] 未找到 sqlite3，请先执行: apt install sqlite3"; exit 1; }
set -- $(sqlite3 --version)
echo "[OK] sqlite3 $1"

[ -f "$SCRIPT_DIR/schemas/schema.sql" ] || { echo "[FAIL] 缺少 schemas/schema.sql"; exit 1; }

# 幂等建库建表
sqlite3 "$DB" < "$SCRIPT_DIR/schemas/schema.sql"
echo "[OK] 数据库就绪: $DB"

sqlite3 -header -column "$DB" "
SELECT 'words' AS item, COUNT(*) AS n FROM words
UNION ALL SELECT 'review_queue', COUNT(*) FROM review_queue
UNION ALL SELECT 'due_reviews', COUNT(*) FROM review_queue WHERE is_reviewed=0 AND next_review_time <= strftime('%s','now');
SELECT 'target_exam' AS item, COALESCE(target_exam,'(未设置)') AS n FROM user_profile WHERE id=1;
SELECT 'total_words_count' AS item, total_words_count AS n FROM user_profile WHERE id=1;
"

echo "== selfcheck passed =="
