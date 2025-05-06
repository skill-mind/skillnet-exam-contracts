# Skill-mind Education Platform Indexer

This project implements an Apibara indexer for a Skill-mind-based education
platform, capturing all relevant events and storing them in a PostgreSQL
database. It also includes a REST API to query the indexed data.

## Features

- Indexes events from a Skill-mind education platform contract:
  - Exam creation
  - Question additions
  - Student enrollments
  - Exam status changes
  - Certificate claims
  - Token transfers
- Stores all events in a PostgreSQL database
- Provides a REST API to query the indexed data

## Setup

### Prerequisites

- [Deno](https://deno.land/) runtime installed
- PostgreSQL database
- Access to a Skill-mind node

### Configuration

Set the following environment variables:

```bash
# Database connection string
export DB_CONNECTION_STRING="postgres://postgres:password@localhost:5432/postgres"

# Apibara stream URL
export STREAM_URL="https://your-apibara-node.com"

# Starting block for indexing
export STARTING_BLOCK=1000000

# Port for API server (optional, default: 8080)
export PORT=8080
```

Update the `constants.ts` file with your contract addresses and other
configuration.

### Starting the Indexer and API Server

Use the provided start script:

```bash
chmod +x start.sh
./start.sh
```

Or start them separately:

```bash
# Start the indexer
deno run --allow-net --allow-env --allow-read index.ts

# Start the API server
deno run --allow-net --allow-env --allow-read api.ts
```

## API Endpoints

### General

- `GET /health` - Health check
- `GET /stats` - Get overall statistics

### Exams

- `GET /exams` - List all exams
  - Query parameters:
    - `limit` (optional) - Number of results (default: 100)
    - `offset` (optional) - Pagination offset (default: 0)
    - `creator` (optional) - Filter by creator address
- `GET /exams/:examId` - Get exam details with questions and enrollments

### Questions

- `GET /questions/:examId` - Get all questions for an exam

### Enrollments

- `GET /enrollments/exam/:examId` - Get all enrollments for an exam
- `GET /enrollments/student/:student` - Get all enrollments for a student

### Certificates

- `GET /certificates/:student` - Get all certificates for a student

### Transactions

- `GET /transactions/address/:address` - Get all transactions for an address
  - Query parameters:
    - `limit` (optional) - Number of results (default: 100)
    - `offset` (optional) - Pagination offset (default: 0)
- `GET /transactions/token/:token` - Get all transactions for a token
  - Query parameters:
    - `limit` (optional) - Number of results (default: 100)
    - `offset` (optional) - Pagination offset (default: 0)

## Project Structure

- `constants.ts` - Configuration constants
- `index.ts` - Main indexer logic
- `db.ts` - Database client and queries
- `api.ts` - REST API server
- `deps.ts` - Dependencies
- `start.sh` - Script to start both indexer and API

## License

MIT
