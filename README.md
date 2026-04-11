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
# Create and migrate development database
RACK_ENV=development bundle exec rake db:migrate

# Create and migrate test database
RACK_ENV=test bundle exec rake db:migrate

```

4. Start the API server:

```bash
bundle exec rackup -p 9292
```

The server will be running at `http://localhost:9292`.

## Database Tasks

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

### 1. Check System Status

**Endpoint:** `GET /`

**Description:** Used to verify if the API server is up and running.

### 2. Create an Attendance Record (Check-in)

**Endpoint:** `POST /api/v1/attendances`

**Description:** Receives a check-in request from the student client (requires student ID and GPS coordinates).

**Example Request Payload:**

```json
{
  "student_id": "B10902000",
  "location": { "lat": 24.123, "lng": 121.456 }
}
```

### 3. Get All Record IDs

**Endpoint:** `GET /api/v1/attendances`

**Description:** Returns a list of all attendance record IDs currently stored in the system.

### 4. Get Record Details

**Endpoint:** `GET /api/v1/attendances/[id]`

**Description:** Retrieves the detailed information of a specific attendance record using its unique ID.