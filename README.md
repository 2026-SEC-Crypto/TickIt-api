# TickIt API

TickIt is a backend API designed for a "Secure Physical Attendance & Ticket Validation System." This system integrates time-based constraints, geofencing, and identity verification to effectively prevent fraudulent behaviors such as proxy check-ins and GPS spoofing.

## System Requirements

- Ruby 3.x
- Bundler

## Installation and Setup

1. Install the required dependencies:

```bash
bundle install
```

2. Set up configuration (copy the example secrets file):

```bash
cp config/secrets-example.yml config/secrets.yml
```

Edit `config/secrets.yml` with your database configuration if needed.

3. Set up databases:

```bash
bundle exec rake db:migrate
bundle exec rake db:seed

```

4. Start the API server:

```bash
bundle exec rackup -p 9292
```

The server will be running at `http://localhost:9292`.

## Database Tasks

### Database Folder Layout

This project intentionally uses a split database layout:

- `app/db/migrations/`: Sequel migration files (schema changes)
- `app/db/seeds/`: YAML seed data files used by tests/examples
- `db/local/`: runtime SQLite database files (e.g. `development.db`, `test.db`)

This means `app/db` stores database code/data definitions, while `db/local` stores generated database files.

### Seeding with sequel-seed

This project uses the `sequel-seed` gem for database seeding.

- Put seed scripts in the top-level `seeds/` folder using date-prefixed names, for example:
  - `seeds/20260427_create_all.rb`
- Define seed logic in a `run` method inside a `Sequel.seed(:development)` (or multi-env) block.
- Run seeds with:

```bash
bundle exec rake db:seed
```

### Team setup (quick start)

For collaborators, setup is:

```bash
bundle install
rake db:migrate
rake db:seed
```

View the status of your database:

```bash
# Check development database
RACK_ENV=development bundle exec rake db:status

# Check test database
RACK_ENV=test bundle exec rake db:status
```

## Testing

To run the test suite:

```bash
bundle exec rake spec
```

This will execute all tests including:
- **HAPPY Path Tests:** Verify successful API operations (root route, create, get single, get list)
- **SAD Path Tests:** Verify proper error handling (non-existent resources, invalid JSON)

To run API specs only:

```bash
bundle exec rake api_spec
```

## Security

To check for known vulnerabilities in project dependencies:

```bash
bundle exec rake audit
```

This command will scan all gems in your `Gemfile.lock` and alert you to any known security vulnerabilities. Run this regularly as part of your development workflow.

## Code Quality

To check code style and quality issues using RuboCop:

```bash
bundle exec rake style
```

This will run all tests and audits, then check code style.

## Interactive Console

To run an interactive Pry console with the application loaded:

```bash
bundle exec rake console
```

## Available Rake Tasks

To view all available tasks:

```bash
bundle exec rake -T
```

## API Documentation

Base URL: `http://localhost:9292`

All endpoints return JSON responses with appropriate HTTP status codes.

### 1. Check System Status

**Endpoint:** `GET /`

**Description:** Used to verify if the API server is up and running.

**Response:** `200 OK`
```json
{
  "message": "TickIt API is up and running!"
}
```

### 2. Students

#### 2.1 Get All Students
**Endpoint:** `GET /api/v1/students`

**Response:** `200 OK`
```json
{
  "students": [
    {
      "id": 1,
      "name": "Alice Johnson",
      "email": "alice@example.com",
      "student_number": "STU001",
      "created_at": "2026-04-12T10:30:00Z",
      "updated_at": "2026-04-12T10:30:00Z"
    }
  ]
}
```

#### 2.2 Get Student by ID
**Endpoint:** `GET /api/v1/students/:id`

**Response:** `200 OK`
```json
{
  "student": {
    "id": 1,
    "name": "Alice Johnson",
    "email": "alice@example.com",
    "student_number": "STU001",
    "created_at": "2026-04-12T10:30:00Z",
    "updated_at": "2026-04-12T10:30:00Z"
  }
}
```

**Error:** `404 Not Found`
```json
{
  "error": "Student not found"
}
```

#### 2.3 Create a Student
**Endpoint:** `POST /api/v1/students`

