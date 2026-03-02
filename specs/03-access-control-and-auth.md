# Access Control and Authentication

## Roles

- **Staff**
  - View own profile.
  - Browse all roster weeks.
  - View published roster content only.
  - When a viewed week is not published, see a message that it is not published yet.
  - Submit/edit allowed timesheet entries.
  - Submit leave requests.
- **Manager**
  - All staff permissions.
  - Manage roster planning.
  - Publish roster.
  - Approve/unapprove timesheets.
  - Manage active linked staff from the roster workflow (except restricted admin-only account operations).
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
- Trial staff do not appear in the manager/admin roster-side staff list.
