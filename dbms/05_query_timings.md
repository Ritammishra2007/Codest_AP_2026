# Query timings

Measured on 22 November 2026 (Asia/Kolkata) using the explicitly selected benchmark database.

- PostgreSQL: `PostgreSQL 18.4 (Postgres.app) on aarch64-apple-darwin23.6.0, compiled by Apple clang version 15.0.0 (clang-1500.3.9.4), 64-bit`
- Fixture row counts: users=2, problems=4, test_cases=20, rooms=2, submissions=2.
- Method: three measured executions per catalog query using
  `EXPLAIN (ANALYZE, BUFFERS, VERBOSE, FORMAT JSON)`.
- Every run has its own BEGIN/ROLLBACK transaction. State preparation, when
  necessary, occurs before EXPLAIN and is excluded from the measured time.
- Milliseconds below are PostgreSQL **Execution Time**, not planning time,
  network round-trip time, API latency, or transaction commit time.
- Raw JSON plans for all three runs, exact SQL and preparation statements are
  preserved in each linked file. Each plan includes its own Planning Time.
- Rollback restores table rows, but not sequence increments or warmed buffers.
  These are repeated small-fixture measurements, not cold-cache benchmarks.
- Successful reads and writes are exercised, including pending-queue joins,
  room activation and real deletes. A new room has no winner yet, so its
  optional winner join correctly returns no matching user.
- Queries are SQL equivalents of Prisma operations; ORM-generated SQL can
  differ. Q13/Q23 represent collection reads belonging to include operations.
- Reset steps run in dependency order via preparation statements. Q18 removes
  the submitting user's previous pending fixture row first. Q25 prepares a
  RUNNING submission; Q26 prepares an accepted result; Q27 prepares a finished
  room with a winning submission and a remaining pending opponent submission.

