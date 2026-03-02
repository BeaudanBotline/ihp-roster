# Australian SaaS Security, Privacy and Compliance

## Purpose

This spec set defines the minimum architectural and governance direction required to turn this project into a local, high-touch, multi-venue SaaS product for small Australian hospitality businesses.

It is written from the assumption that the product will handle:

- employee identity and contact data
- roster data
- leave data
- availability data
- timesheets and payroll-adjacent records
- exports used by employers, bookkeepers and accountants

This is a product and architecture guide, not legal advice. It is intended to reduce the risk of building the wrong foundations before legal review.

## Why this matters now

The current codebase already behaves like an employment records system. The product is still early, which means the highest-value work is not feature breadth. It is getting the data boundaries, tenancy model, auditability, retention model, access control model and export model right before more personal information is added.

The most expensive mistakes to fix later are:

1. Building as if this were a single-company internal tool instead of a SaaS platform.
2. Treating employment records like ordinary mutable CRUD rows.
3. Allowing sensitive information to leak into generic free-text fields.
4. Adding richer profile data before a privacy notice, retention model and access model exist.
5. Relying on customer assumptions about small business exemptions instead of designing to the APP standard.
6. Letting third-party access and accountant exports evolve ad hoc.
7. Confusing a founder-managed local service model with an excuse to skip SaaS-grade venue and record boundaries.

## Current project gap summary

The current repository is missing or under-specified in the following areas:

- no venue model or venue-scoped data ownership model
- no immutable audit/event history for timesheet, leave or role changes
- no retention and archival model for employment records
- no structured privacy governance layer
- no formal subprocessor or cross-border data handling position
- no subject access / correction workflow
- no breach response playbook
- no structured data classification model
- no strict boundary between ordinary profile data and future sensitive data
- no architected accountant/export model

## Strategic policy

This project should be designed as if it will be regulated and scrutinised, even where a particular customer may currently fall within a small business exemption.

Reasons:

- the platform operator may itself be regulated under the Privacy Act
- the employee records exemption does not protect a SaaS vendor acting for employers
- some customers will be covered entities even if others are not
- the product will be materially harder to re-architect once real customer data exists
- customer due diligence will expect a privacy and security posture well above the legal minimum

## Operating model

The intended near-term model is:

- local venues only
- low venue count
- founder-managed onboarding and support
- standardised product, not bespoke one-off deployments
- no public self-serve venue creation

This is best understood as a managed SaaS service, not an internal staff tool and not a broad self-serve SaaS launch.

## Document map

- `01-regulatory-baseline.md`
- `02-target-architecture.md`
- `03-roadmap-and-priorities.md`
- `04-accountant-exports.md`
- `05-first-client-readiness.md`
- `06-engineering-backlog.md`

## Operating assumptions

1. The product will become multi-venue.
2. The product will eventually store more detailed worker profile information.
3. The product may later support payroll, accountant exports, award interpretation and decision support.
4. The product should prefer Australian hosting and Australian-default subprocessors unless there is a strong reason not to.
5. Privacy-by-design, least privilege and record integrity are first-order product requirements, not later hardening tasks.
6. For the first few venues, manual operations are acceptable; weak data boundaries are not.
