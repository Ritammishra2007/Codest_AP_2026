# Codest

> Real-time 1v1 Python competitive programming duel platform.

---

## Overview

**Codest** is a web-based competitive programming platform designed for head-to-head (1v1) coding duels:
- **Real-Time Duels**: Two registered players join a private room via a 6-character room code.
- **Identical Problem**: Both players receive the same Python programming challenge and sample test cases.
- **Fair Queue & Judging**: Submissions are assigned an atomic, sequential order upon arrival. A background worker evaluates them against hidden and sample test cases.
- **First-to-Solve Wins**: The first participant whose submission passes all test cases wins the duel immediately.

---

## Deliverables & Repository Structure

This repository contains the authoritative database design, normalization analysis, production schema, query catalog, and query benchmark suite:

| Deliverable | Description |
|---|---|
| [dbms/01_normalization.md](dbms/01_normalization.md) | Normalization breakdown (UNF → 1NF → 2NF → 3NF), functional dependencies, and architectural limits |
| [dbms/02_er_diagram.png](dbms/02_er_diagram.png) | Entity-Relationship (ER) diagram showing entities, cardinalities, and keys |
| [dbms/03_schema.sql](dbms/03_schema.sql) | Authoritative PostgreSQL schema matching the application Prisma migration |
| [dbms/04_queries.sql](dbms/04_queries.sql) | 35 application queries (Auth, Rooms, Submissions, Worker, Maintenance, Seed) |
| [dbms/05_query_timings.md](dbms/05_query_timings.md) | Benchmark execution timings across three runs and averages for all 35 queries |
| [dbms/plans/](dbms/plans/) | Detailed JSON `EXPLAIN (ANALYZE, BUFFERS)` execution plans (Q01–Q35) |

---

## Database Architecture

- **Engine**: PostgreSQL
- **Normal Form**: Strictly normalized to **Third Normal Form (3NF)**
- **Core Entities**:
  - `users`: Registered player accounts, bcrypt password hashes, and profile timestamps.
  - `problems`: Programming challenge descriptions, I/O formats, constraints, and time limits.
  - `test_cases`: Visible sample test cases and hidden test cases for solution evaluation.
  - `rooms`: Duel lifecycle states (`WAITING`, `ACTIVE`, `FINISHED`), creator, opponent, and winner.
  - `submissions`: User source code, room FIFO queue sequence numbers, execution verdicts, and timestamps.

---

## Database Setup & Inspection

1. **Initialize the Schema**:
   Run in an empty PostgreSQL database:
   ```bash
   psql -d codest_db -f dbms/03_schema.sql
   ```

2. **Inspect Queries**:
   The queries in [dbms/04_queries.sql](dbms/04_queries.sql) are cataloged by operation (READ/WRITE), module, and Query ID (Q01–Q35).

3. **Performance & Query Plans**:
   Refer to [dbms/05_query_timings.md](dbms/05_query_timings.md) for execution timings and [dbms/plans/](dbms/plans/) for raw query execution plans.