| Query | Operation | Description | Run 1 (ms) | Run 2 (ms) | Run 3 (ms) | Average (ms) | Raw plans |
|---|---|---|---:|---:|---:|---:|---|
| Q01 | READ | System Health Check Heartbeat | 0.011 | 0.009 | 0.009 | 0.010 | [Plans](plans/q01.txt) |
| Q02 | READ | Registration Duplicate Username/Email Check | 0.011 | 0.011 | 0.010 | 0.011 | [Plans](plans/q02.txt) |
| Q03 | WRITE | Insert Newly Registered User | 0.095 | 0.076 | 0.068 | 0.080 | [Plans](plans/q03.txt) |
| Q04 | READ | Login Credential Lookup by Identifier | 0.011 | 0.014 | 0.010 | 0.012 | [Plans](plans/q04.txt) |
| Q05 | READ | Fetch User Profile by Session JWT ID | 0.010 | 0.011 | 0.011 | 0.011 | [Plans](plans/q05.txt) |
| Q06 | READ | Count Available Seeded Problems | 0.023 | 0.032 | 0.020 | 0.025 | [Plans](plans/q06.txt) |
| Q07 | READ | Select Problem via Random Offset | 0.012 | 0.009 | 0.011 | 0.011 | [Plans](plans/q07.txt) |
| Q08 | READ | Verify 6-Character Room Code Uniqueness | 0.013 | 0.010 | 0.010 | 0.011 | [Plans](plans/q08.txt) |
| Q09 | WRITE | Create New Room in WAITING State | 0.366 | 0.337 | 0.327 | 0.343 | [Plans](plans/q09.txt) |
| Q10 | READ | Lookup Room Details Prior to Joining | 0.012 | 0.010 | 0.013 | 0.012 | [Plans](plans/q10.txt) |
| Q11 | WRITE | Atomic Room Slot Occupation & Activation | 0.222 | 0.203 | 0.190 | 0.205 | [Plans](plans/q11.txt) |
| Q12 | READ | Poll Room State with Players & Problem Joins | 0.030 | 0.030 | 0.028 | 0.029 | [Plans](plans/q12.txt) |
| Q13 | READ | Fetch Sample Test Cases for Problem | 0.022 | 0.020 | 0.021 | 0.021 | [Plans](plans/q13.txt) |
| Q14 | READ | Fetch User Match History (My Rooms) | 0.055 | 0.050 | 0.054 | 0.053 | [Plans](plans/q14.txt) |
| Q15 | READ | Read room before submission (ordinary SELECT) | 0.011 | 0.010 | 0.010 | 0.010 | [Plans](plans/q15.txt) |
| Q16 | READ | Check In-Flight Active Submissions | 0.013 | 0.010 | 0.011 | 0.011 | [Plans](plans/q16.txt) |
| Q17 | WRITE | Set allocated next sequence (current application behavior) | 0.074 | 0.070 | 0.065 | 0.070 | [Plans](plans/q17.txt) |
| Q18 | WRITE | Insert Submission into Queue | 0.306 | 0.275 | 0.248 | 0.276 | [Plans](plans/q18.txt) |
| Q19 | READ | Fetch User Submissions for Room | 0.020 | 0.018 | 0.019 | 0.019 | [Plans](plans/q19.txt) |
| Q20 | WRITE | Judging Worker Crash Recovery Reset | 0.059 | 0.054 | 0.055 | 0.056 | [Plans](plans/q20.txt) |
| Q21 | READ | Find Active Duel Rooms for Queue Polling | 0.011 | 0.011 | 0.011 | 0.011 | [Plans](plans/q21.txt) |
| Q22 | READ | Fetch Next Pending Submission in FIFO Order | 0.032 | 0.028 | 0.031 | 0.030 | [Plans](plans/q22.txt) |
| Q23 | READ | Fetch All Test Cases for Problem Execution | 0.019 | 0.018 | 0.017 | 0.018 | [Plans](plans/q23.txt) |
| Q24 | WRITE | Mark Submission as RUNNING | 0.065 | 0.057 | 0.053 | 0.058 | [Plans](plans/q24.txt) |
| Q25 | WRITE | Record Judging Verdict and Finalize Status | 0.270 | 0.232 | 0.219 | 0.240 | [Plans](plans/q25.txt) |
| Q26 | WRITE | Atomically Crown Winner & Finish Room | 0.141 | 0.142 | 0.140 | 0.141 | [Plans](plans/q26.txt) |
| Q27 | WRITE | Cancel Remaining Submissions in Finished Room | 0.007 | 0.007 | 0.006 | 0.007 | [Plans](plans/q27.txt) |
| Q28 | WRITE | Reset: delete all submissions | 0.046 | 0.040 | 0.043 | 0.043 | [Plans](plans/q28.txt) |
| Q29 | WRITE | Reset: delete all rooms | 0.125 | 0.111 | 0.119 | 0.118 | [Plans](plans/q29.txt) |
| Q30 | WRITE | Reset: delete all test_cases | 0.007 | 0.007 | 0.010 | 0.008 | [Plans](plans/q30.txt) |
| Q31 | WRITE | Reset: delete all problems | 0.093 | 0.079 | 0.086 | 0.086 | [Plans](plans/q31.txt) |
| Q32 | WRITE | Reset: delete all users | 0.089 | 0.093 | 0.090 | 0.091 | [Plans](plans/q32.txt) |
| Q33 | READ | Seed: find existing problem by title | 0.010 | 0.011 | 0.010 | 0.010 | [Plans](plans/q33.txt) |
| Q34 | WRITE | Seed: create problem | 0.078 | 0.061 | 0.060 | 0.066 | [Plans](plans/q34.txt) |
| Q35 | WRITE | Seed: create nested test cases | 0.330 | 0.251 | 0.252 | 0.278 | [Plans](plans/q35.txt) |

## Interpretation and limits

The fixture is intentionally small and deterministic. Sequential scans can be
appropriate at this size; a fast time does not prove an index is optimal or
that the application scales. These results do not validate concurrent request
safety, distributed worker coordination, or end-to-end judging speed.

See 01_normalization.md for the actual transaction/concurrency limitations.
There is no claim that Q15 takes a row lock. The unique sequence key protects
stored uniqueness but is not a substitute for serialized allocation.

All three runs have already been performed; their raw plans are included.
Values depend on PostgreSQL version, machine, fixture size and cache state. Schema DDL, fixture preparation and transaction-control
statements are setup, not catalog queries, so are not included in the table.
