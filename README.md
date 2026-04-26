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
- `seeds/`: `sequel-seed` seed scripts using dated filenames such as `20260427_create_all.rb`
- `db/local/`: runtime SQLite database files (e.g. `development.db`, `test.db`)

This means `app/db` stores database code/data definitions, `seeds/` stores runnable seed scripts, and `db/local` stores generated database files.

### Seeding with sequel-seed

This project uses the `sequel-seed` gem for database seeding.

- Put seed scripts in the top-level `seeds/` folder using date-prefixed names, for example:
  - `seeds/20260427_create_all.rb`
- Define seed logic in a `run` method inside a `Sequel.seed(:development, :test)` (or multi-env) block.
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

If a clean local reset is needed first, run:

```bash
rake db:drop
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
- **HAPPY Path Tests:** Verify successful API operations for events, attendances, accounts, and student event/course lookups
- **SAD Path Tests:** Verify proper error handling for non-existent resources, invalid JSON, and mass-assignment attempts

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

The API does not expose full student CRUD at the moment. Instead, it exposes student-attendance derived views.

#### 2.1 Get Events for a Student
**Endpoint:** `GET /api/v1/students/:student_id/events`

**Response:** `200 OK`
```json
{
  "student_id": "STU001",
  "events": [
    {
      "id": "event-uuid",
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

#### 2.2 Get Courses for a Student
**Endpoint:** `GET /api/v1/students/:student_id/courses`

**Response:** `200 OK`
```json
{
  "student_id": "STU001",
  "courses": [
    {
      "id": "event-uuid",
      "name": "Database Design Course",
      "location": "Room 303",
      "start_time": "2026-04-12T14:00:00Z",
      "end_time": "2026-04-12T15:00:00Z",
      "description": "Relational Database Concepts",
      "created_at": "2026-04-12T10:30:00Z",
      "updated_at": "2026-04-12T10:30:00Z"
    }
  ]
}
```

### 3. Accounts

#### 3.1 Create an Account
**Endpoint:** `POST /api/v1/accounts`

**Request Body:**
```json
{
  "email": "new_user@example.com",
  "password": "super_secure_password_123",
  "role": "member"
}
```

**Response:** `201 Created`
```json
{
  "message": "Account created successfully",
  "account": {
    "id": "account-uuid",
    "email": "new_user@example.com",
    "role": "member"
  }
}
```

#### 3.2 Get an Account by ID
**Endpoint:** `GET /api/v1/accounts/:id`

**Response:** `200 OK`
```json
{
  "account": {
    "id": "account-uuid",
    "email": "search_me@example.com",
    "role": "member"
  }
}
```

**Error:** `404 Not Found`
```json
{
  "error": "Account not found"
}
```

### 4. Events

#### 4.1 Get All Events
**Endpoint:** `GET /api/v1/events`

**Response:** `200 OK`
```json
{
  "events": []
}
```

#### 4.2 Get Event by ID
**Endpoint:** `GET /api/v1/events/:id`

**Response:** `200 OK`
```json
{
  "event": {
    "id": "event-uuid",
    "name": "Web Development Workshop",
    "location": "Room 101",
    "start_time": "2026-04-12T14:00:00Z",
    "end_time": "2026-04-12T15:00:00Z",
    "description": "Introduction to Web Dev"
  }
}
```

**Error:** `404 Not Found`
```json
{
  "error": "Event not found"
}
```

#### 4.3 Create an Event
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
    "id": "event-uuid",
    "name": "Security Seminar",
    "location": "Room 202",
    "start_time": "2026-04-12T16:00:00Z",
    "end_time": "2026-04-12T17:00:00Z",
    "description": "Application Security Basics"
  }
}
```

**Error:** `400 Bad Request`
```json
{
  "error": "Missing required fields",
  "missing": ["start_time", "end_time"]
}
```

### 5. Attendance Records

#### 5.1 Get All Attendance Record IDs
**Endpoint:** `GET /api/v1/attendances`

**Response:** `200 OK`
```json
{
  "attendance_ids": [
    "attendance-uuid"
  ]
}
```

#### 5.2 Get Attendance Record by ID
**Endpoint:** `GET /api/v1/attendances/:id`

**Response:** `200 OK`
```json
{
  "id": "attendance-uuid",
  "student_id": "B10902000",
  "status": "present",
  "check_in_time": "2026-04-12T22:08:14+08:00",
  "event_id": "event-uuid"
}
```

**Error:** `404 Not Found`
```json
{
  "error": "Attendance record not found"
}
```

#### 5.3 Create an Attendance Record
**Endpoint:** `POST /api/v1/attendances`

**Request Body:**
```json
{
  "student_id": "STU001",
  "event_id": "event-uuid"
}
```

**Response:** `201 Created`
```json
{
  "message": "Attendance successfully recorded",
  "id": "attendance-uuid"
}
```

**Error:** `400 Bad Request`
```json
{
  "error": "Illegal mass assignment detected"
}
```

**Error:** `400 Bad Request`
```json
{
  "error": "Invalid JSON format"
}
```

**Error:** `404 Not Found`
```json
{
  "error": "No event available; create an event or pass event_id"
}
```




