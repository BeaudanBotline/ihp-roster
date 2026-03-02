# Retention Schedule Draft

## Status

Operational draft. Tailor to actual product behavior and legal advice.

## Retention principles

- Keep records only as long as reasonably necessary unless a longer legal retention period applies.
- Do not treat payroll-adjacent records as disposable CRUD data.
- Prefer archive or correction history over destructive deletion for business-use employment records.

## Draft schedule

| Data class | Example records | Draft retention position | Notes |
| --- | --- | --- | --- |
| Account and venue records | users, venue admins, venue metadata | Retain while service is active and for a reasonable post-termination period | Needed for support, billing and audit |
| Worker operational records | staff profiles, roster assignments | Retain while service is active; archive on termination according to offboarding policy | Check overlap with employment record needs |
| Payroll-adjacent records | timesheets, approvals, export snapshots | Retain for at least the period needed to support customer legal record-keeping obligations | Fair Work time and wages records are generally 7 years |
| Leave and availability records | leave requests, availability | Retain while operationally relevant and as needed for record integrity | May need longer retention where linked to payroll or disputes |
| Audit logs | approvals, role changes, exports, support access | Retain long enough to support investigations, disputes and security reviews | Should not be too short |
| Backups | database backups | Rolling retention with documented backup window | Must align with offboarding and restore policy |
| Support records | emails, tickets, troubleshooting notes | Retain for a reasonable support and dispute period | Avoid unnecessary personal data in notes |

## Source

- Fair Work record-keeping: https://www.fairwork.gov.au/pay-and-wages/paying-wages/record-keeping
