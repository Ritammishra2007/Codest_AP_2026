-- Codest | PostgreSQL application queries
-- Schema: dbms/03_schema.sql (users, problems, test_cases, rooms, submissions).
-- Each named statement represents one database operation in the project plan.
-- READ and WRITE describe what happens when the statement is executed.
--
-- To inspect these in psql, use a fresh connection to a database with the schema:
--   \i dbms/04_queries.sql
--   EXECUTE my_duels(1);
-- Loading the file only prepares statements. EXECUTE runs a chosen statement.
-- $1, $2, ... are bound parameters. The API takes the current user ID from
-- the verified JWT. Prisma can express these operations with its client or
-- parameterized SQL. The transaction groups below use one connection.

-- 1. Accounts

-- POST /api/auth/register | $1 username, $2 email, $3 bcrypt password hash.
-- A unique-constraint error means the username or email is already in use.
-- WRITE
PREPARE register_user(text, text, text) AS
INSERT INTO users (username, email, password_hash)
VALUES ($1, lower(trim($2)), $3)
RETURNING id, username, email;

-- POST /api/auth/login | $1 email. Only the auth service sees the hash.
-- READ
PREPARE login_by_email(text) AS
SELECT id, username, password_hash
FROM users
WHERE email = lower(trim($1));

-- GET /api/auth/me | $1 current user ID.
-- READ
PREPARE my_account(integer) AS
SELECT id, username, email, created_at
FROM users
WHERE id = $1;

-- 2. Rooms, polling, and duel history

-- POST /api/rooms | $1 generated six-character code, $2 creator ID.
-- An empty result means there is no problem with tests. On a duplicate room
-- code the API retries a bounded number of times with a new code.
-- WRITE
PREPARE create_room(text, integer) AS
INSERT INTO rooms (code, player1_id, problem_id)
SELECT $1, $2, p.id
FROM problems AS p
WHERE EXISTS (SELECT 1 FROM test_cases AS t WHERE t.problem_id = p.id)
ORDER BY random()
LIMIT 1
RETURNING id, code, status;

-- POST /api/rooms/join | $1 room code, $2 joining user ID.
-- One conditional update claims the second seat even if two players try at once.
-- Zero rows means the room is unavailable to this player.
-- WRITE
PREPARE join_room(text, integer) AS
UPDATE rooms
SET player2_id = $2, status = 'ACTIVE',
    started_at = statement_timestamp() + interval '5 seconds'
WHERE code = upper(trim($1)) AND status = 'WAITING'
  AND player2_id IS NULL AND player1_id <> $2
RETURNING id, code, status, started_at;

-- GET /api/rooms/:code | $1 room code, $2 current user ID.
-- LEFT JOIN keeps waiting rooms visible. Problem fields appear at the start.
-- READ
PREPARE room_state(text, integer) AS
SELECT r.code, r.status, r.started_at, r.ended_at, statement_timestamp() AS server_now,
       host.username AS player1, guest.username AS player2, winner.username AS winner,
       p.title, p.description, p.input_format, p.output_format, p.constraints_text,
       p.difficulty, p.time_limit_ms
FROM rooms AS r
JOIN users AS host ON host.id = r.player1_id
LEFT JOIN users AS guest ON guest.id = r.player2_id
LEFT JOIN users AS winner ON winner.id = r.winner_id
LEFT JOIN problems AS p ON p.id = r.problem_id AND r.started_at <= statement_timestamp()
WHERE r.code = upper(trim($1)) AND $2 IN (r.player1_id, r.player2_id);

-- Same endpoint | $1 room code, $2 current user ID. Return these samples
-- alongside the problem only when room_state has revealed the statement.
-- READ
PREPARE visible_samples(text, integer) AS
SELECT t.position, t.input, t.expected_output
FROM rooms AS r
JOIN test_cases AS t ON t.problem_id = r.problem_id
WHERE r.code = upper(trim($1)) AND $2 IN (r.player1_id, r.player2_id)
  AND r.started_at <= statement_timestamp() AND t.is_sample
ORDER BY t.position;

-- GET /api/users/me/duels | $1 current user ID. The lobby uses this too.
-- READ
PREPARE my_duels(integer) AS
SELECT r.code, r.status, r.created_at, r.started_at, r.ended_at,
       opponent.username AS opponent, p.title, winner.username AS winner
FROM rooms AS r