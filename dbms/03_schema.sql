-- Codest: PostgreSQL database schema
-- Run once in a new, empty database.

BEGIN;

CREATE TABLE users (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    username VARCHAR(30) NOT NULL UNIQUE,
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT users_username_not_blank
        CHECK (LENGTH(TRIM(username)) > 0)
);

CREATE TABLE problems (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    title VARCHAR(150) NOT NULL,
    description TEXT NOT NULL,
    input_format TEXT NOT NULL,
    output_format TEXT NOT NULL,
    constraints_text TEXT NOT NULL,
    difficulty VARCHAR(10) NOT NULL DEFAULT 'EASY',
    time_limit_ms INTEGER NOT NULL DEFAULT 2000,

    CONSTRAINT problems_difficulty_valid
        CHECK (difficulty IN ('EASY', 'MEDIUM', 'HARD')),

    CONSTRAINT problems_time_limit_positive
        CHECK (time_limit_ms > 0)
);

CREATE TABLE test_cases (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    problem_id INTEGER NOT NULL REFERENCES problems(id),
    input TEXT NOT NULL,
    expected_output TEXT NOT NULL,
    is_sample BOOLEAN NOT NULL DEFAULT FALSE,
    position INTEGER NOT NULL,

    CONSTRAINT test_cases_position_positive
        CHECK (position > 0),

    CONSTRAINT test_cases_problem_position_unique
        UNIQUE (problem_id, position)
);

CREATE TABLE rooms (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code VARCHAR(6) NOT NULL UNIQUE,
    problem_id INTEGER NOT NULL REFERENCES problems(id),
    player1_id INTEGER NOT NULL REFERENCES users(id),
    player2_id INTEGER REFERENCES users(id),
    status VARCHAR(10) NOT NULL DEFAULT 'WAITING',
    winner_id INTEGER REFERENCES users(id),
    started_at TIMESTAMPTZ,
    ended_at TIMESTAMPTZ,
    next_submission_sequence INTEGER NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT rooms_code_format
        CHECK (code ~ '^[A-Z0-9]{6}$'),

    CONSTRAINT rooms_status_valid
        CHECK (status IN ('WAITING', 'ACTIVE', 'FINISHED')),

    CONSTRAINT rooms_different_players
        CHECK (player2_id IS NULL OR player1_id <> player2_id),

    CONSTRAINT rooms_winner_is_player
        CHECK (
            winner_id IS NULL
            OR winner_id = player1_id
            OR (player2_id IS NOT NULL AND winner_id = player2_id)
        ),

    CONSTRAINT rooms_sequence_positive
        CHECK (next_submission_sequence > 0),

    CONSTRAINT rooms_lifecycle_valid
        CHECK (
            (
                status = 'WAITING'
                AND player2_id IS NULL
                AND started_at IS NULL
                AND ended_at IS NULL
                AND winner_id IS NULL
            )
            OR
            (
                status = 'ACTIVE'
                AND player2_id IS NOT NULL
                AND started_at IS NOT NULL
                AND ended_at IS NULL
                AND winner_id IS NULL
            )
            OR
            (
                status = 'FINISHED'
                AND player2_id IS NOT NULL
                AND started_at IS NOT NULL
                AND ended_at IS NOT NULL
                AND winner_id IS NOT NULL
            )
        ),

    CONSTRAINT rooms_end_after_start
        CHECK (
            ended_at IS NULL
            OR ended_at >= started_at
        )
);

CREATE TABLE submissions (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    room_id INTEGER NOT NULL REFERENCES rooms(id),
    user_id INTEGER NOT NULL REFERENCES users(id),
    sequence_number INTEGER NOT NULL,
    source_code TEXT NOT NULL,
    status VARCHAR(10) NOT NULL DEFAULT 'QUEUED',
    verdict VARCHAR(20),
    submitted_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    judged_at TIMESTAMPTZ,

    CONSTRAINT submissions_sequence_positive
        CHECK (sequence_number > 0),

    CONSTRAINT submissions_room_sequence_unique
        UNIQUE (room_id, sequence_number),

    CONSTRAINT submissions_source_not_blank
        CHECK (LENGTH(TRIM(source_code)) > 0),

    CONSTRAINT submissions_status_valid
        CHECK (
            status IN ('QUEUED', 'RUNNING', 'COMPLETED', 'CANCELLED')
        ),

    CONSTRAINT submissions_verdict_valid
        CHECK (
            verdict IN (
                'ACCEPTED',
                'WRONG_ANSWER',
                'RUNTIME_ERROR',
                'TIME_LIMIT',
                'OUTPUT_LIMIT',
                'JUDGE_ERROR'
            )
        ),

    CONSTRAINT submissions_completion_valid
        CHECK (
            (
                status = 'COMPLETED'
                AND verdict IS NOT NULL
                AND judged_at IS NOT NULL
            )
            OR
            (
                status IN ('QUEUED', 'RUNNING', 'CANCELLED')
                AND verdict IS NULL
                AND judged_at IS NULL
            )
        ),

    CONSTRAINT submissions_judged_after_submission
        CHECK (
            judged_at IS NULL
            OR judged_at >= submitted_at
        )
);

-- Support room-history and submission-history queries.
CREATE INDEX rooms_player1_idx ON rooms(player1_id);
CREATE INDEX rooms_player2_idx ON rooms(player2_id);
CREATE INDEX rooms_problem_idx ON rooms(problem_id);

CREATE INDEX submissions_user_time_idx
    ON submissions(user_id, submitted_at);

-- At most one pending submission per user across the application.
CREATE UNIQUE INDEX submissions_one_pending_per_user
    ON submissions(user_id)
    WHERE status IN ('QUEUED', 'RUNNING');

-- Application transactions must also enforce:
-- 1. A submitting user is a participant in the room.
-- 2. The room is ACTIVE and started_at has been reached.
-- 3. Sequence allocation and submission creation are atomic.
-- 4. Submissions are judged in sequence order within each room.
-- 5. Only the earliest accepted submission wins.
-- There is intentionally no duel deadline column.

COMMIT;