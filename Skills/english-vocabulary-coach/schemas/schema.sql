-- 英语词汇教练 v2.4.1 - 数据库模式（全幂等，可重复执行）
-- 初始化：sqlite3 /workspace/english-vocabulary-coach/vocabulary.db < schemas/schema.sql
-- 结构契约详见同目录 Schemas.md

CREATE TABLE IF NOT EXISTS user_profile (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    target_exam TEXT DEFAULT '',           -- 目标考试 (CET4/CET6/考研英语/雅思/托福等)
    vocabulary_level TEXT DEFAULT 'Medium',
    grammar_basis TEXT DEFAULT 'Weak',
    total_words_count INTEGER DEFAULT 0
);

CREATE TABLE IF NOT EXISTS words (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    word TEXT UNIQUE NOT NULL,             -- 单词（唯一，查重键）
    pos TEXT,
    meaning TEXT,
    frequency INTEGER DEFAULT 0,           -- 考试频率 (1-5)
    collocation TEXT,                      -- 搭配 (JSON数组字符串)
    example TEXT,
    tips TEXT,
    tag TEXT,
    created_at INTEGER DEFAULT (strftime('%s', 'now'))
);

CREATE TABLE IF NOT EXISTS review_queue (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    word TEXT NOT NULL,
    stage INTEGER DEFAULT 1,
    next_review_time INTEGER,
    is_reviewed INTEGER DEFAULT 0,
    FOREIGN KEY (word) REFERENCES words(word)
);

CREATE TABLE IF NOT EXISTS history_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    date TEXT,                             -- YYYY-MM-DD
    type TEXT,                             -- vocab_search/exercise/review/qa
    count INTEGER DEFAULT 0,
    UNIQUE(date, type)
);

INSERT OR IGNORE INTO user_profile (id) VALUES (1);

CREATE INDEX IF NOT EXISTS idx_words_word ON words(word);
CREATE INDEX IF NOT EXISTS idx_words_tag ON words(tag);
CREATE INDEX IF NOT EXISTS idx_review_queue_time ON review_queue(next_review_time);
CREATE INDEX IF NOT EXISTS idx_review_queue_word ON review_queue(word);
CREATE INDEX IF NOT EXISTS idx_review_queue_due ON review_queue(next_review_time ASC, is_reviewed ASC);
CREATE INDEX IF NOT EXISTS idx_history_date ON history_logs(date);
