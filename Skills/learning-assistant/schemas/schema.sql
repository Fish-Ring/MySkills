-- 通用学习助手 v1.4.2 - 数据库模式（全幂等，可重复执行）
-- 初始化：sqlite3 /workspace/learning-assistant/learner.db < schemas/schema.sql

CREATE TABLE IF NOT EXISTS subjects (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT UNIQUE NOT NULL,             -- 科目名（唯一，查重键）
    full_name TEXT,                        -- 全称/代码说明（如"408计算机学科专业基础"）
    weight REAL DEFAULT 1.0,               -- 考试权重
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS topics (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    subject_id INTEGER NOT NULL,
    name TEXT NOT NULL,                    -- 知识点名
    keywords TEXT DEFAULT '',              -- 别名/关键词（逗号分隔，供模糊检索）
    tags TEXT DEFAULT '',                  -- 专业名词标签（1主2细分，逗号分隔，如"矩阵,逆矩阵,秩"）
    parent_id INTEGER,
    exam_weight REAL DEFAULT 3.0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (subject_id) REFERENCES subjects(id),
    FOREIGN KEY (parent_id) REFERENCES topics(id),
    UNIQUE(subject_id, name)               -- 同科目下知识点唯一（查重键）
);

-- 问答流水线：提问记录表
CREATE TABLE IF NOT EXISTS questions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    subject_id INTEGER,
    topic_id INTEGER,
    question TEXT NOT NULL UNIQUE,         -- 问题原文（查重键）
    answer_digest TEXT DEFAULT '',         -- 解答要点摘要（复习用）
    technique TEXT DEFAULT '',             -- 关联的通用答题技巧
    tags TEXT DEFAULT '',                  -- 专业名词标签（1主2细分，如"矩阵,行列式,特征值"）
    times_asked INTEGER DEFAULT 1,         -- 重复提问自动 +1，不重复插入
    last_asked_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (subject_id) REFERENCES subjects(id),
    FOREIGN KEY (topic_id) REFERENCES topics(id)
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

CREATE TABLE IF NOT EXISTS user_profile (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    exam TEXT DEFAULT '',
    stage TEXT DEFAULT '基础',
    exam_date TEXT DEFAULT '',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS history_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    date TEXT,                             -- YYYY-MM-DD
    type TEXT,                             -- qa/exercise/mistake/review/vocab_search
    count INTEGER DEFAULT 0,
    UNIQUE(date, type)
);

INSERT OR IGNORE INTO user_profile (id) VALUES (1);

CREATE INDEX IF NOT EXISTS idx_topics_subject ON topics(subject_id);
CREATE INDEX IF NOT EXISTS idx_topics_subject_id ON topics(subject_id, id DESC);
CREATE INDEX IF NOT EXISTS idx_questions_subject_topic ON questions(subject_id, topic_id, id DESC);
CREATE INDEX IF NOT EXISTS idx_mistakes_topic ON mistakes(topic_id);
CREATE INDEX IF NOT EXISTS idx_mistakes_count ON mistakes(mistake_count DESC);
CREATE INDEX IF NOT EXISTS idx_progress_mastery ON progress(mastery_level ASC);
CREATE INDEX IF NOT EXISTS idx_review_queue_due ON review_queue(next_review_at ASC, is_reviewed ASC);
CREATE INDEX IF NOT EXISTS idx_questions_topic ON questions(topic_id);
CREATE INDEX IF NOT EXISTS idx_questions_last ON questions(last_asked_at DESC);
CREATE INDEX IF NOT EXISTS idx_history_date ON history_logs(date);