**Request Body:**
```json
{
  "name": "Sarah Lim",
  "email": "sarah@example.com",
  "student_number": "B12121212"
}
```

**Response:** `201 Created`
```json
{
  "message": "Student created",
  "student": {
      "id": 233,
      "name": "Sarah Lim",
      "email": "sarah@example.com",
      "student_number": "B12121212",
      "created_at": "2026-04-12T22:01:35+08:00",
      "updated_at": "2026-04-12T22:01:35+08:00"
  }
}
```

**Error:** `400 Bad Request`
```json
{
  "error": "Missing required fields",
  "missing": ["email"]
}
```

### 3. Events

#### 3.1 Get All Events
**Endpoint:** `GET /api/v1/events`

**Response:** `200 OK`
```json
{
  "events": [
    {
      "id": 1,
      "name": "Web Development Workshop",
      "location": "Room 101",
      "start_time": "2026-04-12T14:00:00Z",
      "end_time": "2026-04-12T15:00:00Z",
      "description": "Introduction to Web Dev",
      "created_at": "2026-04-12T10:30:00Z",
      "updated_at": "2026-04-12T10:30:00Z"
    }
  ]
}
```

#### 3.2 Get Event by ID
**Endpoint:** `GET /api/v1/events/:id`

**Response:** `200 OK`
```json
{
  "event": {
    "id": 1,
    "name": "Web Development Workshop",
    "location": "Room 101",
    "start_time": "2026-04-12T14:00:00Z",
    "end_time": "2026-04-12T15:00:00Z",
    "description": "Introduction to Web Dev",
    "created_at": "2026-04-12T10:30:00Z",
    "updated_at": "2026-04-12T10:30:00Z"
  }
}
```

**Error:** `404 Not Found`
```json
{
  "error": "Event not found"
}
```

#### 3.3 Create an Event
**Endpoint:** `POST /api/v1/events`

**Request Body:**
```json
{
  "name": "Security Seminar",
  "location": "Room 202",
  "start_time": "2026-04-12T16:00:00Z",
  "end_time": "2026-04-12T17:00:00Z",
  "description": "Application Security Basics"
}
```

**Response:** `201 Created`
```json
{
  "message": "Event created",
  "event": {
    "id": 2,
    "name": "Security Seminar",
    "location": "Room 202",
    "start_time": "2026-04-12T16:00:00Z",
    "end_time": "2026-04-12T17:00:00Z",
    "description": "Application Security Basics",
    "created_at": "2026-04-12T10:31:00Z",
    "updated_at": "2026-04-12T10:31:00Z"
  }
}
```

**Error:** `400 Bad Request`
```json
{
  "error": "Invalid start_time or end_time"
}
```

### 4. Attendance Records

#### 4.1 Get All Attendance Record IDs
**Endpoint:** `GET /api/v1/attendances`

**Response:** `200 OK`
```json
{
    "attendance_ids": [
        19,
        20,
        21,
        22
    ]
}
```

#### 4.2 Get Attendance Record by ID
**Endpoint:** `GET /api/v1/attendances/:id`

**Response:** `200 OK`
```json
{
    "id": 20,
    "student_id": "B10902000",
    "status": "present",
    "check_in_time": "2026-04-12T22:08:14+08:00",
    "event_id": 83
}
```

**Error:** `404 Not Found`
```json
{
  "error": "Attendance record not found"
}
```

#### 4.3 Create an Attendance Record (Check-in)
**Endpoint:** `POST /api/v1/attendances`

**Request Body (Minimal):**
```json
{
  "student_id": "B10902000"
}
```

**Request Body (Full):**
```json
{
  "student_id": "B10902000",
  "event_id": 83,
  "status": "present",
  "timestamp": 1712973900
}
```
**Response:** `201 Created`
```json
{
  "message": "Attendance successfully recorded",
  "id": "3ab1443b5e902b66"
}
```

**Error:** `404 Not Found`
```json
{
  "error": "Student not found"
}
```

**Error:** `400 Bad Request`
```json
{
  "error": "No event available; create an event or pass event_id"
}
```

