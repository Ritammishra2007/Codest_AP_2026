-- Codest application SQL catalog — PostgreSQL
-- Concrete demonstration parameters match the dataset used in the saved plans.
-- SQL equivalents of Prisma operations, NOT a verbatim ORM query-log capture.
-- JOINs express include relations; Q13 and Q23 fetch their test-case collections.
-- SELECT * preserves model fields; duplicate column names in joined examples
-- correspond to nested objects in Prisma. Timestamp literals use database now()
-- instead of application-supplied Date parameters for a reproducible SQL demo.
-- Repeated calls with different IDs/inputs share one query shape and timing row.
-- Runtime: Q01-Q27. Reset utility: Q28-Q32. Seed utility: Q33-Q35.
-- Schema creation is in 03_schema.sql; test-only verification scripts are excluded.
-- This is a query CATALOG, not an installation script: do not run it end-to-end.
-- WRITE examples include deletes. Each saved measurement used BEGIN/ROLLBACK
-- in a disposable database.
-- Q15-Q18 belong in ONE application transaction with validation between reads
-- and writes. Q15 intentionally has no FOR UPDATE: current source has none.
-- Q17 sets old next_submission_sequence + 1 (fixture old value = 3).
-- Q18 uses the allocated old value. Its isolated benchmark is not the whole flow.
-- Q34 and Q35 represent the nested seed creation transaction; the benchmark of
-- Q35 uses an existing fixture parent, while the app uses Q34's returned id.

-- READ
-- Q01: System Health Check Heartbeat
-- Source: backend/server.js
SELECT 1;

-- READ
-- Q02: Registration Duplicate Username/Email Check
-- Source: backend/controllers/authController.js
SELECT * FROM users WHERE username = 'alice' OR email = 'alice@email.com' LIMIT 1;

-- WRITE
-- Q03: Insert Newly Registered User
-- Source: backend/controllers/authController.js
INSERT INTO users (username,email,password_hash) VALUES ('bench_new','bench_new@codest.local','demo_hash_not_for_login') RETURNING id,username,email,created_at;

-- READ
-- Q04: Login Credential Lookup by Identifier
-- Source: backend/controllers/authController.js
SELECT "id", "username", "email", "password_hash", "created_at" FROM "users" WHERE "username" = 'bob' OR "email" = 'bob' LIMIT 1;

-- READ
-- Q05: Fetch User Profile by Session JWT ID
-- Source: backend/controllers/authController.js
SELECT "id", "username", "email", "created_at" FROM "users" WHERE "id" = 1 LIMIT 1;

-- READ
-- Q06: Count Available Seeded Problems
-- Source: backend/controllers/roomController.js
SELECT COUNT(*) AS "count" FROM "problems";

-- READ
-- Q07: Select Problem via Random Offset
-- Source: backend/controllers/roomController.js
SELECT "id" FROM "problems" OFFSET 1 LIMIT 1;

-- READ
-- Q08: Verify 6-Character Room Code Uniqueness
-- Source: backend/controllers/roomController.js
SELECT * FROM rooms WHERE code = 'WAIT01' LIMIT 1;

-- WRITE
-- Q09: Create New Room in WAITING State
-- Source: backend/controllers/roomController.js
INSERT INTO rooms (code,problem_id,player1_id,status,next_submission_sequence) VALUES ('NEW001',1,1,'WAITING',1) RETURNING id,code,player1_id,player2_id,status,created_at;

-- READ
-- Q10: Lookup Room Details Prior to Joining
-- Source: backend/controllers/roomController.js
SELECT * FROM rooms WHERE code = 'WAIT01' LIMIT 1;

-- WRITE
-- Q11: Atomic Room Slot Occupation & Activation
-- Source: backend/controllers/roomController.js
UPDATE rooms SET player2_id=2,status='ACTIVE',started_at=CURRENT_TIMESTAMP WHERE code='WAIT01' AND status='WAITING' AND player2_id IS NULL;

-- READ
-- Q12: Poll Room State with Players & Problem Joins
-- Source: backend/controllers/roomController.js
SELECT r.*, u1.id AS player1_user_id,u1.username AS player1_username,u2.id AS player2_user_id,u2.username AS player2_username,uw.id AS winner_user_id,uw.username AS winner_username,p.* FROM rooms r LEFT JOIN users u1 ON u1.id=r.player1_id LEFT JOIN users u2 ON u2.id=r.player2_id LEFT JOIN users uw ON uw.id=r.winner_id JOIN problems p ON p.id=r.problem_id WHERE r.code='ACT001' LIMIT 1;

-- READ
-- Q13: Fetch Sample Test Cases for Problem
-- Source: backend/controllers/roomController.js
SELECT "id", "position", "is_sample", "input", "expected_output" FROM "test_cases" WHERE "problem_id" = 1 AND "is_sample" = TRUE ORDER BY "position" ASC;

-- READ
-- Q14: Fetch User Match History (My Rooms)
-- Source: backend/controllers/roomController.js
SELECT r.*,u1.username AS player1_username,u2.username AS player2_username,uw.username AS winner_username FROM rooms r LEFT JOIN users u1 ON u1.id=r.player1_id LEFT JOIN users u2 ON u2.id=r.player2_id LEFT JOIN users uw ON uw.id=r.winner_id WHERE r.player1_id=1 OR r.player2_id=1 ORDER BY r.created_at DESC;

