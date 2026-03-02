# First Client Readiness

## Purpose

This document records the legal, operational and real-world work that should be completed before taking on the first paying or pilot client.

This is separate from code delivery because several important requirements are not software tasks.

It assumes the first clients are local venues onboarded manually in a founder-managed service model.

## Minimum standard before first client

The product should not take on its first real client until the following are true.

## Product and architecture

- Multi-tenant data ownership is implemented.
- Tenant-scoped authorisation is implemented and tested.
- Payroll-adjacent records use a correction-safe model rather than destructive overwrite.
- Security-sensitive actions create durable audit records.
- Export generation is attributable and logged.
- Backup and restore have been tested at least once against realistic data.

## Legal and policy documents

- Privacy policy is written and published.
- Customer terms or SaaS agreement exist.
- The contract clearly explains customer and platform responsibilities for data handling, exports, incidents and authorised users.
- Collection notices exist for:
  - employer-supplied worker data
  - worker self-service profile data
  - future export and disclosure paths where relevant
- A subprocessor list exists, including hosting, email and support tooling.
- A retention schedule exists by data class.

## Operational readiness

- There is a named person responsible for privacy and customer complaints handling.
- There is a named person responsible for security incidents.
- A breach response plan exists and can be followed within the timeframes expected under Australian law where applicable.
- Production access is limited to a small approved group.
- Production access approval and review is documented.
- Support access to tenant data requires an explicit workflow and audit trail.

## Security baseline

- Secrets are stored outside source control.
- Production uses HTTPS and secure session configuration.
- High-risk endpoints are rate limited.
- Dependency update and vulnerability review process exists.
- Logs avoid storing passwords, tokens and unnecessary personal data.
- A restore path for backups has been exercised.

## Customer-facing readiness

- Onboarding process is documented.
- Role setup guidance exists for customers.
- Export behavior is documented for customers.
- The product can explain where data is hosted and whether any subprocessors are offshore.
- There is a clear support contact and incident contact path for customers.
- The founder-managed support model is documented so customers understand what the service includes and what remains their responsibility.

## If accountant exports are offered before first client

Then all of the following should also be true:

- Export jobs are logged with actor, scope and timestamp.
- Export files expire and are not exposed through permanent public URLs.
- Export schemas are versioned.
- Customer documentation explains that the customer is responsible for choosing authorised recipients.
- Contracts and notices explain that payroll-adjacent data may be disclosed to authorised payroll staff, bookkeepers or accountants.

## Recommended "good enough for first client" package

At a practical minimum, have these artifacts ready:

1. Privacy policy.
2. Customer terms.
3. Incident and breach response playbook.
4. Subprocessor inventory.
5. Retention schedule.
6. Internal production access policy.
7. Customer onboarding checklist.
8. Export policy if any export feature is enabled.

## Things that are easy to overlook

- Whether third-party scripts on authenticated pages create offshore disclosure issues.
- Whether backups and logs hold the same personal information as the primary database.
- Whether support staff can see more customer data than they need.
- Whether free-text fields will end up holding sensitive data in practice.
- Whether the product can explain and evidence corrections to timesheets after payroll-related use.

## Rule of thumb

Before first client, you should be able to answer these questions quickly and concretely:

- Where is customer data stored?
- Who can access it?
- How is tenant separation enforced?
- How are timesheet mistakes corrected without destroying history?
- What happens if there is a breach?
- What happens when the customer exports data to their accountant?
- What data is shared with third parties?
- How long is data kept?
