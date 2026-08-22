/**
 * SQLite Database Layer for English Vocabulary Coach (sqlite3 CLI edition)
 *
 * 通过 sqlite3 命令行工具操作数据库，零 npm 依赖。
 * 环境要求：Node.js >= 16 + sqlite3 CLI（Debian/Ubuntu: apt install sqlite3）
 * 可用环境变量覆盖：
 *   ENGLISH_DB_PATH  数据库文件路径（默认 ./vocabulary.db）
 *   SQLITE3_BIN      sqlite3 可执行文件（默认在 PATH 中查找 "sqlite3"）
 */

'use strict';

const path = require('path');
const fs = require('fs');
const { spawnSync } = require('child_process');

const DB_PATH = process.env.ENGLISH_DB_PATH || path.join(__dirname, 'vocabulary.db');
const SQLITE3_BIN = process.env.SQLITE3_BIN || 'sqlite3';

// Ebbinghaus review intervals in seconds: 1d, 2d, 4d, 8d, 16d (matches Schemas.md)
const REVIEW_INTERVALS = [86400, 172800, 345600, 691200, 1382400];

// ============ sqlite3 CLI 引擎 ============

const dbDir = path.dirname(DB_PATH);
if (!fs.existsSync(dbDir)) {
    fs.mkdirSync(dbDir, { recursive: true });
}

function cliExec(script) {
    const res = spawnSync(SQLITE3_BIN, ['-batch', DB_PATH], {
        input: '.timeout 5000\n' + script,
        encoding: 'utf8',
        maxBuffer: 64 * 1024 * 1024,
        timeout: 20000,
    });
    if (res.error) {
        throw new Error(`[db] 无法调用 sqlite3 CLI ("${SQLITE3_BIN}")：${res.error.message}。请先安装：apt install sqlite3`);
    }
    if (res.status !== 0) {
        throw new Error(`[db] SQL 执行失败：${String(res.stderr || '').trim()}`);
    }
    return String(res.stdout || '');
}

function queryJson(sql) {
    const out = cliExec('.mode json\n' + sql).trim();
    if (!out) return [];
    try {
        const parsed = JSON.parse(out);
        return Array.isArray(parsed) ? parsed : [];
    } catch (e) {
        throw new Error('[db] sqlite3 输出解析失败：' + out.slice(0, 200));
    }
}