-- READ
-- Q15: Read room before submission (ordinary SELECT)
-- Source: backend/controllers/submissionController.js
SELECT id,status,player1_id,player2_id,next_submission_sequence FROM rooms WHERE id=1 LIMIT 1;

-- READ
-- Q16: Check In-Flight Active Submissions
-- Source: backend/controllers/submissionController.js
SELECT * FROM submissions WHERE room_id=1 AND user_id=1 AND status IN ('PENDING','RUNNING') LIMIT 1;

-- WRITE
-- Q17: Set allocated next sequence (current application behavior)
-- Source: backend/controllers/submissionController.js
UPDATE rooms SET next_submission_sequence=4 WHERE id=1 RETURNING *;

-- WRITE
-- Q18: Insert Submission into Queue
-- Source: backend/controllers/submissionController.js
INSERT INTO submissions (room_id,user_id,sequence_number,source_code,status,verdict) VALUES (1,1,3,'print(8)','PENDING',NULL) RETURNING id,sequence_number,status,submitted_at;

-- READ
-- Q19: Fetch User Submissions for Room
-- Source: backend/controllers/submissionController.js
SELECT "id", "sequence_number", "status", "verdict", "submitted_at", "judged_at" FROM "submissions" WHERE "room_id" = 1 AND "user_id" = 1 ORDER BY "sequence_number" DESC;

-- WRITE
-- Q20: Judging Worker Crash Recovery Reset
-- Source: backend/services/judgingService.js
UPDATE "submissions" SET "status" = 'PENDING' WHERE "status" = 'RUNNING';

-- READ
-- Q21: Find Active Duel Rooms for Queue Polling
-- Source: backend/services/judgingService.js
SELECT "id", "problem_id" FROM "rooms" WHERE "status" = 'ACTIVE';

-- READ
-- Q22: Fetch Next Pending Submission in FIFO Order
-- Source: backend/services/judgingService.js
SELECT s.*,r.*,p.* FROM submissions s JOIN rooms r ON r.id=s.room_id JOIN problems p ON p.id=r.problem_id WHERE s.room_id=1 AND s.status='PENDING' ORDER BY s.sequence_number ASC LIMIT 1;

-- READ
-- Q23: Fetch All Test Cases for Problem Execution
-- Source: backend/services/judgingService.js
SELECT * FROM test_cases WHERE problem_id=1 ORDER BY position ASC;

-- WRITE
-- Q24: Mark Submission as RUNNING
-- Source: backend/services/judgingService.js
UPDATE submissions SET status='RUNNING' WHERE id=1 RETURNING *;

-- WRITE
-- Q25: Record Judging Verdict and Finalize Status
-- Source: backend/services/judgingService.js
UPDATE submissions SET status='DONE',verdict='ACCEPTED',judged_at=CURRENT_TIMESTAMP WHERE id=1 RETURNING *;

-- WRITE
-- Q26: Atomically Crown Winner & Finish Room
-- Source: backend/services/judgingService.js
UPDATE rooms SET status='FINISHED',winner_id=1,ended_at=CURRENT_TIMESTAMP WHERE id=1 AND status='ACTIVE';

-- WRITE
-- Q27: Cancel Remaining Submissions in Finished Room
-- Source: backend/services/judgingService.js
UPDATE "submissions" SET "status" = 'CANCELLED' WHERE "room_id" = 1 AND "status" = 'PENDING';

-- WRITE
-- Q28: Reset: delete all submissions
-- Source: backend/prisma/reset.js
DELETE FROM submissions;

-- WRITE
-- Q29: Reset: delete all rooms
-- Source: backend/prisma/reset.js
DELETE FROM rooms;

-- WRITE
-- Q30: Reset: delete all test_cases
-- Source: backend/prisma/reset.js
DELETE FROM test_cases;

-- WRITE
-- Q31: Reset: delete all problems
-- Source: backend/prisma/reset.js
DELETE FROM problems;

-- WRITE
-- Q32: Reset: delete all users
-- Source: backend/prisma/reset.js
DELETE FROM users;

-- READ
-- Q33: Seed: find existing problem by title
-- Source: backend/prisma/seed.js
SELECT * FROM problems WHERE title='Sum of Two Numbers' LIMIT 1;

-- WRITE
-- Q34: Seed: create problem
-- Source: backend/prisma/seed.js
INSERT INTO problems (title,description,input_format,output_format,constraints_text,difficulty,time_limit_ms) VALUES ('Demo seed problem','Add A and B','Two integers','Their sum','-1000 <= A,B <= 1000','EASY',2000) RETURNING *;

-- WRITE
-- Q35: Seed: create nested test cases
-- Source: backend/prisma/seed.js
INSERT INTO test_cases (problem_id,position,is_sample,input,expected_output) VALUES (1,6,TRUE,'1 2','3'),(1,7,TRUE,'2 2','4'),(1,8,FALSE,'0 1','1'),(1,9,FALSE,'-1 1','0'),(1,10,FALSE,'3 4','7');

