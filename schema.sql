-- =============================================================
-- AUTO-GENERATED SCHEMA EXPORT
-- Source: en-practice-be/docs/schema.sql + all SQL migrations
-- Generated: 2026-04-24 11:31:05
-- Order: base schema -> V*.sql -> migration_*.sql
-- =============================================================

-- -------------------------------------------------------------
-- BEGIN FILE: schema.sql
-- -------------------------------------------------------------
-- =============================================
-- EN Practice - Database Schema
-- PostgreSQL
-- =============================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =============================================
-- 1. USERS
-- =============================================
CREATE TABLE users (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email           VARCHAR(255) NOT NULL UNIQUE,
    password_hash   VARCHAR(255) NOT NULL,
    display_name    VARCHAR(100) NOT NULL,
    role            VARCHAR(20) NOT NULL DEFAULT 'USER',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =============================================
-- 2. VOCABULARY RECORDS
-- Mỗi lần user kiểm tra 1 từ = 1 record
-- =============================================
CREATE TABLE vocabulary_records (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    english_word    VARCHAR(255) NOT NULL,
    user_meaning    TEXT NOT NULL,
    correct_meaning TEXT NOT NULL,
    alternatives    JSONB DEFAULT '[]',
    synonyms        JSONB DEFAULT '[]',
    is_correct      BOOLEAN NOT NULL DEFAULT FALSE,
    tested_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =============================================
-- 3. REVIEW SESSIONS
-- Mỗi phiên ôn tập (nhiều từ) = 1 session
-- =============================================
CREATE TABLE review_sessions (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    filter          VARCHAR(20) NOT NULL DEFAULT 'all',
    total           INTEGER NOT NULL DEFAULT 0,
    correct         INTEGER NOT NULL DEFAULT 0,
    incorrect       INTEGER NOT NULL DEFAULT 0,
    accuracy        INTEGER NOT NULL DEFAULT 0,
    words           JSONB DEFAULT '[]',
    reviewed_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =============================================
-- 4. AUTH SESSIONS
-- Refresh token sessions for rotation and revocation
-- =============================================
CREATE TABLE auth_sessions (
    id                  UUID PRIMARY KEY,
    user_id             UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    refresh_token_hash  VARCHAR(128) NOT NULL UNIQUE,
    expires_at          TIMESTAMPTZ NOT NULL,
    revoked_at          TIMESTAMPTZ,
    last_used_at        TIMESTAMPTZ,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =============================================
-- INDEXES
-- =============================================

-- Truy vấn lịch sử theo thời gian (History page, chart data)
CREATE INDEX idx_vocab_user_tested ON vocabulary_records(user_id, tested_at DESC);

-- Truy vấn từ vựng theo word (review, dedup)
CREATE INDEX idx_vocab_user_word ON vocabulary_records(user_id, english_word);

-- Lọc từ sai (review "từ hay sai", stats)
CREATE INDEX idx_vocab_user_correct ON vocabulary_records(user_id, is_correct);

-- Phiên review gần nhất
CREATE INDEX idx_review_user_date ON review_sessions(user_id, reviewed_at DESC);
CREATE INDEX idx_auth_sessions_user ON auth_sessions(user_id);
CREATE INDEX idx_auth_sessions_expires ON auth_sessions(expires_at);

-- =============================================
-- TRIGGER: auto-update updated_at on users
-- =============================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- END FILE: schema.sql

-- -------------------------------------------------------------
-- BEGIN FILE: V2__writing_feature.sql
-- -------------------------------------------------------------
-- Phase 2: Writing Feature
-- Creates writing_tasks and writing_submissions tables

-- writing_tasks: admin-created writing prompts
CREATE TABLE IF NOT EXISTS writing_tasks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    task_type VARCHAR(20) NOT NULL,
    title VARCHAR(500) NOT NULL,
    content TEXT NOT NULL,
    instruction TEXT,
    image_urls TEXT,
    ai_grading_prompt TEXT,
    difficulty VARCHAR(10) NOT NULL DEFAULT 'MEDIUM',
    is_published BOOLEAN NOT NULL DEFAULT FALSE,
    time_limit_minutes INT NOT NULL DEFAULT 60,
    min_words INT NOT NULL DEFAULT 150,
    max_words INT DEFAULT 300,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- writing_submissions: user essay submissions + AI grading results
CREATE TABLE IF NOT EXISTS writing_submissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id),
    task_id UUID NOT NULL REFERENCES writing_tasks(id) ON DELETE CASCADE,
    essay_content TEXT NOT NULL,
    word_count INT NOT NULL DEFAULT 0,
    time_spent_seconds INT,
    status VARCHAR(20) NOT NULL DEFAULT 'SUBMITTED',
    task_response_score FLOAT,
    coherence_score FLOAT,
    lexical_resource_score FLOAT,
    grammar_score FLOAT,
    overall_band_score FLOAT,
    ai_feedback TEXT,
    submitted_at TIMESTAMPTZ DEFAULT NOW(),
    graded_at TIMESTAMPTZ
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_writing_tasks_task_type ON writing_tasks(task_type);
CREATE INDEX IF NOT EXISTS idx_writing_tasks_difficulty ON writing_tasks(difficulty);
CREATE INDEX IF NOT EXISTS idx_writing_tasks_is_published ON writing_tasks(is_published);
CREATE INDEX IF NOT EXISTS idx_writing_submissions_user_id ON writing_submissions(user_id);
CREATE INDEX IF NOT EXISTS idx_writing_submissions_task_id ON writing_submissions(task_id);
CREATE INDEX IF NOT EXISTS idx_writing_submissions_status ON writing_submissions(status);

-- END FILE: V2__writing_feature.sql

-- -------------------------------------------------------------
-- BEGIN FILE: V3__speaking_feature.sql
-- -------------------------------------------------------------
-- Phase 3: Speaking Feature
-- Creates speaking_topics and speaking_attempts tables

-- speaking_topics: admin-created speaking questions
CREATE TABLE IF NOT EXISTS speaking_topics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    part VARCHAR(10) NOT NULL,
    question TEXT NOT NULL,
    cue_card TEXT,
    follow_up_questions TEXT,
    ai_grading_prompt TEXT,
    difficulty VARCHAR(10) NOT NULL DEFAULT 'MEDIUM',
    is_published BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- speaking_attempts: user recordings + AI grading results
CREATE TABLE IF NOT EXISTS speaking_attempts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id),
    topic_id UUID NOT NULL REFERENCES speaking_topics(id) ON DELETE CASCADE,
    audio_url TEXT,
    transcript TEXT,
    time_spent_seconds INT,
    status VARCHAR(20) NOT NULL DEFAULT 'SUBMITTED',
    fluency_score FLOAT,
    lexical_score FLOAT,
    grammar_score FLOAT,
    pronunciation_score FLOAT,
    overall_band_score FLOAT,
    ai_feedback TEXT,
    submitted_at TIMESTAMPTZ DEFAULT NOW(),
    graded_at TIMESTAMPTZ
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_speaking_topics_part ON speaking_topics(part);
CREATE INDEX IF NOT EXISTS idx_speaking_topics_difficulty ON speaking_topics(difficulty);
CREATE INDEX IF NOT EXISTS idx_speaking_topics_is_published ON speaking_topics(is_published);
CREATE INDEX IF NOT EXISTS idx_speaking_attempts_user_id ON speaking_attempts(user_id);
CREATE INDEX IF NOT EXISTS idx_speaking_attempts_topic_id ON speaking_attempts(topic_id);
CREATE INDEX IF NOT EXISTS idx_speaking_attempts_status ON speaking_attempts(status);

-- END FILE: V3__speaking_feature.sql

-- -------------------------------------------------------------
-- BEGIN FILE: V4__ielts_test_schema.sql
-- -------------------------------------------------------------
-- ============================================================
-- IELTS Test Schema - Phase 1: Listening & Reading
-- ============================================================

-- 1. Main test table
CREATE TABLE ielts_tests (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title           VARCHAR(500) NOT NULL,
    skill           VARCHAR(20)  NOT NULL CHECK (skill IN ('LISTENING', 'READING')),
    time_limit_minutes INT       NOT NULL DEFAULT 60,
    difficulty      VARCHAR(10)  NOT NULL DEFAULT 'MEDIUM' CHECK (difficulty IN ('EASY', 'MEDIUM', 'HARD')),
    is_published    BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- 2. Sections (Part 1-4 for Listening, Section 1-3 for Reading)
CREATE TABLE ielts_sections (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    test_id         UUID         NOT NULL REFERENCES ielts_tests(id) ON DELETE CASCADE,
    section_order   INT          NOT NULL,
    title           VARCHAR(500),
    audio_url       VARCHAR(1000),  -- Only used for Listening
    instructions    TEXT,
    UNIQUE (test_id, section_order)
);

-- 3. Passages (Reading passages or Listening question groups)
CREATE TABLE ielts_passages (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    section_id      UUID         NOT NULL REFERENCES ielts_sections(id) ON DELETE CASCADE,
    passage_order   INT          NOT NULL,
    title           VARCHAR(500),
    content         TEXT,          -- Full passage text for Reading
    UNIQUE (section_id, passage_order)
);

-- 4. Questions
CREATE TABLE ielts_questions (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    passage_id      UUID         NOT NULL REFERENCES ielts_passages(id) ON DELETE CASCADE,
    question_order  INT          NOT NULL,
    question_type   VARCHAR(30)  NOT NULL,
    question_text   TEXT         NOT NULL,
    options         JSONB,        -- e.g. ["A. ...", "B. ...", "C. ..."] for MCQ
    correct_answers JSONB        NOT NULL, -- e.g. ["TRUE"] or ["B"] or ["answer text"]
    explanation     TEXT,
    UNIQUE (passage_id, question_order)
);

-- 5. Test attempts (user history)
CREATE TABLE ielts_test_attempts (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id           UUID         NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    test_id           UUID         NOT NULL REFERENCES ielts_tests(id) ON DELETE CASCADE,
    total_questions   INT          NOT NULL DEFAULT 0,
    correct_count     INT          NOT NULL DEFAULT 0,
    band_score        REAL,
    time_spent_seconds INT,
    status            VARCHAR(20)  NOT NULL DEFAULT 'IN_PROGRESS' CHECK (status IN ('IN_PROGRESS', 'COMPLETED')),
    started_at        TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    completed_at      TIMESTAMPTZ
);

-- 6. Individual answer records
CREATE TABLE ielts_answer_records (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    attempt_id      UUID         NOT NULL REFERENCES ielts_test_attempts(id) ON DELETE CASCADE,
    question_id     UUID         NOT NULL REFERENCES ielts_questions(id) ON DELETE CASCADE,
    user_answer     JSONB,        -- e.g. ["B"] or ["some text"]
    is_correct      BOOLEAN      NOT NULL DEFAULT FALSE,
    UNIQUE (attempt_id, question_id)
);

-- Indexes for performance
CREATE INDEX idx_ielts_tests_skill ON ielts_tests(skill);
CREATE INDEX idx_ielts_tests_published ON ielts_tests(is_published);
CREATE INDEX idx_ielts_sections_test_id ON ielts_sections(test_id);
CREATE INDEX idx_ielts_passages_section_id ON ielts_passages(section_id);
CREATE INDEX idx_ielts_questions_passage_id ON ielts_questions(passage_id);
CREATE INDEX idx_ielts_test_attempts_user_id ON ielts_test_attempts(user_id);
CREATE INDEX idx_ielts_test_attempts_test_id ON ielts_test_attempts(test_id);
CREATE INDEX idx_ielts_answer_records_attempt_id ON ielts_answer_records(attempt_id);

-- END FILE: V4__ielts_test_schema.sql

-- -------------------------------------------------------------
-- BEGIN FILE: V4__speaking_conversation.sql
-- -------------------------------------------------------------
-- Phase 3b: Speaking Conversation Feature
-- Adds tables for multi-turn conversational speaking practice

CREATE TABLE IF NOT EXISTS speaking_conversations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id),
    topic_id UUID NOT NULL REFERENCES speaking_topics(id) ON DELETE CASCADE,
    status VARCHAR(20) NOT NULL DEFAULT 'IN_PROGRESS',
    total_turns INT DEFAULT 0,
    time_spent_seconds INT,
    fluency_score FLOAT,
    lexical_score FLOAT,
    grammar_score FLOAT,
    pronunciation_score FLOAT,
    overall_band_score FLOAT,
    ai_feedback TEXT,
    started_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    graded_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS speaking_conversation_turns (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL REFERENCES speaking_conversations(id) ON DELETE CASCADE,
    turn_number INT NOT NULL,
    ai_question TEXT NOT NULL,
    user_transcript TEXT,
    audio_url TEXT,
    time_spent_seconds INT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_speaking_conv_user_id ON speaking_conversations(user_id);
CREATE INDEX IF NOT EXISTS idx_speaking_conv_topic_id ON speaking_conversations(topic_id);
CREATE INDEX IF NOT EXISTS idx_speaking_conv_status ON speaking_conversations(status);
CREATE INDEX IF NOT EXISTS idx_speaking_conv_turns_conv_id ON speaking_conversation_turns(conversation_id);

-- END FILE: V4__speaking_conversation.sql

-- -------------------------------------------------------------
-- BEGIN FILE: V4b__conversation_hint_system.sql
-- -------------------------------------------------------------
-- V4b: Add turn_type column for adaptive hint system
ALTER TABLE speaking_conversation_turns ADD COLUMN IF NOT EXISTS turn_type VARCHAR(20) DEFAULT 'QUESTION';
-- Also track which follow-up index this QUESTION turn is addressing
ALTER TABLE speaking_conversation_turns ADD COLUMN IF NOT EXISTS follow_up_index INT;

-- END FILE: V4b__conversation_hint_system.sql

-- -------------------------------------------------------------
-- BEGIN FILE: V5__add_role_to_users.sql
-- -------------------------------------------------------------
-- Add role column to users table
ALTER TABLE users ADD COLUMN IF NOT EXISTS role VARCHAR(20) NOT NULL DEFAULT 'USER';

-- Set admin user role
UPDATE users SET role = 'ADMIN' WHERE email = 'admin@enpractice.com';

-- END FILE: V5__add_role_to_users.sql

-- -------------------------------------------------------------
-- BEGIN FILE: V6__user_management.sql
-- -------------------------------------------------------------
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT true;
ALTER TABLE users ADD COLUMN IF NOT EXISTS last_login_at TIMESTAMPTZ;

-- END FILE: V6__user_management.sql

-- -------------------------------------------------------------
-- BEGIN FILE: V7__audit_log.sql
-- -------------------------------------------------------------
CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_id UUID NOT NULL REFERENCES users(id),
    action VARCHAR(50) NOT NULL,
    entity_type VARCHAR(50) NOT NULL,
    entity_id UUID,
    details JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_audit_logs_admin ON audit_logs(admin_id);
CREATE INDEX idx_audit_logs_created ON audit_logs(created_at DESC);

-- END FILE: V7__audit_log.sql

-- -------------------------------------------------------------
-- BEGIN FILE: V8__notification_history.sql
-- -------------------------------------------------------------
CREATE TABLE notification_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_id UUID NOT NULL REFERENCES users(id),
    title VARCHAR(255) NOT NULL,
    body TEXT,
    target_type VARCHAR(20) NOT NULL,
    target_role VARCHAR(20),
    recipients_count INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- END FILE: V8__notification_history.sql

-- -------------------------------------------------------------
-- BEGIN FILE: V9__dashboard_daily_stats.sql
-- -------------------------------------------------------------
CREATE TABLE dashboard_daily_stats (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    stat_date DATE NOT NULL UNIQUE,
    total_users BIGINT DEFAULT 0,
    active_users_today BIGINT DEFAULT 0,
    new_users_this_week BIGINT DEFAULT 0,
    total_ielts BIGINT DEFAULT 0,
    published_ielts BIGINT DEFAULT 0,
    total_speaking BIGINT DEFAULT 0,
    published_speaking BIGINT DEFAULT 0,
    total_writing BIGINT DEFAULT 0,
    published_writing BIGINT DEFAULT 0,
    total_attempts BIGINT DEFAULT 0,
    attempts_today BIGINT DEFAULT 0,
    vocab_today BIGINT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- END FILE: V9__dashboard_daily_stats.sql

-- -------------------------------------------------------------
-- BEGIN FILE: V10__user_activity_logs.sql
-- -------------------------------------------------------------
CREATE TABLE user_activity_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id),
    activity_type VARCHAR(50) NOT NULL,
    entity_id UUID,
    entity_name VARCHAR(255) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_user_activity_logs_user ON user_activity_logs(user_id);
CREATE INDEX idx_user_activity_logs_created ON user_activity_logs(created_at DESC);

-- END FILE: V10__user_activity_logs.sql

-- -------------------------------------------------------------
-- BEGIN FILE: V11__add_device_info_to_fcm_tokens.sql
-- -------------------------------------------------------------
ALTER TABLE fcm_tokens
ADD COLUMN os VARCHAR(50),
ADD COLUMN browser VARCHAR(50);

-- END FILE: V11__add_device_info_to_fcm_tokens.sql

-- -------------------------------------------------------------
-- BEGIN FILE: V12__leaderboard.sql
-- -------------------------------------------------------------
-- =============================================
-- V12: Leaderboard & XP System
-- PostgreSQL
-- =============================================

-- 1. Thêm total_xp vào bảng users
ALTER TABLE users ADD COLUMN IF NOT EXISTS total_xp INT NOT NULL DEFAULT 0;

-- 2. Bảng ghi nhận XP activity
CREATE TABLE user_xp_logs (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    source          VARCHAR(50) NOT NULL,
    source_id       VARCHAR(100),
    xp_amount       INT NOT NULL DEFAULT 0,
    earned_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_xp_logs_user_earned ON user_xp_logs(user_id, earned_at DESC);
CREATE INDEX idx_xp_logs_source ON user_xp_logs(source, source_id);

-- 3. Bảng snapshot leaderboard (pre-computed)
CREATE TABLE leaderboard_snapshots (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    period_type     VARCHAR(20) NOT NULL,   -- WEEKLY, MONTHLY, ALL_TIME
    period_key      VARCHAR(20) NOT NULL,   -- 2025-W03, 2025-01, ALL
    scope           VARCHAR(30) NOT NULL DEFAULT 'GLOBAL',
    xp              INT NOT NULL DEFAULT 0,
    rank            INT NOT NULL DEFAULT 0,
    previous_rank   INT,
    snapshot_date   DATE NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX uk_snapshot
    ON leaderboard_snapshots(user_id, period_type, period_key, scope, snapshot_date);
CREATE INDEX idx_leaderboard_period_scope
    ON leaderboard_snapshots(period_type, period_key, scope, rank);
CREATE INDEX idx_leaderboard_user
    ON leaderboard_snapshots(user_id, period_type, period_key);

-- 4. Bảng tracking XP cap hàng ngày
CREATE TABLE user_daily_xp_cap (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    date            DATE NOT NULL,
    total_xp_earned INT NOT NULL DEFAULT 0
);

CREATE UNIQUE INDEX uk_user_daily_xp ON user_daily_xp_cap(user_id, date);

-- END FILE: V12__leaderboard.sql

-- -------------------------------------------------------------
-- BEGIN FILE: V13__user_dictionary.sql
-- -------------------------------------------------------------
CREATE TABLE user_dictionary (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

    -- Core Word Data
    word                VARCHAR(200) NOT NULL,
    ipa                 VARCHAR(200),
    word_type           VARCHAR(50),
    
    -- Meaning & Usage
    meaning             TEXT NOT NULL,
    explanation         TEXT,
    note                TEXT,
    examples            JSONB DEFAULT '[]',
    
    -- Organization & Metadata
    tags                JSONB DEFAULT '[]',
    source_type         VARCHAR(50) DEFAULT 'MANUAL',
    source_reference_id UUID,
    is_favorite         BOOLEAN NOT NULL DEFAULT FALSE,

    -- Learning/SRS Tracking
    proficiency_level   INT NOT NULL DEFAULT 0,
    last_reviewed_at    TIMESTAMPTZ,
    next_review_at      TIMESTAMPTZ,
    review_count        INT NOT NULL DEFAULT 0,

    -- Timestamps
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Constraints
    CONSTRAINT uq_user_word UNIQUE (user_id, word)
);

-- Indexes for performance
CREATE INDEX idx_user_dict_user_id ON user_dictionary(user_id);
CREATE INDEX idx_user_dict_word ON user_dictionary(word);
CREATE INDEX idx_user_dict_tags ON user_dictionary USING GIN (tags);
CREATE INDEX idx_user_dict_next_review ON user_dictionary(user_id, next_review_at);

-- END FILE: V13__user_dictionary.sql

-- -------------------------------------------------------------
-- BEGIN FILE: V14__speech_analytics.sql
-- -------------------------------------------------------------
-- V14: Speech analytics columns
-- Adds word-level speech metrics to speaking_attempts and speaking_conversation_turns
-- for pronunciation analysis, pause detection, and speech rate measurement.

-- ─── speaking_attempts ────────────────────────────────────────────────────────
ALTER TABLE speaking_attempts
    ADD COLUMN IF NOT EXISTS word_count            INT,
    ADD COLUMN IF NOT EXISTS words_per_minute      NUMERIC(7, 2),
    ADD COLUMN IF NOT EXISTS pause_count           INT,
    ADD COLUMN IF NOT EXISTS avg_pause_duration_ms NUMERIC(10, 2),
    ADD COLUMN IF NOT EXISTS long_pause_count      INT,
    ADD COLUMN IF NOT EXISTS filler_word_count     INT,
    ADD COLUMN IF NOT EXISTS avg_word_confidence   NUMERIC(6, 4),
    -- JSON storage for list data (filler words, low-confidence words, per-word details)
    ADD COLUMN IF NOT EXISTS speech_data_json      TEXT;

-- ─── speaking_conversation_turns ─────────────────────────────────────────────
ALTER TABLE speaking_conversation_turns
    ADD COLUMN IF NOT EXISTS word_count            INT,
    ADD COLUMN IF NOT EXISTS words_per_minute      NUMERIC(7, 2),
    ADD COLUMN IF NOT EXISTS pause_count           INT,
    ADD COLUMN IF NOT EXISTS avg_pause_duration_ms NUMERIC(10, 2),
    ADD COLUMN IF NOT EXISTS long_pause_count      INT,
    ADD COLUMN IF NOT EXISTS filler_word_count     INT,
    ADD COLUMN IF NOT EXISTS avg_word_confidence   NUMERIC(6, 4),
    ADD COLUMN IF NOT EXISTS speech_data_json      TEXT;

-- Index for querying attempts by speech quality
CREATE INDEX IF NOT EXISTS idx_speaking_attempts_wpm
    ON speaking_attempts (words_per_minute)
    WHERE words_per_minute IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_speaking_attempts_avg_confidence
    ON speaking_attempts (avg_word_confidence)
    WHERE avg_word_confidence IS NOT NULL;


-- END FILE: V14__speech_analytics.sql

-- -------------------------------------------------------------
-- BEGIN FILE: V15__custom_speaking_conversation.sql
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS custom_speaking_conversations
(
    id                     UUID PRIMARY KEY      DEFAULT gen_random_uuid(),
    user_id                UUID         NOT NULL REFERENCES users (id),
    title                  VARCHAR(255) NOT NULL,
    topic                  TEXT         NOT NULL,
    style                  VARCHAR(30)  NOT NULL,
    personality            VARCHAR(30)  NOT NULL,
    voice_name             VARCHAR(30)  NOT NULL,
    expertise              VARCHAR(30)  NOT NULL,
    grading_enabled        BOOLEAN      NOT NULL DEFAULT FALSE,
    status                 VARCHAR(20)  NOT NULL DEFAULT 'IN_PROGRESS',
    max_user_turns         INT          NOT NULL,
    user_turn_count        INT          NOT NULL DEFAULT 0,
    total_turns            INT          NOT NULL DEFAULT 0,
    time_spent_seconds     INT,
    fluency_score          FLOAT,
    vocabulary_score       FLOAT,
    coherence_score        FLOAT,
    pronunciation_score    FLOAT,
    overall_score          FLOAT,
    ai_feedback            TEXT,
    system_prompt_snapshot TEXT,
    started_at             TIMESTAMPTZ           DEFAULT NOW(),
    completed_at           TIMESTAMPTZ,
    graded_at              TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS custom_speaking_conversation_turns
(
    id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id       UUID NOT NULL REFERENCES custom_speaking_conversations (id) ON DELETE CASCADE,
    turn_number           INT  NOT NULL,
    ai_message            TEXT NOT NULL,
    user_transcript       TEXT,
    audio_url             TEXT,
    time_spent_seconds    INT,
    word_count            INT,
    words_per_minute      NUMERIC(7, 2),
    pause_count           INT,
    avg_pause_duration_ms NUMERIC(10, 2),
    long_pause_count      INT,
    filler_word_count     INT,
    avg_word_confidence   NUMERIC(6, 4),
    speech_data_json      TEXT,
    created_at            TIMESTAMPTZ      DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_custom_speaking_conv_user_id
    ON custom_speaking_conversations (user_id);

CREATE INDEX IF NOT EXISTS idx_custom_speaking_conv_status
    ON custom_speaking_conversations (status);

CREATE INDEX IF NOT EXISTS idx_custom_speaking_conv_turns_conv_id
    ON custom_speaking_conversation_turns (conversation_id);

-- END FILE: V15__custom_speaking_conversation.sql

-- -------------------------------------------------------------
-- BEGIN FILE: V16__user_profile.sql
-- -------------------------------------------------------------
ALTER TABLE users
    ADD COLUMN IF NOT EXISTS avatar_url VARCHAR(500),
    ADD COLUMN IF NOT EXISTS bio TEXT;

CREATE TABLE IF NOT EXISTS user_profiles (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    target_ielts_band REAL,
    target_exam_date DATE,
    daily_goal_minutes INTEGER NOT NULL DEFAULT 30,
    weekly_word_goal INTEGER,
    preferred_skill VARCHAR(50),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_user_profiles_target_band
    ON user_profiles(target_ielts_band);

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_trigger
        WHERE tgname = 'trigger_user_profiles_updated_at'
    ) THEN
        CREATE TRIGGER trigger_user_profiles_updated_at
            BEFORE UPDATE ON user_profiles
            FOR EACH ROW
            EXECUTE FUNCTION update_updated_at_column();
    END IF;
END $$;

-- END FILE: V16__user_profile.sql

-- -------------------------------------------------------------
-- BEGIN FILE: V17__user_profile_snapshot.sql
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS user_profile_snapshots (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    total_xp INTEGER NOT NULL DEFAULT 0,
    current_level INTEGER NOT NULL DEFAULT 1,
    current_level_min_xp INTEGER NOT NULL DEFAULT 0,
    next_level INTEGER NOT NULL DEFAULT 2,
    next_level_min_xp INTEGER NOT NULL DEFAULT 100,
    xp_into_current_level INTEGER NOT NULL DEFAULT 0,
    xp_needed_for_next_level INTEGER NOT NULL DEFAULT 100,
    level_progress_percentage INTEGER NOT NULL DEFAULT 0,
    weekly_xp INTEGER NOT NULL DEFAULT 0,
    total_lessons_completed BIGINT NOT NULL DEFAULT 0,
    total_words_learned BIGINT NOT NULL DEFAULT 0,
    total_study_minutes INTEGER NOT NULL DEFAULT 0,
    studied_minutes_today INTEGER NOT NULL DEFAULT 0,
    words_to_review_today BIGINT NOT NULL DEFAULT 0,
    favorite_words BIGINT NOT NULL DEFAULT 0,
    new_words BIGINT NOT NULL DEFAULT 0,
    learning_words BIGINT NOT NULL DEFAULT 0,
    current_streak INTEGER NOT NULL DEFAULT 0,
    longest_streak INTEGER NOT NULL DEFAULT 0,
    active_days_last_30 INTEGER NOT NULL DEFAULT 0,
    last_30_days_heatmap JSONB NOT NULL DEFAULT '[]'::jsonb,
    listening_band REAL,
    reading_band REAL,
    speaking_band REAL,
    writing_band REAL,
    overall_band REAL,
    vocab_total_words BIGINT NOT NULL DEFAULT 0,
    vocab_mastered_words BIGINT NOT NULL DEFAULT 0,
    vocab_reviewing_words BIGINT NOT NULL DEFAULT 0,
    computed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_user_profile_snapshots_computed_at
    ON user_profile_snapshots(computed_at DESC);

-- END FILE: V17__user_profile_snapshot.sql

-- -------------------------------------------------------------
-- BEGIN FILE: V18__notifications.sql
-- -------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TABLE IF NOT EXISTS notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    type VARCHAR(50) NOT NULL,
    title VARCHAR(255) NOT NULL,
    body TEXT,
    priority VARCHAR(20) NOT NULL DEFAULT 'NORMAL',
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    action_url VARCHAR(500),
    reference_type VARCHAR(100),
    reference_id UUID,
    metadata JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    read_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_notifications_user_created_at
    ON notifications(user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_notifications_user_is_read
    ON notifications(user_id, is_read, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_notifications_user_type
    ON notifications(user_id, type, created_at DESC);

-- END FILE: V18__notifications.sql

-- -------------------------------------------------------------
-- BEGIN FILE: V19__notification_preferences_and_delivery_logs.sql
-- -------------------------------------------------------------
ALTER TABLE notifications
    ADD COLUMN IF NOT EXISTS dedup_key VARCHAR(200);

CREATE UNIQUE INDEX IF NOT EXISTS uq_notifications_user_dedup_key
    ON notifications(user_id, dedup_key)
    WHERE dedup_key IS NOT NULL;

CREATE TABLE IF NOT EXISTS notification_preferences (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    allow_push BOOLEAN NOT NULL DEFAULT TRUE,
    allow_email BOOLEAN NOT NULL DEFAULT FALSE,
    allow_vocabulary_reminder BOOLEAN NOT NULL DEFAULT TRUE,
    allow_grading_result BOOLEAN NOT NULL DEFAULT TRUE,
    allow_admin_broadcast BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS notification_delivery_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    notification_id UUID REFERENCES notifications(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    channel VARCHAR(20) NOT NULL,
    status VARCHAR(20) NOT NULL,
    target_value VARCHAR(500),
    provider_message_id VARCHAR(255),
    error_code VARCHAR(100),
    error_message VARCHAR(1000),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    delivered_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_notification_delivery_logs_notification
    ON notification_delivery_logs(notification_id, channel, status);

CREATE INDEX IF NOT EXISTS idx_notification_delivery_logs_user
    ON notification_delivery_logs(user_id, created_at DESC);

-- END FILE: V19__notification_preferences_and_delivery_logs.sql

-- -------------------------------------------------------------
-- BEGIN FILE: V20__notification_preference_extensions.sql
-- -------------------------------------------------------------
ALTER TABLE notification_preferences
    ADD COLUMN IF NOT EXISTS allow_new_content_notification BOOLEAN NOT NULL DEFAULT TRUE,
    ADD COLUMN IF NOT EXISTS allow_weekly_summary BOOLEAN NOT NULL DEFAULT TRUE,
    ADD COLUMN IF NOT EXISTS allow_xp_reward_notification BOOLEAN NOT NULL DEFAULT TRUE;

-- END FILE: V20__notification_preference_extensions.sql

-- -------------------------------------------------------------
-- BEGIN FILE: V21__notification_progress_reminder_preference.sql
-- -------------------------------------------------------------
ALTER TABLE notification_preferences
    ADD COLUMN IF NOT EXISTS allow_progress_reminder BOOLEAN NOT NULL DEFAULT TRUE;

-- END FILE: V21__notification_progress_reminder_preference.sql

-- -------------------------------------------------------------
-- BEGIN FILE: V22__notification_band_and_personalization_preferences.sql
-- -------------------------------------------------------------
ALTER TABLE notification_preferences
    ADD COLUMN IF NOT EXISTS allow_band_improvement_notification BOOLEAN NOT NULL DEFAULT TRUE,
    ADD COLUMN IF NOT EXISTS allow_personalized_recommendation BOOLEAN NOT NULL DEFAULT TRUE;

-- END FILE: V22__notification_band_and_personalization_preferences.sql

-- -------------------------------------------------------------
-- BEGIN FILE: V23__notification_reengagement_and_leaderboard_preferences.sql
-- -------------------------------------------------------------
ALTER TABLE notification_preferences
    ADD COLUMN IF NOT EXISTS allow_reengagement_notification BOOLEAN NOT NULL DEFAULT TRUE,
    ADD COLUMN IF NOT EXISTS allow_leaderboard_notification BOOLEAN NOT NULL DEFAULT TRUE;

-- END FILE: V23__notification_reengagement_and_leaderboard_preferences.sql

-- -------------------------------------------------------------
-- BEGIN FILE: V24__add_ielts_section_transcript.sql
-- -------------------------------------------------------------
ALTER TABLE ielts_sections
ADD COLUMN transcript TEXT;

-- END FILE: V24__add_ielts_section_transcript.sql

-- -------------------------------------------------------------
-- BEGIN FILE: V25__learning_lifecycle_events.sql
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS learning_lifecycle_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    event_name VARCHAR(100) NOT NULL,
    source VARCHAR(100) NOT NULL,
    module VARCHAR(50),
    route VARCHAR(255),
    reference_type VARCHAR(100),
    reference_id UUID,
    session_id UUID,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_learning_lifecycle_events_user_occurred
    ON learning_lifecycle_events(user_id, occurred_at DESC);

CREATE INDEX IF NOT EXISTS idx_learning_lifecycle_events_name_occurred
    ON learning_lifecycle_events(event_name, occurred_at DESC);

-- END FILE: V25__learning_lifecycle_events.sql

-- -------------------------------------------------------------
-- BEGIN FILE: V26__retention_daily_stats.sql
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS retention_daily_stats (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    stat_date DATE NOT NULL UNIQUE,
    dau BIGINT NOT NULL DEFAULT 0,
    d1_return_users BIGINT NOT NULL DEFAULT 0,
    users_with_learning_session BIGINT NOT NULL DEFAULT 0,
    continue_learning_impressions BIGINT NOT NULL DEFAULT 0,
    continue_learning_clicks BIGINT NOT NULL DEFAULT 0,
    continue_learning_ctr DOUBLE PRECISION NOT NULL DEFAULT 0,
    daily_task_impressions BIGINT NOT NULL DEFAULT 0,
    daily_task_clicks BIGINT NOT NULL DEFAULT 0,
    daily_task_completed BIGINT NOT NULL DEFAULT 0,
    daily_task_completion_rate DOUBLE PRECISION NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_retention_daily_stats_date
    ON retention_daily_stats(stat_date DESC);

-- END FILE: V26__retention_daily_stats.sql

-- -------------------------------------------------------------
-- BEGIN FILE: V27__user_recommendation_feedback.sql
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS user_recommendation_feedback (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    recommendation_key VARCHAR(150) NOT NULL,
    action_type VARCHAR(20) NOT NULL,
    source_surface VARCHAR(30) NOT NULL,
    snooze_until TIMESTAMPTZ NULL,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_user_recommendation_feedback_user_created
    ON user_recommendation_feedback(user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_user_recommendation_feedback_user_key
    ON user_recommendation_feedback(user_id, recommendation_key, created_at DESC);

-- END FILE: V27__user_recommendation_feedback.sql

-- -------------------------------------------------------------
-- BEGIN FILE: V28__achievement_and_challenge_tables.sql
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS achievement_definitions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(100) NOT NULL UNIQUE,
    title VARCHAR(150) NOT NULL,
    description TEXT NOT NULL,
    rule_type VARCHAR(50) NOT NULL,
    rule_threshold INTEGER NOT NULL,
    icon VARCHAR(100),
    active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS user_achievements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    achievement_definition_id UUID NOT NULL REFERENCES achievement_definitions(id) ON DELETE CASCADE,
    unlocked_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_user_achievement UNIQUE (user_id, achievement_definition_id)
);

CREATE INDEX IF NOT EXISTS idx_user_achievements_user_id
    ON user_achievements(user_id);

CREATE TABLE IF NOT EXISTS weekly_challenge_definitions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(100) NOT NULL UNIQUE,
    title VARCHAR(150) NOT NULL,
    description TEXT NOT NULL,
    rule_type VARCHAR(50) NOT NULL,
    target_value INTEGER NOT NULL,
    reward_xp INTEGER NOT NULL,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS user_weekly_challenge_progress (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    challenge_definition_id UUID NOT NULL REFERENCES weekly_challenge_definitions(id) ON DELETE CASCADE,
    week_start TIMESTAMPTZ NOT NULL,
    week_end TIMESTAMPTZ NOT NULL,
    current_value INTEGER NOT NULL DEFAULT 0,
    completed BOOLEAN NOT NULL DEFAULT FALSE,
    completed_at TIMESTAMPTZ NULL,
    reward_granted_at TIMESTAMPTZ NULL,
    CONSTRAINT uq_user_weekly_challenge UNIQUE (user_id, challenge_definition_id, week_start)
);

CREATE INDEX IF NOT EXISTS idx_user_weekly_challenge_user_week
    ON user_weekly_challenge_progress(user_id, week_start DESC);

INSERT INTO achievement_definitions (code, title, description, rule_type, rule_threshold, icon, active, sort_order)
VALUES
    ('STREAK_3', '3-Day Streak', 'Giữ nhịp học liên tiếp trong 3 ngày.', 'STREAK_DAYS', 3, 'streak-3', TRUE, 10),
    ('STREAK_7', '7-Day Streak', 'Giữ nhịp học liên tiếp trong 7 ngày.', 'STREAK_DAYS', 7, 'streak-7', TRUE, 20),
    ('VOCAB_REVIEW_10', 'Vocabulary Keeper', 'Hoàn thành 10 phiên ôn từ vựng.', 'VOCAB_REVIEW_COUNT', 10, 'vocab-10', TRUE, 30),
    ('SPEAKING_5', 'Speaking Starter', 'Hoàn thành 5 phiên luyện speaking.', 'SPEAKING_PRACTICE_COUNT', 5, 'speaking-5', TRUE, 40),
    ('WEEKLY_CHALLENGE_FIRST', 'Challenge Cleared', 'Hoàn thành challenge tuần đầu tiên.', 'WEEKLY_CHALLENGE_COMPLETED', 1, 'challenge-1', TRUE, 50)
ON CONFLICT (code) DO NOTHING;

INSERT INTO weekly_challenge_definitions (code, title, description, rule_type, target_value, reward_xp, active, sort_order)
VALUES
    ('WEEKLY_LEARNING_5', 'Giữ nhịp 5 phiên học', 'Hoàn thành 5 phiên học thật trong tuần này để nhận thưởng XP.', 'LEARNING_COMPLETIONS', 5, 40, TRUE, 10)
ON CONFLICT (code) DO NOTHING;

-- END FILE: V28__achievement_and_challenge_tables.sql

-- -------------------------------------------------------------
-- BEGIN FILE: V29__daily_speaking_prompt_catalog.sql
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS daily_speaking_prompt_catalog (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    topic VARCHAR(255) NOT NULL,
    prompt TEXT NOT NULL,
    persona VARCHAR(100),
    difficulty VARCHAR(30),
    active BOOLEAN NOT NULL DEFAULT TRUE,
    tags JSONB NOT NULL DEFAULT '[]'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO daily_speaking_prompt_catalog (topic, prompt, persona, difficulty, active, tags)
VALUES
    ('Learning habit', 'Talk for one minute about a study habit that helps you learn faster.', 'Encouraging coach', 'Easy', TRUE, '["habit","study"]'::jsonb),
    ('Technology and learning', 'Do you think technology helps students learn better, or does it create more distraction?', 'IELTS examiner', 'Medium', TRUE, '["technology","education"]'::jsonb),
    ('Daily routine', 'Describe one part of your daily routine that you would like to improve and explain why.', 'Friendly partner', 'Easy', TRUE, '["routine","self-improvement"]'::jsonb),
    ('Future goals', 'What is one English-learning goal you want to reach this year, and how will you get there?', 'Goal coach', 'Medium', TRUE, '["goal","english"]'::jsonb)
ON CONFLICT DO NOTHING;

-- END FILE: V29__daily_speaking_prompt_catalog.sql

-- -------------------------------------------------------------
-- BEGIN FILE: V30__user_weekly_reports.sql
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS user_weekly_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    week_start TIMESTAMPTZ NOT NULL,
    week_end TIMESTAMPTZ NOT NULL,
    study_minutes INTEGER,
    vocabulary_learned INTEGER,
    tests_completed INTEGER,
    band_improvement REAL
);

CREATE INDEX IF NOT EXISTS idx_user_weekly_reports_user_week_end
    ON user_weekly_reports(user_id, week_end DESC);

CREATE INDEX IF NOT EXISTS idx_user_weekly_reports_week_start
    ON user_weekly_reports(week_start DESC);

-- END FILE: V30__user_weekly_reports.sql

-- -------------------------------------------------------------
-- BEGIN FILE: V31__ielts_quick_test.sql
-- -------------------------------------------------------------
ALTER TABLE ielts_test_attempts
    ADD COLUMN IF NOT EXISTS attempt_mode VARCHAR(20) NOT NULL DEFAULT 'FULL',
    ADD COLUMN IF NOT EXISTS scope_type VARCHAR(20) NOT NULL DEFAULT 'TEST',
    ADD COLUMN IF NOT EXISTS scope_id UUID,
    ADD COLUMN IF NOT EXISTS question_ids_snapshot JSONB NOT NULL DEFAULT '[]'::jsonb,
    ADD COLUMN IF NOT EXISTS source_recommendation_key VARCHAR(150),
    ADD COLUMN IF NOT EXISTS source_surface VARCHAR(50);

UPDATE ielts_test_attempts
SET attempt_mode = COALESCE(attempt_mode, 'FULL'),
    scope_type = COALESCE(scope_type, 'TEST'),
    scope_id = COALESCE(scope_id, test_id)
WHERE attempt_mode IS NULL
   OR scope_type IS NULL
   OR scope_id IS NULL;

CREATE INDEX IF NOT EXISTS idx_ielts_test_attempts_user_status_started
    ON ielts_test_attempts(user_id, status, started_at DESC);

CREATE INDEX IF NOT EXISTS idx_ielts_test_attempts_user_completed
    ON ielts_test_attempts(user_id, completed_at DESC);

CREATE INDEX IF NOT EXISTS idx_ielts_test_attempts_test_scope
    ON ielts_test_attempts(test_id, scope_type, scope_id);

-- END FILE: V31__ielts_quick_test.sql

-- -------------------------------------------------------------
-- BEGIN FILE: V32__user_activity_logs_metadata.sql
-- -------------------------------------------------------------
ALTER TABLE user_activity_logs
    ADD COLUMN IF NOT EXISTS metadata JSONB NOT NULL DEFAULT '{}'::jsonb;

-- END FILE: V32__user_activity_logs_metadata.sql

-- -------------------------------------------------------------
-- BEGIN FILE: V33__daily_task_runtime.sql
-- -------------------------------------------------------------
CREATE TABLE user_daily_task_plans (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL,
    task_date DATE NOT NULL,
    generation_seed BIGINT NOT NULL,
    total_tasks INTEGER NOT NULL DEFAULT 0,
    completed_tasks INTEGER NOT NULL DEFAULT 0,
    bonus_xp_awarded BOOLEAN NOT NULL DEFAULT FALSE,
    bonus_xp_awarded_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_user_daily_task_plans_user_date UNIQUE (user_id, task_date)
);

CREATE TABLE user_daily_task_items (
    id UUID PRIMARY KEY,
    plan_id UUID NOT NULL REFERENCES user_daily_task_plans(id) ON DELETE CASCADE,
    user_id UUID NOT NULL,
    task_date DATE NOT NULL,
    sort_order INTEGER NOT NULL,
    task_type VARCHAR(50) NOT NULL,
    task_subtype VARCHAR(100),
    title VARCHAR(255) NOT NULL,
    description TEXT NOT NULL,
    action_url VARCHAR(500) NOT NULL,
    estimated_minutes INTEGER NOT NULL,
    xp_reward INTEGER NOT NULL,
    difficulty VARCHAR(50),
    reference_type VARCHAR(100),
    reference_id UUID,
    reference_key VARCHAR(200),
    progress_target INTEGER NOT NULL DEFAULT 1,
    progress_value INTEGER NOT NULL DEFAULT 0,
    completed BOOLEAN NOT NULL DEFAULT FALSE,
    completed_at TIMESTAMP WITH TIME ZONE,
    completion_reference_id UUID,
    xp_awarded BOOLEAN NOT NULL DEFAULT FALSE,
    xp_awarded_at TIMESTAMP WITH TIME ZONE,
    metadata JSONB,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- END FILE: V33__daily_task_runtime.sql

-- -------------------------------------------------------------
-- BEGIN FILE: V34__daily_task_supporting_indexes.sql
-- -------------------------------------------------------------
CREATE INDEX idx_user_daily_task_plans_user_date
    ON user_daily_task_plans(user_id, task_date);

CREATE INDEX idx_user_daily_task_items_user_date_sort
    ON user_daily_task_items(user_id, task_date, sort_order);

CREATE INDEX idx_user_daily_task_items_user_date_completed
    ON user_daily_task_items(user_id, task_date, completed);

CREATE INDEX idx_user_daily_task_items_user_type_reference
    ON user_daily_task_items(user_id, task_type, reference_id, task_date);

CREATE INDEX idx_user_daily_task_items_user_type_reference_key
    ON user_daily_task_items(user_id, task_type, reference_key, task_date);

-- END FILE: V34__daily_task_supporting_indexes.sql

-- -------------------------------------------------------------
-- BEGIN FILE: V35__user_word_lookup_events.sql
-- -------------------------------------------------------------
CREATE TABLE user_word_lookup_events (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL,
    word VARCHAR(200) NOT NULL,
    normalized_word VARCHAR(200) NOT NULL,
    source VARCHAR(50) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_user_word_lookup_events_user_created
    ON user_word_lookup_events(user_id, created_at DESC);

CREATE INDEX idx_user_word_lookup_events_user_normalized
    ON user_word_lookup_events(user_id, normalized_word, created_at DESC);

-- END FILE: V35__user_word_lookup_events.sql

-- -------------------------------------------------------------
-- BEGIN FILE: V36__learning_lifecycle_event_dedup.sql
-- -------------------------------------------------------------
ALTER TABLE learning_lifecycle_events
    ADD COLUMN IF NOT EXISTS dedup_key VARCHAR(255);

CREATE UNIQUE INDEX IF NOT EXISTS uq_learning_lifecycle_events_user_dedup_key
    ON learning_lifecycle_events (user_id, dedup_key)
    WHERE dedup_key IS NOT NULL;

-- END FILE: V36__learning_lifecycle_event_dedup.sql

-- -------------------------------------------------------------
-- BEGIN FILE: V37__admin_job_runs.sql
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS admin_jobs (
    job_key VARCHAR(120) PRIMARY KEY,
    job_group VARCHAR(80) NOT NULL,
    job_title VARCHAR(200) NOT NULL,
    owner_class VARCHAR(255) NOT NULL,
    method_name VARCHAR(120) NOT NULL,
    display_order INTEGER NOT NULL,
    CONSTRAINT uk_admin_jobs_owner_method UNIQUE (owner_class, method_name)
);

CREATE INDEX IF NOT EXISTS idx_admin_jobs_display_order
    ON admin_jobs (display_order);

INSERT INTO admin_jobs (job_key, job_group, job_title, owner_class, method_name, display_order)
VALUES
    ('daily-engagement-progress-reminders', 'daily-engagement', 'Daily Progress Reminders', 'com.swpts.enpracticebe.scheduler.DailyEngagementReminderScheduler', 'sendDailyProgressReminders', 1),
    ('daily-engagement-streak-milestones', 'daily-engagement', 'Streak Milestone Notifications', 'com.swpts.enpracticebe.scheduler.DailyEngagementReminderScheduler', 'sendStreakMilestoneNotifications', 2),
    ('dashboard-daily-stats', 'dashboard', 'Dashboard Daily Stats', 'com.swpts.enpracticebe.scheduler.DashboardStatsScheduler', 'calculateDailyStats', 3),
    ('dashboard-weekly-reports', 'dashboard', 'Dashboard Weekly Reports', 'com.swpts.enpracticebe.scheduler.DashboardStatsScheduler', 'generateWeeklyReports', 4),
    ('executor-health-monitor', 'system', 'Executor Health Monitor', 'com.swpts.enpracticebe.scheduler.ExecutorHealthMonitorScheduler', 'logExecutorHealth', 5),
    ('gamification-sync', 'gamification', 'Gamification Read Model Sync', 'com.swpts.enpracticebe.scheduler.GamificationSyncScheduler', 'syncGamificationReadModels', 6),
    ('inactive-user-nudges', 'retention', 'Inactive User Nudges', 'com.swpts.enpracticebe.scheduler.InactivityNudgeScheduler', 'sendInactiveUserNudges', 7),
    ('leaderboard-weekly-ranks', 'leaderboard', 'Leaderboard Weekly Ranks', 'com.swpts.enpracticebe.scheduler.LeaderboardScheduler', 'computeWeeklyRanks', 8),
    ('leaderboard-monthly-ranks', 'leaderboard', 'Leaderboard Monthly Ranks', 'com.swpts.enpracticebe.scheduler.LeaderboardScheduler', 'computeMonthlyRanks', 9),
    ('leaderboard-all-time-ranks', 'leaderboard', 'Leaderboard All-Time Ranks', 'com.swpts.enpracticebe.scheduler.LeaderboardScheduler', 'computeAllTimeRanks', 10),
    ('leaderboard-archive-expired-snapshots', 'leaderboard', 'Leaderboard Archive Expired Snapshots', 'com.swpts.enpracticebe.scheduler.LeaderboardScheduler', 'archiveExpiredSnapshots', 11),
    ('mascot-messages', 'ai', 'Mascot Messages', 'com.swpts.enpracticebe.scheduler.MascotScheduler', 'computeMascotMessagesForAllUsers', 12),
    ('recommendations', 'ai', 'Practice Recommendations', 'com.swpts.enpracticebe.scheduler.RecommendationScheduler', 'computeRecommendationsForAllUsers', 13),
    ('smart-reminders', 'ai', 'Smart Reminders', 'com.swpts.enpracticebe.scheduler.SmartReminderScheduler', 'computeSmartRemindersForAllUsers', 14),
    ('retention-daily-stats', 'retention', 'Retention Daily Stats', 'com.swpts.enpracticebe.scheduler.RetentionStatsScheduler', 'calculateDailyRetentionStats', 15),
    ('retention-streak-risk', 'retention', 'Retention Streak Risk Notifications', 'com.swpts.enpracticebe.scheduler.RetentionTriggerScheduler', 'sendStreakRiskNotifications', 16),
    ('retention-daily-plan-one-left', 'retention', 'Retention Daily Plan One Task Left Notifications', 'com.swpts.enpracticebe.scheduler.RetentionTriggerScheduler', 'sendDailyPlanOneTaskLeftNotifications', 17),
    ('retention-due-vocab-quick-review', 'retention', 'Retention Due Vocab Quick Review Notifications', 'com.swpts.enpracticebe.scheduler.RetentionTriggerScheduler', 'sendDueQuickReviewNotifications', 18),
    ('retention-weekly-report-ready', 'retention', 'Retention Weekly Report Ready Notifications', 'com.swpts.enpracticebe.scheduler.RetentionTriggerScheduler', 'sendWeeklyReportReadyNotifications', 19),
    ('daily-task-generation', 'daily-task', 'Daily Task Generation', 'com.swpts.enpracticebe.scheduler.UserDailyTaskGenerationScheduler', 'generateTodayTasks', 20),
    ('user-profile-snapshot-refresh', 'profile', 'User Profile Snapshot Refresh', 'com.swpts.enpracticebe.scheduler.UserProfileSnapshotScheduler', 'refreshSnapshotsEveryThirtyMinutes', 21),
    ('user-profile-snapshot-nightly-refresh', 'profile', 'User Profile Snapshot Nightly Refresh', 'com.swpts.enpracticebe.scheduler.UserProfileSnapshotScheduler', 'nightlyFullRefresh', 22),
    ('vocabulary-reminders', 'vocabulary', 'Vocabulary Reminders', 'com.swpts.enpracticebe.scheduler.VocabularyReminderService', 'sendDailyVocabularyReminders', 23),
    ('weekly-rewards', 'leaderboard', 'Weekly Rewards', 'com.swpts.enpracticebe.scheduler.WeeklyRewardJob', 'distributeWeeklyRewards', 24)
ON CONFLICT (job_key) DO UPDATE SET
    job_group = EXCLUDED.job_group,
    job_title = EXCLUDED.job_title,
    owner_class = EXCLUDED.owner_class,
    method_name = EXCLUDED.method_name,
    display_order = EXCLUDED.display_order;

CREATE TABLE IF NOT EXISTS admin_job_runs (
    id UUID PRIMARY KEY,
    job_key VARCHAR(120) NOT NULL,
    job_group VARCHAR(80) NOT NULL,
    job_title VARCHAR(200) NOT NULL,
    trigger_type VARCHAR(20) NOT NULL,
    triggered_by_admin_id UUID NULL,
    status VARCHAR(20) NOT NULL,
    error_message VARCHAR(4000) NULL,
    started_at TIMESTAMP WITH TIME ZONE NOT NULL,
    finished_at TIMESTAMP WITH TIME ZONE NOT NULL,
    duration_ms BIGINT NOT NULL DEFAULT 0,
    CONSTRAINT ck_admin_job_runs_trigger_type CHECK (trigger_type IN ('CRON', 'MANUAL')),
    CONSTRAINT ck_admin_job_runs_status CHECK (status IN ('SUCCESS', 'FAILED'))
);

CREATE INDEX IF NOT EXISTS idx_admin_job_runs_job_key_started_at
    ON admin_job_runs (job_key, started_at DESC);

CREATE INDEX IF NOT EXISTS idx_admin_job_runs_trigger_type_started_at
    ON admin_job_runs (trigger_type, started_at DESC);

CREATE INDEX IF NOT EXISTS idx_admin_job_runs_status_started_at
    ON admin_job_runs (status, started_at DESC);

-- END FILE: V37__admin_job_runs.sql

-- -------------------------------------------------------------
-- BEGIN FILE: V38__vocabulary_test.sql
-- -------------------------------------------------------------
CREATE TABLE vocabulary_tests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'READY',
    question_count INT NOT NULL,
    estimated_minutes INT NOT NULL,
    selected_sources JSONB NOT NULL DEFAULT '[]'::jsonb,
    source_words_snapshot JSONB NOT NULL DEFAULT '[]'::jsonb,
    generator_model VARCHAR(100),
    prompt_version VARCHAR(50),
    source_surface VARCHAR(50),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE vocabulary_test_questions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    test_id UUID NOT NULL REFERENCES vocabulary_tests(id) ON DELETE CASCADE,
    question_order INT NOT NULL,
    source_word VARCHAR(200) NOT NULL,
    source_type VARCHAR(50) NOT NULL,
    question_text TEXT NOT NULL,
    blank_sentence TEXT NOT NULL,
    options JSONB NOT NULL DEFAULT '[]'::jsonb,
    correct_answer VARCHAR(200) NOT NULL,
    correct_option_index INT NOT NULL,
    explanation TEXT,
    CONSTRAINT uq_vocabulary_test_questions_test_order UNIQUE (test_id, question_order)
);

CREATE TABLE vocabulary_test_attempts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    test_id UUID NOT NULL REFERENCES vocabulary_tests(id) ON DELETE CASCADE,
    total_questions INT NOT NULL,
    correct_count INT NOT NULL DEFAULT 0,
    accuracy_percent NUMERIC(5,2),
    time_spent_seconds INT,
    status VARCHAR(20) NOT NULL DEFAULT 'IN_PROGRESS',
    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ
);

CREATE TABLE vocabulary_test_answer_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    attempt_id UUID NOT NULL REFERENCES vocabulary_test_attempts(id) ON DELETE CASCADE,
    question_id UUID NOT NULL REFERENCES vocabulary_test_questions(id) ON DELETE CASCADE,
    selected_option_index INT,
    selected_answer VARCHAR(200),
    is_correct BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT uq_vocabulary_test_answer_records_attempt_question UNIQUE (attempt_id, question_id)
);

CREATE INDEX idx_vocab_tests_user_created
    ON vocabulary_tests(user_id, created_at DESC);

CREATE INDEX idx_vocab_test_attempts_user_started
    ON vocabulary_test_attempts(user_id, started_at DESC);

CREATE INDEX idx_vocab_test_attempts_user_completed
    ON vocabulary_test_attempts(user_id, completed_at DESC);

CREATE INDEX idx_vocab_test_questions_test_order
    ON vocabulary_test_questions(test_id, question_order);

CREATE INDEX idx_vocab_test_answers_attempt
    ON vocabulary_test_answer_records(attempt_id);

-- END FILE: V38__vocabulary_test.sql

-- -------------------------------------------------------------
-- BEGIN FILE: V39__system_config_versions.sql
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS system_config_versions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    version_no BIGINT NOT NULL UNIQUE,
    status VARCHAR(20) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT false,
    base_version_id UUID NULL,
    config_payload JSONB NOT NULL,
    change_summary VARCHAR(1000) NULL,
    created_by_admin_id UUID NOT NULL,
    activated_by_admin_id UUID NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    activated_at TIMESTAMP WITH TIME ZONE NULL,
    checksum VARCHAR(128) NOT NULL,
    CONSTRAINT ck_system_config_versions_status CHECK (status IN ('DRAFT', 'ACTIVE', 'ARCHIVED'))
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_system_config_versions_active_true
    ON system_config_versions (is_active)
    WHERE is_active = true;

CREATE INDEX IF NOT EXISTS idx_system_config_versions_created_at_desc
    ON system_config_versions (created_at DESC);

CREATE INDEX IF NOT EXISTS idx_system_config_versions_status_created_at_desc
    ON system_config_versions (status, created_at DESC);

INSERT INTO system_config_versions (
    version_no,
    status,
    is_active,
    base_version_id,
    config_payload,
    change_summary,
    created_by_admin_id,
    activated_by_admin_id,
    created_at,
    activated_at,
    checksum
)
VALUES (
    1,
    'ACTIVE',
    true,
    NULL,
    '{
      "gamification": {
        "xp": {
          "maxDailyXp": 300,
          "minimumDurationSeconds": {
            "fullTest": 600,
            "miniTest": 180,
            "speakingPractice": 90,
            "writingSubmission": 300,
            "vocabularyTest": 120
          }
        },
        "leaderboard": {
          "cron": {
            "weekly": "0 */15 * * * *",
            "monthly": "0 0 * * * *",
            "allTime": "0 0 */6 * * *",
            "archive": "0 0 2 * * *",
            "weeklyReward": "0 5 0 * * MON"
          },
          "rankChangeNotification": {
            "top3Threshold": 3,
            "top10Threshold": 10,
            "top50Threshold": 50,
            "strongImprovementDelta": 3,
            "pageSize": 100
          },
          "weeklyReward": {
            "pageSize": 100,
            "rank1Xp": 200,
            "rank2To3Xp": 100,
            "rank4To10Xp": 50,
            "rank11To50Xp": 25,
            "participantXp": 10
          }
        },
        "dailyTask": {
          "generation": {
            "cron": "0 5 0 * * *",
            "zone": "UTC",
            "activeUserBatchSize": 200
          },
          "selection": {
            "pageSize": 50,
            "maxScanPages": 4,
            "vocabularyTargetTaskCount": 4,
            "vocabularyMinTaskCount": 2,
            "vocabularyDictionaryScanSize": 50
          },
          "rewards": {
            "vocabTaskXp": 8,
            "allTasksBonusXp": 20
          }
        }
      },
      "notification": {
        "reminders": {
          "zone": "UTC",
          "quietHoursStart": 22,
          "quietHoursEnd": 7,
          "dailyProgressCron": "0 0 18 * * *",
          "streakMilestoneCron": "0 15 20 * * *",
          "goalThresholdPercent": 60,
          "targetMinutes": 30,
          "streakMilestones": [3, 7, 14, 30, 60, 100]
        },
        "retention": {
          "streakRiskCron": "0 0 18 * * *",
          "dailyOneLeftCron": "0 30 19 * * *",
          "dueVocabCron": "0 0 17 * * *",
          "weeklyReportCron": "0 15 8 * * MON",
          "inactiveCron": "0 0 14 * * *",
          "suppressionHours": {
            "streakRisk": 12,
            "dailyPlanOneTaskLeft": 6,
            "dueVocabQuickReview": 12,
            "weeklyReportReady": 168,
            "reengagement3d": 24,
            "reengagement7d": 24
          }
        },
        "bulkDispatch": {
          "batchSize": 100,
          "spacingMinutes": 3,
          "initialDelaySeconds": 60
        }
      },
      "profile": {
        "defaultDailyGoalMinutes": 30,
        "heatmapDays": 30,
        "approxVocabSecondsPerRecord": 15
      },
      "recommendation": {
        "scheduler": {
          "computeCron": "0 0 */6 * * *",
          "batchSize": 200
        },
        "snapshot": {
          "staleHours": 6,
          "feedVisibleItems": 5
        },
        "signals": {
          "dueReviewFetchSize": 5,
          "dueReviewMinActionLimit": 5,
          "unfinishedFreshHours": 12,
          "dueReviewFreshHours": 12,
          "weakSkillFreshHours": 24,
          "goalClosingFreshHours": 6,
          "fallbackFreshHours": 24,
          "goalClosingMaxRemainingMinutes": 10,
          "unfinishedDefaultEstimatedMinutes": 10,
          "dueReviewEstimatedMinutes": 4,
          "goalClosingMinEstimatedMinutes": 3,
          "goalClosingMaxEstimatedMinutes": 5,
          "fallbackEstimatedMinutes": 3
        },
        "quickPractice": {
          "quickReviewLimit": 10,
          "dueReviewMinEstimatedMinutes": 3,
          "dueReviewMaxEstimatedMinutes": 6,
          "quickVocabEstimatedMinutes": 4,
          "miniIeltsEstimatedMinutes": 8,
          "speakingEstimatedMinutes": 5
        },
        "quickLaunch": {
          "candidateTestLimit": 12,
          "fallbackFullTestMinutes": 60,
          "scopedMinMinutes": 5
        }
      },
      "vocabulary": {
        "reminder": {
          "cron": "0 0 10 * * ?",
          "previewWords": 5,
          "quickReviewLimit": 10,
          "estimatedMinutes": 4
        },
        "microLearning": {
          "fetchDueWordCount": 5,
          "targetWordCount": 5,
          "estimatedMinutes": 4
        },
        "tests": {
          "maxDailyGeneratedTests": 5
        }
      },
      "speaking": {
        "customConversation": {
          "maxUserTurns": 100
        },
        "dailyPrompt": {
          "estimatedMinutes": 4
        }
      }
    }'::jsonb,
    'Initial seed from hardcoded/runtime defaults',
    '00000000-0000-0000-0000-000000000000',
    '00000000-0000-0000-0000-000000000000',
    NOW(),
    NOW(),
    'seed-v1'
)
ON CONFLICT (version_no) DO NOTHING;

-- END FILE: V39__system_config_versions.sql

-- -------------------------------------------------------------
-- BEGIN FILE: V40__system_config_group_versions.sql
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS system_config_group_versions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_key VARCHAR(64) NOT NULL,
    version_no BIGINT NOT NULL,
    status VARCHAR(20) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT false,
    base_version_id UUID NULL,
    config_payload JSONB NOT NULL,
    change_summary VARCHAR(1000) NULL,
    created_by_admin_id UUID NOT NULL,
    activated_by_admin_id UUID NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    activated_at TIMESTAMP WITH TIME ZONE NULL,
    checksum VARCHAR(128) NOT NULL,
    CONSTRAINT ck_system_config_group_versions_status CHECK (status IN ('DRAFT', 'ACTIVE', 'ARCHIVED')),
    CONSTRAINT uq_system_config_group_versions_group_version UNIQUE (group_key, version_no)
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_system_config_group_versions_active_true
    ON system_config_group_versions (group_key)
    WHERE is_active = true;

CREATE INDEX IF NOT EXISTS idx_system_config_group_versions_group_created_at_desc
    ON system_config_group_versions (group_key, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_system_config_group_versions_group_status_created_at_desc
    ON system_config_group_versions (group_key, status, created_at DESC);

WITH active_monolith AS (
    SELECT *
    FROM system_config_versions
    WHERE is_active = true
    ORDER BY activated_at DESC NULLS LAST, created_at DESC
    LIMIT 1
)
INSERT INTO system_config_group_versions (
    group_key,
    version_no,
    status,
    is_active,
    base_version_id,
    config_payload,
    change_summary,
    created_by_admin_id,
    activated_by_admin_id,
    created_at,
    activated_at,
    checksum
)
SELECT seeded.group_key,
       1,
       'ACTIVE',
       true,
       NULL,
       seeded.config_payload,
       'Seed from active monolith system config',
       seeded.created_by_admin_id,
       seeded.activated_by_admin_id,
       seeded.created_at,
       seeded.activated_at,
       seeded.checksum
FROM (
    SELECT 'gamification' AS group_key,
           config_payload -> 'gamification' AS config_payload,
           created_by_admin_id,
           COALESCE(activated_by_admin_id, created_by_admin_id) AS activated_by_admin_id,
           created_at,
           COALESCE(activated_at, created_at) AS activated_at,
           'seed-gamification-v1' AS checksum
    FROM active_monolith
    WHERE config_payload ? 'gamification'

    UNION ALL

    SELECT 'profile',
           config_payload -> 'profile',
           created_by_admin_id,
           COALESCE(activated_by_admin_id, created_by_admin_id),
           created_at,
           COALESCE(activated_at, created_at),
           'seed-profile-v1'
    FROM active_monolith
    WHERE config_payload ? 'profile'

    UNION ALL

    SELECT 'notification',
           config_payload -> 'notification',
           created_by_admin_id,
           COALESCE(activated_by_admin_id, created_by_admin_id),
           created_at,
           COALESCE(activated_at, created_at),
           'seed-notification-v1'
    FROM active_monolith
    WHERE config_payload ? 'notification'

    UNION ALL

    SELECT 'recommendation',
           config_payload -> 'recommendation',
           created_by_admin_id,
           COALESCE(activated_by_admin_id, created_by_admin_id),
           created_at,
           COALESCE(activated_at, created_at),
           'seed-recommendation-v1'
    FROM active_monolith
    WHERE config_payload ? 'recommendation'

    UNION ALL

    SELECT 'vocabulary',
           config_payload -> 'vocabulary',
           created_by_admin_id,
           COALESCE(activated_by_admin_id, created_by_admin_id),
           created_at,
           COALESCE(activated_at, created_at),
           'seed-vocabulary-v1'
    FROM active_monolith
    WHERE config_payload ? 'vocabulary'

    UNION ALL

    SELECT 'speaking',
           config_payload -> 'speaking',
           created_by_admin_id,
           COALESCE(activated_by_admin_id, created_by_admin_id),
           created_at,
           COALESCE(activated_at, created_at),
           'seed-speaking-v1'
    FROM active_monolith
    WHERE config_payload ? 'speaking'
) seeded
ON CONFLICT (group_key, version_no) DO NOTHING;

-- END FILE: V40__system_config_group_versions.sql

-- -------------------------------------------------------------
-- BEGIN FILE: V41__notification_i18n_support.sql
-- -------------------------------------------------------------
ALTER TABLE notifications
    ADD COLUMN IF NOT EXISTS title_key VARCHAR(150),
    ADD COLUMN IF NOT EXISTS body_key VARCHAR(150),
    ADD COLUMN IF NOT EXISTS message_params JSONB;

ALTER TABLE notification_delivery_logs
    ADD COLUMN IF NOT EXISTS locale VARCHAR(16);

-- END FILE: V41__notification_i18n_support.sql

-- -------------------------------------------------------------
-- BEGIN FILE: V42__user_profile_preferred_language.sql
-- -------------------------------------------------------------
ALTER TABLE user_profiles
    ADD COLUMN IF NOT EXISTS preferred_language VARCHAR(16);

UPDATE user_profiles
SET preferred_language = 'en'
WHERE preferred_language IS NULL;

-- END FILE: V42__user_profile_preferred_language.sql

-- -------------------------------------------------------------
-- BEGIN FILE: V43__custom_speaking_conversation_memory_summary.sql
-- -------------------------------------------------------------
ALTER TABLE custom_speaking_conversations
    ADD COLUMN IF NOT EXISTS memory_summary TEXT;

-- END FILE: V43__custom_speaking_conversation_memory_summary.sql

-- -------------------------------------------------------------
-- BEGIN FILE: V44__vocabulary_record_enrichment.sql
-- -------------------------------------------------------------
ALTER TABLE vocabulary_records
    ADD COLUMN IF NOT EXISTS normalized_word VARCHAR(255),
    ADD COLUMN IF NOT EXISTS accepted_meanings_vi JSONB NOT NULL DEFAULT '[]'::jsonb,
    ADD COLUMN IF NOT EXISTS meaning_explanation TEXT,
    ADD COLUMN IF NOT EXISTS example_sentences JSONB NOT NULL DEFAULT '[]'::jsonb,
    ADD COLUMN IF NOT EXISTS enrichment_status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    ADD COLUMN IF NOT EXISTS enrichment_source VARCHAR(30),
    ADD COLUMN IF NOT EXISTS enrichment_version VARCHAR(50),
    ADD COLUMN IF NOT EXISTS enrichment_requested_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS enriched_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS enrichment_error VARCHAR(2000);

UPDATE vocabulary_records
SET normalized_word = LOWER(REGEXP_REPLACE(BTRIM(COALESCE(english_word, '')), '\s+', ' ', 'g'))
WHERE normalized_word IS NULL;

UPDATE vocabulary_records
SET accepted_meanings_vi =
        CASE
            WHEN COALESCE(jsonb_array_length(accepted_meanings_vi), 0) > 0 THEN accepted_meanings_vi
            ELSE (
                CASE
                    WHEN alternatives IS NULL THEN jsonb_build_array(correct_meaning)
                    ELSE jsonb_build_array(correct_meaning) || alternatives
                END
            )
        END
WHERE accepted_meanings_vi = '[]'::jsonb;

ALTER TABLE vocabulary_records
    ALTER COLUMN normalized_word SET NOT NULL;

CREATE INDEX IF NOT EXISTS idx_vocab_user_normalized_tested
    ON vocabulary_records (user_id, normalized_word, tested_at DESC);

CREATE INDEX IF NOT EXISTS idx_vocab_enrichment_status_tested
    ON vocabulary_records (enrichment_status, tested_at DESC);

-- END FILE: V44__vocabulary_record_enrichment.sql

-- -------------------------------------------------------------
-- BEGIN FILE: migration_mascot_messages.sql
-- -------------------------------------------------------------
-- =============================================
-- Mascot Messages (Pre-computed AI encouragements)
-- =============================================
CREATE TABLE mascot_messages (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id     UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    messages    JSONB DEFAULT '[]',
    computed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_mascot_messages_user_id ON mascot_messages(user_id);

-- END FILE: migration_mascot_messages.sql

-- -------------------------------------------------------------
-- BEGIN FILE: migration_user_practice_recommendations.sql
-- -------------------------------------------------------------
-- =============================================
-- User Practice Recommendations (Pre-computed)
-- =============================================
CREATE TABLE user_practice_recommendations (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    weak_skills     JSONB DEFAULT '[]',
    recommendations JSONB DEFAULT '[]',
    computed_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_upr_user_id ON user_practice_recommendations(user_id);

-- END FILE: migration_user_practice_recommendations.sql

-- -------------------------------------------------------------
-- BEGIN FILE: migration_user_smart_reminders.sql
-- -------------------------------------------------------------
-- =============================================
-- User Smart Reminders (Pre-computed AI smart reminders)
-- =============================================
CREATE TABLE user_smart_reminders (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id     UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    reminder    JSONB DEFAULT '{}',
    computed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_user_smart_reminders_user_id ON user_smart_reminders(user_id);

-- END FILE: migration_user_smart_reminders.sql