function sqlLiteral(v) {
    if (v === null || v === undefined) return 'NULL';
    switch (typeof v) {
        case 'number':
            if (!Number.isFinite(v)) throw new Error('[db] 非法数值参数');
            return String(v);
        case 'boolean':
            return v ? '1' : '0';
        default:
            return "'" + String(v).replace(/'/g, "''") + "'";
    }
}

function bindSql(sql, params) {
    const list = params === undefined ? [] : (Array.isArray(params) ? params : [params]);
    if (list.length === 0) return sql;
    let i = 0;
    const bound = sql.replace(/\?/g, () => {
        if (i >= list.length) throw new Error('[db] SQL 占位符多于参数');
        return sqlLiteral(list[i++]);
    });
    if (i !== list.length) throw new Error('[db] 参数数量与占位符不符');
    return bound;
}

function run(sql, params) {
    const rows = queryJson(
        bindSql(sql, params) +
        ';\nSELECT changes() AS changes, last_insert_rowid() AS last_insert_rowid;'
    );
    const r = rows[0] || {};
    return { changes: Number(r.changes) || 0, lastInsertRowid: Number(r.last_insert_rowid) || 0 };
}

function get(sql, params) {
    return queryJson(bindSql(sql, params))[0];
}

function all(sql, params) {
    return queryJson(bindSql(sql, params));
}

// ============ SCHEMA ============

function initDatabase() {
    cliExec(`
        CREATE TABLE IF NOT EXISTS user_profile (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            target_exam TEXT DEFAULT '',
            vocabulary_level TEXT DEFAULT 'Medium',
            grammar_basis TEXT DEFAULT 'Weak',
            total_words_count INTEGER DEFAULT 0
        );

        CREATE TABLE IF NOT EXISTS words (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            word TEXT UNIQUE NOT NULL,
            pos TEXT,
            meaning TEXT,
            frequency INTEGER DEFAULT 0,
            collocation TEXT,
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
            date TEXT,
            type TEXT,
            count INTEGER DEFAULT 0,
            UNIQUE(date, type)
        );

        CREATE INDEX IF NOT EXISTS idx_words_word ON words(word);
        CREATE INDEX IF NOT EXISTS idx_words_tag ON words(tag);
        CREATE INDEX IF NOT EXISTS idx_review_queue_time ON review_queue(next_review_time);
        CREATE INDEX IF NOT EXISTS idx_review_queue_word ON review_queue(word);
        CREATE INDEX IF NOT EXISTS idx_review_queue_due ON review_queue(next_review_time ASC, is_reviewed ASC);
        CREATE INDEX IF NOT EXISTS idx_history_date ON history_logs(date);

        INSERT OR IGNORE INTO user_profile (id) VALUES (1);

        PRAGMA journal_mode = WAL;
    `);
}

// Initialize on module load
initDatabase();

// ============ HELPERS ============

const ALLOWED_PROFILE_KEYS = ['target_exam', 'vocabulary_level', 'grammar_basis', 'total_words_count'];

function parseWordRow(row) {
    if (row && row.collocation) {
        try { row.collocation = JSON.parse(row.collocation); }
        catch (e) { row.collocation = []; }
    }
    return row;
}

// ============ USER PROFILE OPERATIONS ============

function getProfile() {
    return get('SELECT * FROM user_profile WHERE id = 1');
}

function updateProfile(updates) {
    const keys = Object.keys(updates || {}).filter((k) => ALLOWED_PROFILE_KEYS.indexOf(k) !== -1);
    if (keys.length === 0) return getProfile();
    run(
        `UPDATE user_profile SET ${keys.map((k) => `${k} = ?`).join(', ')} WHERE id = 1`,
        keys.map((k) => updates[k])
    );
    return getProfile();
}

function setTargetExam(exam) {
    return updateProfile({ target_exam: exam });
}

// ============ WORDS OPERATIONS ============

function getWord(word) {
    return parseWordRow(get('SELECT * FROM words WHERE word = ?', [word]));
}

function wordExists(word) {
    const row = get('SELECT COUNT(*) AS count FROM words WHERE word = ?', [word]);
    return (row ? row.count : 0) > 0;
}

function addWord(wordData) {
    const { word, pos, meaning, frequency, collocation, example, tips, tag } = wordData;
    const collocationJson = Array.isArray(collocation) ? JSON.stringify(collocation) : collocation;

    // Check if word already exists before inserting
    const existsRow = get('SELECT COUNT(*) AS count FROM words WHERE word = ?', [word]);
    const exists = existsRow ? existsRow.count : 0;
    run(
        `INSERT OR REPLACE INTO words (word, pos, meaning, frequency, collocation, example, tips, tag)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
        [word, pos, meaning, frequency || 0, collocationJson, example, tips, tag]
    );

    // Update total count: increment only on new word
    if (!exists) {
        run('UPDATE user_profile SET total_words_count = total_words_count + 1 WHERE id = 1');
    } else {
        const count = get('SELECT COUNT(*) AS total FROM words').total;
        run('UPDATE user_profile SET total_words_count = ? WHERE id = 1', [count]);
    }

    return true;
}

function getAllWords() {
    return all('SELECT * FROM words ORDER BY created_at DESC').map(parseWordRow);
}

function getWordsByTag(tag) {
    return all('SELECT * FROM words WHERE tag = ? ORDER BY created_at DESC', [tag]).map(parseWordRow);
}

function getRecentWords(limit) {
    return all('SELECT * FROM words ORDER BY created_at DESC LIMIT ?', [limit === undefined ? 5 : limit]).map(parseWordRow);
}

function getRandomWords(count) {
    return all('SELECT * FROM words ORDER BY RANDOM() LIMIT ?', [count === undefined ? 5 : count]).map(parseWordRow);
}

// ============ REVIEW QUEUE OPERATIONS ============

function addToReviewQueue(word, stage, nextReviewTime) {
    const s = Math.min(Math.max(stage === undefined ? 1 : stage, 1), REVIEW_INTERVALS.length);
    let nrt = nextReviewTime;
    if (!nrt) {
        nrt = Math.floor(Date.now() / 1000) + REVIEW_INTERVALS[s - 1];
    }

    // 复用任意已有行（含已完成行），避免同一单词累积多条队列记录
    const existing = get(
        'SELECT id FROM review_queue WHERE word = ? ORDER BY is_reviewed ASC, id DESC LIMIT 1',
        [word]
    );
    if (existing) {
        run(
            'UPDATE review_queue SET stage = ?, next_review_time = ?, is_reviewed = 0 WHERE id = ?',
            [s, nrt, existing.id]
        );
    } else {
        run(
            'INSERT INTO review_queue (word, stage, next_review_time, is_reviewed) VALUES (?, ?, ?, 0)',
            [word, s, nrt]
        );
    }

    return getReviewQueue();
}

function getReviewQueue() {
    return all('SELECT * FROM review_queue WHERE is_reviewed = 0 ORDER BY next_review_time ASC');
}

function getDueReviews(currentTime) {
    const now = currentTime === undefined || currentTime === null
        ? Math.floor(Date.now() / 1000)
        : currentTime;
    return all(
        'SELECT * FROM review_queue WHERE next_review_time <= ? AND is_reviewed = 0 ORDER BY next_review_time ASC',
        [now]
    );
}

function updateReviewStage(word, correct, currentTime) {
    const now = currentTime === undefined || currentTime === null
        ? Math.floor(Date.now() / 1000)
        : currentTime;

    const existing = get('SELECT * FROM review_queue WHERE word = ? AND is_reviewed = 0', [word]);
    if (!existing) return null;

    let newStage;
    let nextReviewTime;
    let isReviewed = 0; // Default: keep in queue for future review

    if (correct) {
        newStage = Math.min(existing.stage + 1, REVIEW_INTERVALS.length);
        nextReviewTime = now + REVIEW_INTERVALS[newStage - 1];
        // Mark as reviewed only when reaching max stage (all stages completed)
        if (newStage === REVIEW_INTERVALS.length) isReviewed = 1;
    } else {
        newStage = 1;
        nextReviewTime = now + REVIEW_INTERVALS[0];
        isReviewed = 0;
    }

    run(
        'UPDATE review_queue SET stage = ?, next_review_time = ?, is_reviewed = ? WHERE id = ?',
        [newStage, nextReviewTime, isReviewed, existing.id]
    );
    return { word, stage: newStage, next_review_time: nextReviewTime };
}

function removeFromReviewQueue(word) {
    run('DELETE FROM review_queue WHERE word = ?', [word]);
}

// ============ HISTORY LOG OPERATIONS ============

function addLog(date, type, count) {
    const c = count === undefined ? 1 : count;
    run(
        `INSERT INTO history_logs (date, type, count) VALUES (?, ?, ?)
         ON CONFLICT(date, type) DO UPDATE SET count = count + excluded.count`,
        [date, type, c]
    );
    return getLogs();
}

function getLogs() {
    return all('SELECT * FROM history_logs ORDER BY date DESC');
}

function getLogsByDate(date) {
    return all('SELECT type, count FROM history_logs WHERE date = ?', [date]);
}

/** 今日统计：新增/复习量与正确率 */
function getTodayStats() {
    const t = new Date();
    const p = (n) => String(n).padStart(2, '0');
    const d = `${t.getFullYear()}-${p(t.getMonth() + 1)}-${p(t.getDate())}`;
    const stats = { date: d, vocab_search: 0, exercise: 0, review: 0 };
    getLogsByDate(d).forEach((row) => {
        if (Object.prototype.hasOwnProperty.call(stats, row.type)) stats[row.type] = row.count;
    });
    return stats;
}

// ============ UTILITY OPERATIONS ============

function getStats() {
    const profile = getProfile();
    const totalWords = get('SELECT COUNT(*) AS count FROM words');
    const queueSize = get('SELECT COUNT(*) AS count FROM review_queue WHERE is_reviewed = 0');
    const dueReviews = get(
        'SELECT COUNT(*) AS count FROM review_queue WHERE next_review_time <= ? AND is_reviewed = 0',
        [Math.floor(Date.now() / 1000)]
    );
    return {
        backend: 'sqlite3-cli',
        db_path: DB_PATH,
        target_exam: profile ? profile.target_exam : '',
        vocabulary_level: profile ? profile.vocabulary_level : 'Medium',
        grammar_basis: profile ? profile.grammar_basis : 'Weak',
        total_words: totalWords.count,
        queue_size: queueSize.count,
        due_reviews: dueReviews ? dueReviews.count : 0,
        today: getTodayStats()
    };
}

module.exports = {
    initDatabase,
    getProfile,
    updateProfile,
    setTargetExam,
    getWord,
    wordExists,
    addWord,
    getAllWords,
    getWordsByTag,
    getRecentWords,
    getRandomWords,
    addToReviewQueue,
    getReviewQueue,
    getDueReviews,
    updateReviewStage,
    removeFromReviewQueue,
    addLog,
    getLogs,
    getLogsByDate,
    getTodayStats,
    getStats
};
