# TickIt API

TickIt is a backend API designed for a "Secure Physical Attendance & Ticket Validation System." 
This system integrates time-based constraints, geofencing, and identity verification to effectively prevent fraudulent behaviors such as proxy check-ins and GPS spoofing.

## System Requirements

- Ruby 3.x
- Bundler

## Installation and Setup

1. Install the required dependencies:
```bash
   bundle install
```
2. Start the API server:
```bash
bundle exec rackup -p 9292
```
The server will be running at http://localhost:9292.

## API Documentation
1. Check System Status
Endpoint: GET /

Description: Used to verify if the API server is up and running.

2. Create an Attendance Record (Check-in)
Endpoint: POST /api/v1/attendances

Description: Receives a check-in request from the student client (requires student ID and GPS coordinates).

Example Request Payload (JSON):

```JSON
{
  "student_id": "B10902000",
  "location": { "lat": 24.123, "lng": 121.456 }
}```
3. Get All Record IDs
Endpoint: GET /api/v1/attendances

Description: Returns a list of all attendance record IDs currently stored in the system.

4. Get Record Details
Endpoint: GET /api/v1/attendances/[id].json

Description: Retrieves the detailed information of a specific attendance record using its unique ID.