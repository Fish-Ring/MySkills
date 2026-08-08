/**
 * SQLite Database Layer for English Vocabulary Coach
 * Uses sqlite3 CLI tool (no external npm dependencies required)
 */

const { execSync } = require('child_process');
const path = require('path');

const DB_PATH = path.join(__dirname, 'vocabulary.db');
const SQLITE3_CMD = 'sqlite3';

function executeSQL(sql, params = []) {
    let command = `${SQLITE3_CMD} -json "${DB_PATH}"`;
    
    // Replace ? placeholders with escaped values
    let processedSQL = sql;
    params.forEach(param => {
        if (typeof param === 'string') {
            processedSQL = processedSQL.replace('?', `'${param.replace(/'/g, "''")}'`);
        } else {
            processedSQL = processedSQL.replace('?', param);
        }
    });
    
    command += ` "${processedSQL.replace(/"/g, '\\"')}"`;
    
    try {
        const result = execSync(command, { encoding: 'utf8', timeout: 30000 });
        if (!result.trim()) return [];
        try {
            return JSON.parse(result);
        } catch (e) {
            return result.trim();
        }
    } catch (error) {
        console.error('SQL Error:', error.message);
        return null;
    }
}

function initDatabase() {
    const sqls = [
        `CREATE TABLE IF NOT EXISTS user_profile (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            target_exam TEXT DEFAULT '',
            vocabulary_level TEXT DEFAULT 'Medium',
            grammar_basis TEXT DEFAULT 'Weak',
            total_words_count INTEGER DEFAULT 0
        )`,
        `CREATE TABLE IF NOT EXISTS words (
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
        )`,
        `CREATE TABLE IF NOT EXISTS review_queue (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            word TEXT NOT NULL,
            stage INTEGER DEFAULT 1,
            next_review_time INTEGER,
            FOREIGN KEY (word) REFERENCES words(word)
        )`,
        `CREATE TABLE IF NOT EXISTS history_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT,
            type TEXT,
            count INTEGER DEFAULT 0
        )`,
        `CREATE INDEX IF NOT EXISTS idx_words_word ON words(word)`,
        `CREATE INDEX IF NOT EXISTS idx_words_tag ON words(tag)`,
        `CREATE INDEX IF NOT EXISTS idx_review_queue_time ON review_queue(next_review_time)`,
        `CREATE INDEX IF NOT EXISTS idx_review_queue_word ON review_queue(word)`,
        `CREATE INDEX IF NOT EXISTS idx_history_date ON history_logs(date)`,
        `INSERT OR IGNORE INTO user_profile (id) VALUES (1)`
    ];
    
    sqls.forEach(sql => executeSQL(sql));
}

// Initialize on module load
initDatabase();

// ============ USER PROFILE OPERATIONS ============

function getProfile() {
    const result = executeSQL('SELECT * FROM user_profile WHERE id = 1');
    return Array.isArray(result) && result.length > 0 ? result[0] : null;
}

function updateProfile(updates) {
    const keys = Object.keys(updates);
    const setClause = keys.map(k => {
        const val = typeof updates[k] === 'string' ? `'${updates[k]}'` : updates[k];
        return `${k} = ${val}`;
    }).join(', ');
    
    executeSQL(`UPDATE user_profile SET ${setClause} WHERE id = 1`);
    return getProfile();
}

function setTargetExam(exam) {
    return updateProfile({ target_exam: exam });
}

// ============ WORDS OPERATIONS ============

function getWord(word) {
    const result = executeSQL('SELECT * FROM words WHERE word = ?', [word]);
    if (Array.isArray(result) && result.length > 0) {
        const row = result[0];
        if (row.collocation) {
            try {
                row.collocation = JSON.parse(row.collocation);
            } catch (e) {
                row.collocation = [];
            }
        }
        return row;
    }
    return null;
}

function wordExists(word) {
    const result = executeSQL('SELECT COUNT(*) as count FROM words WHERE word = ?', [word]);
    return Array.isArray(result) && result[0].count > 0;
}

function addWord(wordData) {
    const { word, pos, meaning, frequency, collocation, example, tips, tag } = wordData;
    
    const collocationJson = Array.isArray(collocation) ? JSON.stringify(collocation) : collocation;
    
    executeSQL(`INSERT OR REPLACE INTO words (word, pos, meaning, frequency, collocation, example, tips, tag) VALUES (?, ?, ?, ?, ?, ?, ?, ?)`, 
        [word, pos, meaning, frequency || 0, collocationJson, example, tips, tag]);
    
    // Update total count
    const countResult = executeSQL('SELECT COUNT(*) as total FROM words');
    if (Array.isArray(countResult) && countResult.length > 0) {
        updateProfile({ total_words_count: countResult[0].total });
    }
    
    return true;
}

function getAllWords() {
    const result = executeSQL('SELECT * FROM words ORDER BY created_at DESC');
    if (Array.isArray(result)) {
        return result.map(row => {
            if (row.collocation) {
                try {
                    row.collocation = JSON.parse(row.collocation);
                } catch (e) {
                    row.collocation = [];
                }
            }
            return row;
        });
    }
    return [];
}

