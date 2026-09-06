-- 通用学习助手 v1.5.1 - 数据库模式（全幂等，可重复执行）
-- 初始化：sqlite3 /workspace/learning-assistant/learner.db < schemas/schema.sql
-- v1.5.0 新增三实体分立：progress=Mastery长期状态 / misconceptions=可复用认知模式 / mistakes=单次错误事件

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
    tags TEXT DEFAULT '',                  -- 专业名词标签（1主加最多5细分，自由决定，逗号分隔，如"矩阵,逆矩阵,秩"）
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
    tags TEXT DEFAULT '',                  -- 专业名词标签（1主加最多5细分，自由决定，如"矩阵,行列式,特征值"）
    source TEXT DEFAULT '',                -- 出处：真题/模拟/教材（出题加权用）
    difficulty INTEGER DEFAULT 3,          -- 难度 1-5（出题加权用）
    times_asked INTEGER DEFAULT 1,         -- 重复提问自动 +1，不重复插入
    last_asked_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (subject_id) REFERENCES subjects(id),
    FOREIGN KEY (topic_id) REFERENCES topics(id)
);

-- 题目-知识点 M:N（副知识点关联，主知识点仍走 questions.topic_id，旧查询兼容）
CREATE TABLE IF NOT EXISTS question_topics (
    question_id INTEGER NOT NULL,
    topic_id INTEGER NOT NULL,
    weight REAL DEFAULT 1.0,              -- 关联权重
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (question_id, topic_id),
    FOREIGN KEY (question_id) REFERENCES questions(id) ON DELETE CASCADE,
    FOREIGN KEY (topic_id) REFERENCES topics(id) ON DELETE CASCADE
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

-- Mastery：知识点的长期状态（只存状态不存事件；事件走 mistakes/history_logs）
CREATE TABLE IF NOT EXISTS progress (
    topic_id INTEGER PRIMARY KEY,
    correct_count INTEGER DEFAULT 0,
    wrong_count INTEGER DEFAULT 0,
    consecutive_correct INTEGER DEFAULT 0, -- 连对次数（答错清零；score 加成用）
    mastery_score REAL DEFAULT 0.0,        -- 0-100：100*(cc+连击加成)/(cc+wc)，见 queries.sql 派生规则
    status TEXT DEFAULT 'learning',        -- learning/familiar/mastered/weak（派生规则见 queries.sql）
    last_practice_at TIMESTAMP,
    mastery_level REAL DEFAULT 0.0,        -- 旧列保留兼容，以 mastery_score/status 为准
    FOREIGN KEY (topic_id) REFERENCES topics(id)
);

-- Misconception：可复用的认知错误模式（跨知识点/跨题复用；单次错误走 mistakes）
CREATE TABLE IF NOT EXISTS misconceptions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL,                   -- 错误名称（如"把条件概率当联合概率"）
    type TEXT DEFAULT 'concept',           -- concept/formula/calculation/thinking/careless
    description TEXT DEFAULT '',           -- 错误描述
    occurrence_count INTEGER DEFAULT 1,    -- 出现次数（复用时+1）
    resolved INTEGER DEFAULT 0,            -- 是否已纠正
    confidence REAL DEFAULT 0.5,          -- 判断可信度 0-1
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(title, type)
);

CREATE TABLE IF NOT EXISTS knowledge_misconception (
    topic_id INTEGER NOT NULL,
    misconception_id INTEGER NOT NULL,
    severity INTEGER DEFAULT 3,            -- 严重程度 1-5
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (topic_id, misconception_id),
    FOREIGN KEY (topic_id) REFERENCES topics(id) ON DELETE CASCADE,
    FOREIGN KEY (misconception_id) REFERENCES misconceptions(id) ON DELETE CASCADE
);

-- Mistake↔Misconception M:N（一道错题可挂多个认知错误；错误事件本体仍是 mistakes 表）
CREATE TABLE IF NOT EXISTS mistake_misconceptions (
    mistake_id INTEGER NOT NULL,
    misconception_id INTEGER NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (mistake_id, misconception_id),
    FOREIGN KEY (mistake_id) REFERENCES mistakes(id) ON DELETE CASCADE,
    FOREIGN KEY (misconception_id) REFERENCES misconceptions(id) ON DELETE CASCADE
);

