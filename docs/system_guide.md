# TickIt Attendance System — User Guide

## Table of Contents

1. [System Overview](#system-overview)
2. [Accounts & Roles](#accounts--roles)
3. [Account Features](#account-features)
4. [Event Management (Teacher / Admin)](#event-management)
5. [Dynamic Attendance System](#dynamic-attendance-system)
6. [Teacher Application Flow](#teacher-application-flow)
7. [API Key Usage](#api-key-usage)
8. [Role Permission Summary](#role-permission-summary)
9. [For Collaborators: Upgrading Roles via Terminal](#for-collaborators-upgrading-roles-via-terminal)

---

## System Overview

TickIt is a QR code-based attendance tracking system that supports dynamic anti-cheat QR codes, role-based access control, and a teacher application review workflow. The system consists of two applications: an API backend (`tickit-2026-api`) and a web frontend (`tickit-2026`).

---

## Accounts & Roles

### Role Definitions

| Role | Description |
|---|---|
| `regular` (Default) | Default role. Can view events, scan QR codes to check in, and apply to become a teacher. |
| `teacher` | Includes all regular permissions. Can additionally create events, start attendance sessions, and view attendee lists. |
| `admin` | Includes all teacher permissions. Can additionally review teacher applications, and manage all events and accounts. |

### Creating an Account

#### Option 1: Email Registration

1. Go to `/register` and enter your username and email address
2. A verification email will be sent — click the link inside
3. Set your password to complete registration
4. Go to `/login` to sign in

#### Option 2: Google SSO

1. Go to `/login` and click the Google sign-in button
2. Select and authorise your Google account
3. The system will automatically create or link your account and log you in

---

## Account Features

### Account Overview Page `/account`

After logging in, your account page displays:

- **Account Info**: username, email, and current role
- **API Key**: a read-only token for calling the API from the command line
- **My Events**: list of events you created or attended
- **Action Buttons**: options vary depending on your role

---

## Event Management

> Requires `teacher` or `admin` role

### Creating an Event

1. Go to `/events/new` (or click "Create Event" on your account page)
2. Fill in the required fields:

| Field | Description |
|---|---|
| Event Name | Name of the event |
| Location | Venue or location |
| Start / End Time | Event start and end time |
| Attendance Start / End | Check-in window (must fall within the event time range) |
| Description | Optional description |
| Repeat Weeks | Number of weeks to repeat (if ≥ 2, multiple events are created in batch) |

3. Submit to create the event and return to the event list

### Editing an Event

- Click "Edit Event" on the event detail page
- Some fields (e.g. Start Time) are locked after the event has started
- For recurring series, use "Edit Entire Series" to apply changes to all events at once

### Deleting an Event

- Click "Delete Event" on the event detail page
- Deleting an event automatically removes all associated attendance records and collaborator links
- For recurring series, use "Delete Entire Series" to remove all events at once

### Viewing the Attendee List

- Only the event creator (collaborator) and admins can view the attendee list
- The list shows: username, email, and check-in time (Taiwan timezone format)

---

## Dynamic Attendance System

### Teacher Workflow

1. Go to the event detail page (`/events/:id`)
2. If the event has an Attendance Window configured and you have edit permission, a green **Start Attendance** button will appear
3. Click it to open the attendance page (`/events/:id/attendance`)
4. A QR code is generated automatically, with a countdown timer (refreshes every 25 seconds)
5. Display the QR code on screen for students to scan
6. The QR code refreshes automatically every 25 seconds (each token is valid for 30 seconds)

> **Note:**
> - The Start Attendance button only appears when the current time is within the Attendance Window
> - Remind students: **Please log in before scanning the QR code**

### Student Workflow

1. Use your phone camera to scan the QR code
2. **If not logged in**: you will be redirected to the login page; after logging in, you will be automatically returned to the check-in page
3. Once logged in, the page displays "Verifying your attendance..."
4. The system automatically submits your check-in to the API
5. The result is displayed:

| Result | Message Shown |
|---|---|
| ✅ Success | "Checked in successfully!" + event name + check-in time |
| ❌ Token expired | "Attendance token has expired" |
| ❌ Outside time window | "Outside the event attendance window" |
| ❌ Already checked in | "You have already checked in to this event" |

### Anti-Cheat Mechanisms

- **Dynamic Token**: each token expires after 30 seconds, preventing screenshot replay attacks
- **Time Window Validation**: check-ins are only accepted within the configured Attendance Window

---

## Teacher Application Flow

### Applying (Regular Users)

1. Go to your account page and click "Apply to Become a Teacher"
2. Fill in the application form:

| Field | Required |
|---|---|
| Full Name | ✅ |
| Organization / Department | ✅ |
| School / Institutional Email | ✅ |
| Additional Notes | Optional |

3. After submitting, you will see: "Application submitted! An admin will review your request."
4. You will receive a **one-time on-page notification** when the application is decided

### Admin Review Workflow

1. Go to your account page and click "Review Applications" (`/admin/applications`)
2. View pending applications — each entry shows: username, email, full name, organization, school email, notes, and application time
3. Actions:
   - **Approve**: approves the application and automatically upgrades the user's role to `teacher`
   - **Reject**: rejects the application; an optional rejection reason can be entered by expanding the input field

4. The applicant receives a notification:
   - Approved: "Your teacher application has been approved! Please log out and log back in to activate your new role."
   - Rejected: "Your teacher application was not approved." (with rejection reason, if provided)

> **Note**: After approval, the applicant must log out and log back in for the new `teacher` role to take effect.

---

## API Key Usage

### What Is an API Key

An API Key is a **read-only** token that allows you to call the API directly from the command line or in code, without going through the full login flow.

### Getting Your API Key

**Option 1**: Go to your account page (`/account`) — your API Key is displayed automatically.

**Option 2**: Request one via the API:
```bash
curl -X POST https://tickit-2026-api-e230b38834a2.herokuapp.com/api/v1/auth/api_key \
  -H "Authorization: Bearer YOUR_SESSION_TOKEN"
```

### Usage Examples

```bash
# Get all events
curl https://tickit-2026-api-e230b38834a2.herokuapp.com/api/v1/events \
  -H "Authorization: Bearer YOUR_API_KEY"

# Get only your own events
curl "https://tickit-2026-api-e230b38834a2.herokuapp.com/api/v1/events?mine=true" \
  -H "Authorization: Bearer YOUR_API_KEY"
```

> **Limitation**: API Keys are read-only. Attempting to create, update, or delete resources will return `403 Forbidden`.

---

## Role Permission Summary

| Feature | Regular | Teacher | Admin |
|---|:---:|:---:|:---:|
| Register / Login | ✅ | ✅ | ✅ |
| Google SSO Login | ✅ | ✅ | ✅ |
| View event list | ✅ | ✅ | ✅ |
| Scan QR code to check in | ✅ | ✅ | ✅ |
| Apply to become a teacher | ✅ | — | — |
| Get API Key (read-only) | ✅ | ✅ | ✅ |
| Create events (single / recurring) | — | ✅ | ✅ |
| Edit / Delete own events | — | ✅ | ✅ |
| Edit / Delete any event | — | — | ✅ |
| Start attendance (QR code) | — | ✅ | ✅ |
| View attendee list | — | ✅ (own events) | ✅ |
| Review teacher applications | — | — | ✅ |
| View all accounts | — | — | ✅ |

---

## For Collaborators: Upgrading Roles via Terminal

If you are a development collaborator on this project, you can directly upgrade an account's role in the production database using the Heroku CLI, without going through the application review flow.

### Prerequisites

- [Heroku CLI](https://devcenter.heroku.com/articles/heroku-cli) installed
- Added to the project's Heroku team with `heroku run` access

### Command

Replace `YOUR_EMAIL` with the account's email address and `ROLE` with the target role (`teacher` or `admin`):

```bash
heroku run --app tickit-2026-api "bundle exec ruby -e \"
require_relative 'config/environments'
require_relative 'app/models/account'
require_relative 'app/lib/secure_db'
require 'digest'

email_hash = Digest::SHA256.hexdigest('YOUR_EMAIL')
account = TickIt::Account.first(email_hash: email_hash)

if account
  account.update(role: 'ROLE')
  puts \\\"Updated: #{account.username} => role=#{account.role}\\\"
else
  puts 'Account not found'
end
\""
```

### Example

Upgrade `alice@example.com` to `teacher`:

```bash
heroku run --app tickit-2026-api "bundle exec ruby -e \"
require_relative 'config/environments'
require_relative 'app/models/account'
require_relative 'app/lib/secure_db'
require 'digest'

email_hash = Digest::SHA256.hexdigest('alice@example.com')
account = TickIt::Account.first(email_hash: email_hash)
account.update(role: 'teacher')
puts \\\"Updated: #{account.username} => role=#{account.role}\\\"
\""
```

> **Note**: After the role is updated, the user must log out and log back in for the change to take effect in their session.
