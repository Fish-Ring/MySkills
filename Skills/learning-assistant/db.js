/**
 * SQLite Database Layer for Learning Assistant (sqlite3 CLI edition)
 *
 * 通过 sqlite3 命令行工具操作数据库，零 npm 依赖。
 * 环境要求：Node.js >= 16 + sqlite3 CLI（Debian/Ubuntu: apt install sqlite3）
 * 可用环境变量覆盖：
 *   LEARNING_DB_PATH  数据库文件路径（默认 ./learner.db）
 *   SQLITE3_BIN       sqlite3 可执行文件（默认在 PATH 中查找 "sqlite3"）
 */

'use strict';

const path = require('path');
const fs = require('fs');
const { spawnSync } = require('child_process');

const DB_PATH = process.env.LEARNING_DB_PATH || path.join(__dirname, 'learner.db');
const SQLITE3_BIN = process.env.SQLITE3_BIN || 'sqlite3';

// Ebbinghaus review intervals in seconds: 1d, 2d, 4d, 8d, 16d
const REVIEW_INTERVALS = [86400, 172800, 345600, 691200, 1382400];

// ============ sqlite3 CLI 引擎 ============

const dbDir = path.dirname(DB_PATH);
if (!fs.existsSync(dbDir)) {
    fs.mkdirSync(dbDir, { recursive: true });
}