function getWordsByTag(tag) {
    const result = executeSQL('SELECT * FROM words WHERE tag = ?', [tag]);
    if (Array.isArray(result)) {
        return result.map(row => {
            if (row.collocation) {
                try {
                    row.collocation = JSON.parse(row.collocation);
                } catch (e) {
                    row.collocation = [];
                }
            }
            return row;
        });
    }
    return [];
}

function getRecentWords(limit = 5) {
    const result = executeSQL(`SELECT * FROM words ORDER BY created_at DESC LIMIT ${limit}`);
    if (Array.isArray(result)) {
        return result.map(row => {
            if (row.collocation) {
                try {
                    row.collocation = JSON.parse(row.collocation);
                } catch (e) {
                    row.collocation = [];
                }
            }
            return row;
        });
    }
    return [];
}

function getRandomWords(count = 5) {
    const result = executeSQL(`SELECT * FROM words ORDER BY RANDOM() LIMIT ${count}`);
    if (Array.isArray(result)) {
        return result.map(row => {
            if (row.collocation) {
                try {
                    row.collocation = JSON.parse(row.collocation);
                } catch (e) {
                    row.collocation = [];
                }
            }
            return row;
        });
    }
    return [];
}

// ============ REVIEW QUEUE OPERATIONS ============

function addToReviewQueue(word, stage = 1, nextReviewTime = null) {
    if (!nextReviewTime) {
        nextReviewTime = Math.floor(Date.now() / 1000) + 86400;
    }
    
    // Check if already in queue
    const existing = executeSQL('SELECT * FROM review_queue WHERE word = ?', [word]);
    
    if (Array.isArray(existing) && existing.length > 0) {
        executeSQL('UPDATE review_queue SET stage = ?, next_review_time = ? WHERE word = ?', [stage, nextReviewTime, word]);
    } else {
        executeSQL('INSERT INTO review_queue (word, stage, next_review_time) VALUES (?, ?, ?)', [word, stage, nextReviewTime]);
    }
    
    return getReviewQueue();
}

function getReviewQueue() {
    const result = executeSQL('SELECT * FROM review_queue ORDER BY next_review_time ASC');
    return Array.isArray(result) ? result : [];
}

function getDueReviews(currentTime = null) {
    if (!currentTime) {
        currentTime = Math.floor(Date.now() / 1000);
    }
    const result = executeSQL('SELECT * FROM review_queue WHERE next_review_time <= ? ORDER BY next_review_time ASC', [currentTime]);
    return Array.isArray(result) ? result : [];
}

function updateReviewStage(word, correct, currentTime = null) {
    if (!currentTime) {
        currentTime = Math.floor(Date.now() / 1000);
    }
    
    const existing = executeSQL('SELECT * FROM review_queue WHERE word = ?', [word]);
    if (!Array.isArray(existing) || existing.length === 0) return null;
    
    let newStage;
    let nextReviewTime;
    
    if (correct) {
        newStage = Math.min(existing[0].stage + 1, 5);
        const days = Math.pow(2, newStage - 1);
        nextReviewTime = currentTime + (days * 86400);
    } else {
        newStage = 1;
        nextReviewTime = currentTime + 86400;
    }
    
    executeSQL('UPDATE review_queue SET stage = ?, next_review_time = ? WHERE word = ?', [newStage, nextReviewTime, word]);
    
    return { word, stage: newStage, next_review_time: nextReviewTime };
}

function removeFromReviewQueue(word) {
    executeSQL('DELETE FROM review_queue WHERE word = ?', [word]);
}

// ============ HISTORY LOG OPERATIONS ============

function addLog(date, type, count = 1) {
    const existing = executeSQL('SELECT * FROM history_logs WHERE date = ? AND type = ?', [date, type]);
    
    if (Array.isArray(existing) && existing.length > 0) {
        executeSQL('UPDATE history_logs SET count = count + ? WHERE date = ? AND type = ?', [count, date, type]);
    } else {
        executeSQL('INSERT INTO history_logs (date, type, count) VALUES (?, ?, ?)', [date, type, count]);
    }
    
    return getLogs();
}

function getLogs() {
    const result = executeSQL('SELECT * FROM history_logs ORDER BY date DESC');
    return Array.isArray(result) ? result : [];
}

function getLogsByDate(date) {
    const result = executeSQL('SELECT * FROM history_logs WHERE date = ?', [date]);
    return Array.isArray(result) ? result : [];
}

// ============ UTILITY OPERATIONS ============

function getStats() {
    const profile = getProfile();
    const totalWords = executeSQL('SELECT COUNT(*) as count FROM words');
    const queueSize = executeSQL('SELECT COUNT(*) as count FROM review_queue');
    const dueReviews = getDueReviews().length;
    
    return {
        target_exam: profile ? profile.target_exam : '',
        vocabulary_level: profile ? profile.vocabulary_level : 'Medium',
        grammar_basis: profile ? profile.grammar_basis : 'Weak',
        total_words: Array.isArray(totalWords) && totalWords.length > 0 ? totalWords[0].count : 0,
        queue_size: Array.isArray(queueSize) && queueSize.length > 0 ? queueSize[0].count : 0,
        due_reviews: dueReviews
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
    getStats
};