-- 已废弃：通用技能不再使用艾宾浩斯队列（仅 english-learning-assistant 背词保留），兼容保留不写入
CREATE TABLE IF NOT EXISTS review_queue (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    topic_id INTEGER NOT NULL,
    stage INTEGER DEFAULT 1,
    next_review_at INTEGER NOT NULL,
    is_reviewed INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (topic_id) REFERENCES topics(id)
);

-- 技巧专用表（主归属可空表示通用，跨科通过 technique_topics 多关联一行实现，AI 自主决定）
CREATE TABLE IF NOT EXISTS techniques (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,                      -- 技巧名（动词化短语，≤12字，专业名词）
    primary_subject_id INTEGER,              -- 主归属学科，NULL=通用；FK 可空兼容旧库
    description TEXT DEFAULT '',             -- 步骤/触发条件（IF-THEN + 2-5步）
    keywords TEXT DEFAULT '',                -- 别名（逗号分隔，供相似合并）
    tags TEXT DEFAULT '',                    -- 专业名词标签（1主加最多5细分，逗号分隔）
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (primary_subject_id) REFERENCES subjects(id),
    UNIQUE(name, primary_subject_id)
);

CREATE TABLE IF NOT EXISTS technique_topics (
    technique_id INTEGER NOT NULL,
    topic_id INTEGER NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (technique_id, topic_id),
    FOREIGN KEY (technique_id) REFERENCES techniques(id) ON DELETE CASCADE,
    FOREIGN KEY (topic_id) REFERENCES topics(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS technique_questions (
    technique_id INTEGER NOT NULL,
    question_id INTEGER NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (technique_id, question_id),
    FOREIGN KEY (technique_id) REFERENCES techniques(id) ON DELETE CASCADE,
    FOREIGN KEY (question_id) REFERENCES questions(id) ON DELETE CASCADE
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

-- v1.5.1 索引瘦身：M:N 表的 PRIMARY KEY 自带 (a,b) 索引，只需补反向 (b) 索引；
-- idx_topics_subject 被 (subject_id,id) 覆盖；review_queue 已废弃，索引一并退役
DROP INDEX IF EXISTS idx_technique_topics_technique;
DROP INDEX IF EXISTS idx_technique_questions_technique;
DROP INDEX IF EXISTS idx_knowledge_mis_mis;
DROP INDEX IF EXISTS idx_mistake_mis_mis;
DROP INDEX IF EXISTS idx_question_topics_question;
DROP INDEX IF EXISTS idx_topics_subject;
DROP INDEX IF EXISTS idx_review_queue_due;
-- techniques 通用行 primary_subject_id 为 NULL，UNIQUE 对 NULL 不生效，补表达式唯一索引防重
CREATE UNIQUE INDEX IF NOT EXISTS idx_techniques_name_subject ON techniques(name, COALESCE(primary_subject_id,-1));

CREATE INDEX IF NOT EXISTS idx_topics_subject_id ON topics(subject_id, id DESC);
CREATE INDEX IF NOT EXISTS idx_techniques_primary_subject ON techniques(primary_subject_id);
CREATE INDEX IF NOT EXISTS idx_techniques_name ON techniques(name);
CREATE INDEX IF NOT EXISTS idx_technique_topics_topic ON technique_topics(topic_id);
CREATE INDEX IF NOT EXISTS idx_technique_questions_question ON technique_questions(question_id);
CREATE INDEX IF NOT EXISTS idx_misconceptions_type ON misconceptions(type);
CREATE INDEX IF NOT EXISTS idx_knowledge_mis_topic ON knowledge_misconception(topic_id);
CREATE INDEX IF NOT EXISTS idx_mistake_mis_mistake ON mistake_misconceptions(mistake_id);
CREATE INDEX IF NOT EXISTS idx_question_topics_topic ON question_topics(topic_id);
CREATE INDEX IF NOT EXISTS idx_progress_status ON progress(status);
CREATE INDEX IF NOT EXISTS idx_questions_subject_topic ON questions(subject_id, topic_id, id DESC);
CREATE INDEX IF NOT EXISTS idx_mistakes_topic ON mistakes(topic_id);
CREATE INDEX IF NOT EXISTS idx_mistakes_count ON mistakes(mistake_count DESC);
CREATE INDEX IF NOT EXISTS idx_progress_mastery ON progress(mastery_level ASC);
CREATE INDEX IF NOT EXISTS idx_questions_topic ON questions(topic_id);
CREATE INDEX IF NOT EXISTS idx_questions_last ON questions(last_asked_at DESC);
CREATE INDEX IF NOT EXISTS idx_history_date ON history_logs(date);