function cliExec(script) {
    const res = spawnSync(SQLITE3_BIN, ['-batch', DB_PATH], {
        input: script,
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
        CREATE TABLE IF NOT EXISTS subjects (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT UNIQUE NOT NULL,
            full_name TEXT,
            weight REAL DEFAULT 1.0,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );

        CREATE TABLE IF NOT EXISTS topics (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            subject_id INTEGER NOT NULL,
            name TEXT NOT NULL,
            parent_id INTEGER,
            exam_weight REAL DEFAULT 3.0,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (subject_id) REFERENCES subjects(id),
            FOREIGN KEY (parent_id) REFERENCES topics(id)
        );

        CREATE TABLE IF NOT EXISTS mistakes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            topic_id INTEGER,
            question TEXT NOT NULL,
            wrong_answer TEXT,
            correct_answer TEXT,
            explanation TEXT,
            mistake_count INTEGER DEFAULT 1,
            last_mistake_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (topic_id) REFERENCES topics(id),
            UNIQUE(topic_id, question, wrong_answer, correct_answer)
        );

        CREATE TABLE IF NOT EXISTS progress (
            topic_id INTEGER PRIMARY KEY,
            correct_count INTEGER DEFAULT 0,
            wrong_count INTEGER DEFAULT 0,
            last_practice_at TIMESTAMP,
            mastery_level REAL DEFAULT 0.0,
            FOREIGN KEY (topic_id) REFERENCES topics(id)
        );

        CREATE TABLE IF NOT EXISTS review_queue (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            topic_id INTEGER NOT NULL,
            stage INTEGER DEFAULT 1,
            next_review_at INTEGER NOT NULL,
            is_reviewed INTEGER DEFAULT 0,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (topic_id) REFERENCES topics(id)
        );

        CREATE TABLE IF NOT EXISTS history_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT NOT NULL,
            type TEXT NOT NULL,
            count INTEGER DEFAULT 0,
            UNIQUE(date, type)
        );

        CREATE TABLE IF NOT EXISTS user_profile (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            exam TEXT DEFAULT '',
            stage TEXT DEFAULT '基础',
            exam_date TEXT DEFAULT '',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );

        CREATE INDEX IF NOT EXISTS idx_mistakes_topic ON mistakes(topic_id);
        CREATE INDEX IF NOT EXISTS idx_mistakes_count ON mistakes(mistake_count DESC);
        CREATE INDEX IF NOT EXISTS idx_progress_mastery ON progress(mastery_level ASC);
        CREATE INDEX IF NOT EXISTS idx_review_queue ON review_queue(next_review_at ASC, is_reviewed ASC);
        CREATE INDEX IF NOT EXISTS idx_history_date ON history_logs(date);

        INSERT OR IGNORE INTO user_profile (id) VALUES (1);
        PRAGMA journal_mode = WAL;
    `);
}

// Initialize on module load
initDatabase();

// ============ HELPERS ============

function todayStr(d) {
    const t = d || new Date();
    const p = (n) => String(n).padStart(2, '0');
    return `${t.getFullYear()}-${p(t.getMonth() + 1)}-${p(t.getDate())}`;
}

// ============ USER PROFILE OPERATIONS ============

const ALLOWED_PROFILE_KEYS = ['exam', 'exam_date', 'stage'];

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

function setExam(exam) {
    return updateProfile({ exam });
}

function setExamDate(date) {
    return updateProfile({ exam_date: date });
}

function setStage(stage) {
    return updateProfile({ stage });
}

// ============ SUBJECT OPERATIONS ============

function addSubject(name, fullName, weight) {
    const exists = get('SELECT id FROM subjects WHERE name = ?', [name]);
    if (exists) return { id: exists.id, created: false };
    const result = run(
        'INSERT INTO subjects (name, full_name, weight) VALUES (?, ?, ?)',
        [name, fullName === undefined ? null : fullName, weight === undefined ? 1.0 : weight]
    );
    return { id: result.lastInsertRowid, created: true };
}

function getAllSubjects() {
    return all('SELECT * FROM subjects ORDER BY name');
}

function getSubject(id) {
    return get('SELECT * FROM subjects WHERE id = ?', [id]);
}

// ============ TOPIC OPERATIONS ============

function addTopic(subjectId, name, parentId, examWeight) {
    const result = run(
        'INSERT INTO topics (subject_id, name, parent_id, exam_weight) VALUES (?, ?, ?, ?)',
        [subjectId, name, parentId === undefined ? null : parentId, examWeight === undefined ? 3.0 : examWeight]
    );
    return { id: result.lastInsertRowid, created: true };
}

function getTopics(subjectId, keyword) {
    let sql = 'SELECT t.*, s.name AS subject_name FROM topics t LEFT JOIN subjects s ON t.subject_id = s.id';
    const params = [];
    const conditions = [];
    if (subjectId !== null && subjectId !== undefined && subjectId !== '') {
        conditions.push('t.subject_id = ?');
        params.push(subjectId);
    }
    if (keyword !== null && keyword !== undefined && keyword !== '') {
        conditions.push("t.name LIKE '%' || ? || '%'");
        params.push(keyword);
    }
    if (conditions.length > 0) sql += ' WHERE ' + conditions.join(' AND ');
    sql += ' ORDER BY t.exam_weight DESC, t.name';
    return all(sql, params);
}

/**
 * 兼容三种调用方式：
 *   getTopic(id)          按 ID 精确查询
 *   getTopic('关键词')     按关键词模糊匹配，返回最佳匹配
 *   getTopic(null,'关键词') 同上（兼容旧文档写法）
 */
function getTopic(idOrKeyword, keywordHint) {
    let id = null;
    let kw = null;
    if (typeof idOrKeyword === 'number') {
        id = idOrKeyword;
    } else if (typeof idOrKeyword === 'string' && idOrKeyword.trim() !== '') {
        kw = idOrKeyword.trim();
    } else if ((idOrKeyword === null || idOrKeyword === undefined) &&
               typeof keywordHint === 'string' && keywordHint.trim() !== '') {
        kw = keywordHint.trim();
    }
    if (id !== null) {
        return get(
            'SELECT t.*, s.name AS subject_name FROM topics t LEFT JOIN subjects s ON t.subject_id = s.id WHERE t.id = ?',
            [id]
        );
    }
    if (kw !== null) {
        return get(
            `SELECT t.*, s.name AS subject_name
             FROM topics t LEFT JOIN subjects s ON t.subject_id = s.id
             WHERE t.name LIKE '%' || ? || '%'
             ORDER BY t.exam_weight DESC, t.id LIMIT 1`,
            [kw]
        );
    }
    return undefined;
}

// ============ MISTAKE / PROGRESS OPERATIONS ============

function upsertProgress(topicId, correctCount, wrongCount) {
    const total = correctCount + wrongCount;
    const mastery = total > 0 ? Math.max(0, Math.min(1, correctCount / total)) : 0;
    run(
        `INSERT INTO progress (topic_id, correct_count, wrong_count, mastery_level, last_practice_at)
         VALUES (?, ?, ?, ?, CURRENT_TIMESTAMP)
         ON CONFLICT(topic_id) DO UPDATE SET
             correct_count = excluded.correct_count,
             wrong_count = excluded.wrong_count,
             mastery_level = excluded.mastery_level,
             last_practice_at = CURRENT_TIMESTAMP`,
        [topicId, correctCount, wrongCount, mastery]
    );
}

function addMistake(topicId, question, wrongAnswer, correctAnswer, explanation) {
    let duplicated = false;
    try {
        run(
            `INSERT INTO mistakes (topic_id, question, wrong_answer, correct_answer, explanation)
             VALUES (?, ?, ?, ?, ?)`,
            [topicId, question, wrongAnswer, correctAnswer, explanation]
        );
    } catch (e) {
        if (/UNIQUE constraint/i.test(String(e.message))) {
            // 已有同题错题记录 -> 仅累计次数
            run(
                `UPDATE mistakes SET mistake_count = mistake_count + 1, last_mistake_at = CURRENT_TIMESTAMP
                 WHERE topic_id = ? AND question = ?`,
                [topicId, question]
            );
            duplicated = true;
        } else {
            throw e;
        }
    }
    // 修复：无论 progress 行是否存在都正确累计 wrong_count（upsert）
    const row = get('SELECT correct_count, wrong_count FROM progress WHERE topic_id = ?', [topicId]);
    upsertProgress(topicId, row ? row.correct_count : 0, (row ? row.wrong_count : 0) + 1);
    addLog('mistake', 1);
    return { topicId, duplicated };
}

function getMistakesByTopic(topicId) {
    return all('SELECT * FROM mistakes WHERE topic_id = ? ORDER BY mistake_count DESC', [topicId]);
}

function getWeakPoints(limit) {
    return all(
        `SELECT t.id, t.name, t.subject_id, s.name AS subject_name,
                p.wrong_count, p.correct_count, p.mastery_level
         FROM topics t
         JOIN subjects s ON t.subject_id = s.id
         LEFT JOIN progress p ON p.topic_id = t.id
         ORDER BY COALESCE(p.wrong_count, -1) DESC, t.id
         LIMIT ?`,
        [limit === undefined ? 5 : limit]
    );
}

function updateProgress(topicId, isCorrect) {
    const row = get('SELECT correct_count, wrong_count FROM progress WHERE topic_id = ?', [topicId]);
    const cc = (row ? row.correct_count : 0) + (isCorrect ? 1 : 0);
    const wc = (row ? row.wrong_count : 0) + (isCorrect ? 0 : 1);
    upsertProgress(topicId, cc, wc);
    addLog('exercise', 1);
    return get('SELECT * FROM progress WHERE topic_id = ?', [topicId]);
}

// ============ REVIEW QUEUE OPERATIONS ============

function addToReviewQueue(topicId, stage) {
    const s = Math.min(Math.max(stage === undefined ? 1 : stage, 1), REVIEW_INTERVALS.length);
    const nextReviewAt = Math.floor(Date.now() / 1000) + REVIEW_INTERVALS[s - 1];
    // 复用任意已有行（含已完成行），避免同一知识点累积多条队列记录
    const existing = get(
        'SELECT id FROM review_queue WHERE topic_id = ? ORDER BY is_reviewed ASC, id DESC LIMIT 1',
        [topicId]
    );
    if (existing) {
        run(
            'UPDATE review_queue SET stage = ?, next_review_at = ?, is_reviewed = 0 WHERE id = ?',
            [s, nextReviewAt, existing.id]
        );
    } else {
        run(
            'INSERT INTO review_queue (topic_id, stage, next_review_at, is_reviewed) VALUES (?, ?, ?, 0)',
            [topicId, s, nextReviewAt]
        );
    }
}

function getReviewQueue() {
    return all('SELECT * FROM review_queue WHERE is_reviewed = 0 ORDER BY next_review_at ASC');
}

function getDueReviews(currentTime) {
    const now = currentTime === undefined || currentTime === null
        ? Math.floor(Date.now() / 1000)
        : currentTime;
    return all(
        'SELECT * FROM review_queue WHERE next_review_at <= ? AND is_reviewed = 0 ORDER BY next_review_at ASC',
        [now]
    );
}

function updateReviewStage(topicId, correct) {
    const existing = get('SELECT * FROM review_queue WHERE topic_id = ? AND is_reviewed = 0', [topicId]);
    if (!existing) return null;

    let newStage;
    let nextReviewAt;
    let isReviewed = 0;
    const now = Math.floor(Date.now() / 1000);
    if (correct) {
        newStage = Math.min(existing.stage + 1, REVIEW_INTERVALS.length);
        nextReviewAt = now + REVIEW_INTERVALS[newStage - 1];
        if (newStage === REVIEW_INTERVALS.length) isReviewed = 1; // Stage 5 已掌握
    } else {
        newStage = 1;
        nextReviewAt = now + REVIEW_INTERVALS[0];
    }

    run(
        'UPDATE review_queue SET stage = ?, next_review_at = ?, is_reviewed = ? WHERE id = ?',
        [newStage, nextReviewAt, isReviewed, existing.id]
    );
    addLog('review', 1);
    return { topic_id: topicId, stage: newStage, next_review_at: nextReviewAt };
}

function removeFromReviewQueue(topicId) {
    run('DELETE FROM review_queue WHERE topic_id = ?', [topicId]);
}

// ============ HISTORY LOG OPERATIONS ============

/** 记录事件日志（type: vocab_search/exercise/mistake/review），日期自动取今天 */
function addLog(type, count, date) {
    const d = date === undefined || date === null ? todayStr() : date;
    const c = count === undefined ? 1 : count;
    run(
        `INSERT INTO history_logs (date, type, count) VALUES (?, ?, ?)
         ON CONFLICT(date, type) DO UPDATE SET count = count + excluded.count`,
        [d, type, c]
    );
    return true;
}

function getLogs() {
    return all('SELECT * FROM history_logs ORDER BY date DESC');
}

function getLogsByDate(date) {
    return all('SELECT type, count FROM history_logs WHERE date = ?', [date === undefined ? todayStr() : date]);
}

/** 今日统计：练习量、错题量、正确率 */
function getTodayStats() {
    const d = todayStr();
    const stats = { date: d, vocab_search: 0, exercise: 0, mistake: 0, review: 0, accuracy: null };
    all('SELECT type, count FROM history_logs WHERE date = ?', [d]).forEach((row) => {
        if (Object.prototype.hasOwnProperty.call(stats, row.type)) stats[row.type] = row.count;
    });
    if (stats.exercise > 0) {
        stats.accuracy = Math.round(((stats.exercise - stats.mistake) / stats.exercise) * 100);
    }
    return stats;
}

// ============ UTILITY ============

function getStats() {
    const profile = getProfile();
    const totalTopics = get('SELECT COUNT(*) AS count FROM topics');
    const totalMistakes = get('SELECT COALESCE(SUM(mistake_count), 0) AS count FROM mistakes');
    const queueSize = get('SELECT COUNT(*) AS count FROM review_queue WHERE is_reviewed = 0');
    const dueCount = get(
        'SELECT COUNT(*) AS count FROM review_queue WHERE next_review_at <= ? AND is_reviewed = 0',
        [Math.floor(Date.now() / 1000)]
    );
    return {
        backend: 'sqlite3-cli',
        db_path: DB_PATH,
        exam: profile ? profile.exam : '',
        stage: profile ? profile.stage : '',
        exam_date: profile ? profile.exam_date : '',
        total_topics: totalTopics.count,
        total_mistakes: totalMistakes.count,
        review_queue_size: queueSize.count,
        due_reviews: dueCount.count,
        today: getTodayStats()
    };
}

module.exports = {
    initDatabase, todayStr,
    getProfile, updateProfile, setExam, setExamDate, setStage,
    addSubject, getAllSubjects, getSubject,
    addTopic, getTopics, getTopic,
    addMistake, getMistakesByTopic, getWeakPoints, updateProgress,
    addToReviewQueue, getReviewQueue, getDueReviews, updateReviewStage, removeFromReviewQueue,
    addLog, getLogs, getLogsByDate, getTodayStats,
    getStats
};
