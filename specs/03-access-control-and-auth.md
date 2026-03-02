# Access Control and Authentication

## Roles

- **Staff**
  - View own profile.
  - View published roster only.
  - Submit/edit allowed timesheet entries.
  - Submit leave requests.
- **Manager**
  - All staff permissions.
  - Manage roster planning.
  - Publish roster.
  - Approve/unapprove timesheets.
  - Manage staff records (except restricted admin-only account operations).
- **Admin**
  - All manager permissions.
  - System-wide configuration management.
  - Full role/account governance.

## Bootstrap admin rule

- First registered login user in a fresh deployment is automatically assigned `admin`.

## Mandatory profile gate

Before profile completion, user is authenticated but not operationally active:

- blocked from primary app actions,
- redirected to complete required profile fields.

Required fields are defined in onboarding spec and enforced server-side.

## Trial staff behavior

- Trial staff are non-login placeholders for quick roster assignment.
- They never access app flows directly.
- No v1 conversion path from trial record to full login user.
