# Codest — Database Normalization

## 1. Project Overview

Codest is a Python-only, one-versus-one competitive programming
web application.

Two registered users join a room and solve the same programming
problem. Submissions are processed in server-assigned order.
The earliest submission in that order that passes all test cases wins.

There is no duel deadline.

## 2. Business Rules

1. Each user has a unique username and email address.
2. A room contains one creator and at most one opponent.
3. The two players must be different users.
4. Each room is assigned one programming problem.
5. A problem has multiple test cases.
6. A test case may be a visible sample or a hidden test.
7. Each submission belongs to one room and one user.
8. A user can make multiple submissions over time.
9. Submissions have a unique sequence number within their room.
10. A room can have at most one winner.
11. The winner must be one of the room's players.
12. Passwords are stored as hashes, never as plaintext.

## 3. Unnormalized Form (UNF)

A conceptual unnormalized room record might contain:

ROOM_RECORD(
    room_id,
    room_code,
    player1_details,
    player2_details,
    problem_details,
    test_cases[],
    submissions[],
    winner_id
)

The player details include username, email, and password hash.
The problem details include title, description, and difficulty.

Problems with this structure:

- Test cases and submissions are repeating groups.
- User details are duplicated across rooms.
- Problem details are duplicated whenever a problem is reused.
- Updating duplicated information can produce inconsistencies.
- Deleting a room could accidentally remove the only stored copy
  of a user or problem.

## 4. First Normal Form (1NF)

A relation is in 1NF when each field contains a single value
and repeating groups are removed.

We replace nested user/problem details with individual fields
and move repeating test cases and submissions into separate rows.

For example, a flattened submission relation could contain:

SUBMISSION_DETAIL(
    room_id,
    sequence_number,
    room_code,
    problem_id,
    problem_title,
    user_id,
    username,
    source_code,
    verdict
)

Its composite candidate key is:

(room_id, sequence_number)

Each row represents exactly one submission, with no list of
submissions inside a field.

However, this relation still contains duplicated information.

## 5. Second Normal Form (2NF)

A relation is in 2NF when it is in 1NF and each non-key attribute
depends on the entire candidate key, not just part of it.

In SUBMISSION_DETAIL:

room_id → room_code, problem_id

These fields depend only on room_id, which is part of the composite
key (room_id, sequence_number).

To remove these partial dependencies, separate room information
from submission information:

ROOM(
    room_id,
    room_code,
    problem_id,
    problem_title,
    ...
)

SUBMISSION(
    room_id,
    sequence_number,
    user_id,
    username,
    source_code,
    verdict,
    ...
)

Test cases are also stored separately from rooms and submissions.

Some transitive dependencies remain.

## 6. Third Normal Form (3NF)

A relation is in 3NF when it is in 2NF and non-key attributes do
not depend transitively on a candidate key through another
non-key attribute.

Examples of transitive dependencies:

room_id → problem_id → problem_title

(room_id, sequence_number) → user_id → username

We remove these by storing problem details in PROBLEMS and user
details in USERS.

The final relations are:

### USERS
Stores account information.

Primary key: id
Alternate keys: username, email

### PROBLEMS
Stores programming problem statements and execution limits.

Primary key: id

### TEST_CASES
Stores individual inputs and expected outputs for a problem.

Primary key: id
Alternate key: (problem_id, position)
Foreign key: problem_id → PROBLEMS.id

### ROOMS
Stores players, assigned problem, lifecycle, and result.

Primary key: id
Alternate key: code
Foreign keys:
- problem_id → PROBLEMS.id
- player1_id → USERS.id
- player2_id → USERS.id
- winner_id → USERS.id

### SUBMISSIONS
Stores source code, submission order, processing state, and verdict.

Primary key: id
Alternate key: (room_id, sequence_number)
Foreign keys:
- room_id → ROOMS.id
- user_id → USERS.id

## 7. Main Functional Dependencies

USERS:
id → username, email, password_hash, created_at

PROBLEMS:
id → title, description, input_format, output_format,
     constraints_text, difficulty, time_limit_ms

TEST_CASES:
id → problem_id, input, expected_output, is_sample, position
(problem_id, position) → id, input, expected_output, is_sample

ROOMS:
id → code, problem_id, player1_id, player2_id, status,
     winner_id, started_at, ended_at, next_submission_sequence,
     created_at

SUBMISSIONS:
id → room_id, user_id, sequence_number, source_code, status,
     verdict, submitted_at, judged_at
(room_id, sequence_number) → id, user_id, source_code, status,
                             verdict, submitted_at, judged_at

## 8. Benefits of the Final Design

- User information is stored once.
- Problem information is stored once and reused across rooms.
- Each test case is stored independently.
- Each submission has a clear owner and room.
- Foreign keys prevent references to nonexistent records.
- Unique constraints prevent duplicate accounts and submission order.
- Updating a username does not require changing old room records.
- Deleting a room does not require deleting its users or problem.

The design is in 3NF under the stated functional dependencies.

## 9. Implementation Notes

next_submission_sequence is operational state used to allocate
submission order atomically.

Submission membership, judging order, and winner selection also
require server-side transactional logic. Normalization alone does
not enforce these workflow rules.

Prisma will map these PostgreSQL tables to application models.