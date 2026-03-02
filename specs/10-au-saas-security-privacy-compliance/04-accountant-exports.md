# Accountant Exports

## Short answer

Yes, accountant exports change the design requirements, but not the core direction.

They do not reduce the need for strong privacy and security controls. They increase the importance of:

- disclosure governance
- auditability
- integrity of payroll-adjacent records
- customer contract clarity
- export scoping and retention

## What does not change

The product should still be built as:

- a multi-tenant SaaS platform
- an APP-aligned system
- a correction-safe record system
- a system with formal export and disclosure controls

An export feature is not a shortcut around privacy, security or record-keeping design.

## What does change

### Exports become a formal disclosure path

When the platform generates a file for an employer to provide to their accountant, the product is supporting a disclosure workflow.

That means the platform should be able to answer:

- who initiated the export
- for which tenant
- for what purpose
- what data fields were included
- where the file was delivered
- how long it remained accessible

### Record integrity matters more

If exported data is used for accounting, BAS, payroll processing or wage reconciliation, the customer will rely on it as a business record.

The platform should therefore provide:

- immutable or versioned export snapshots
- clear correction history
- export manifests
- timestamps and actor attribution

### Role design becomes more important

An accountant is not the same as a manager.

If direct accountant access is later supported, it should be a dedicated role with narrow capabilities such as:

- export access
- read-only payroll-adjacent views
- no roster editing
- no worker role administration
- no support access

## Recommended product approach

### Preferred v1 approach

Use employer-mediated exports first.

Pattern:

1. An authorised tenant user requests an export.
2. The platform generates a fixed snapshot.
3. The platform logs the export.
4. The employer downloads the file and sends it to the accountant outside the platform, or through a controlled platform sharing flow later.

Benefits:

- simpler permissions
- lower support burden
- cleaner product boundary
- easier to explain legally and contractually
- better fit for a founder-managed local service model

### Defer direct accountant accounts until later

Direct accountant access is feasible, but should come after:

- tenant model
- export audit model
- role model
- legal terms and privacy documents
- support process

Otherwise the product will blur employer, accountant and platform responsibilities too early.

## Legal and governance implications

### Fair Work implications

Fair Work recognises that authorised individuals such as an accountant can access records.

However:

- the employer still retains record-keeping obligations
- the records still need integrity and retention
- the platform should not make records easier to falsify or lose

### Privacy implications

For covered entities, exports should be supported by the collection and disclosure framework:

- the disclosure should fit the primary purpose or another permitted basis
- workers should not be surprised that payroll-adjacent data may be shared with payroll staff, bookkeepers or accountants
- notices and contracts should describe these handling paths

### Cross-border implications

Accountant-related workflows can create cross-border issues if:

- the accountant is overseas
- the accountant uses overseas systems
- the export is emailed or stored through offshore services
- the platform directly shares data through offshore subprocessors

This is one reason to prefer an Australian-default product stack and a clear export policy.

## Required architectural controls for exports

### Export job model

Implement export jobs rather than ad hoc controller actions.

Each export job should store:

- tenant id
- requestor id
- export type
- schema version
- data range and filters
- generated file id
- created timestamp
- expiry timestamp
- delivery method
- destination metadata

### Export file handling

Recommended:

- short-lived signed download URLs
- encrypted object storage
- no permanent public URLs
- checksum or manifest
- schema version included in the package

Avoid:

- raw files attached to emails by default
- untracked CSV generation endpoints
- silent overwriting of a previous export

### Export scope controls

Every export should be intentionally scoped.

Examples:

- single pay period
- named workers
- single location or department
- approved timesheets only

Do not default to "all records for all time".

### Export audit and review

At minimum, log:

- request
- generation
- download
- resend
- expiry
- deletion

## Customer contract and policy implications

The product should eventually state clearly:

- whether the customer is responsible for choosing authorised recipients
- whether the platform acts only on customer instructions for exports
- what security controls apply to export delivery
- what happens after the recipient receives the file
- what logs the platform retains

## Recommendation

Build accountant support in two stages.

Stage 1:

- employer-triggered exports
- immutable snapshots
- full audit logging
- no direct accountant login

Stage 2:

- optional accountant role
- invitation-based access
- narrow permissions
- explicit customer controls
- stronger contractual and privacy documentation

## Sources

- Fair Work record-keeping: https://www.fairwork.gov.au/pay-and-wages/paying-wages/record-keeping
- Fair Work workplace privacy guide: https://www.fairwork.gov.au/tools-and-resources/best-practice-guides/workplace-privacy
- OAIC APP 5: https://www.oaic.gov.au/privacy/australian-privacy-principles/australian-privacy-principles-guidelines/chapter-5-app-5-notification-of-the-collection-of-personal-information
- OAIC APP 6: https://www.oaic.gov.au/privacy/australian-privacy-principles/australian-privacy-principles-guidelines/chapter-6-app-6-use-or-disclosure-of-personal-information
- OAIC APP 8: https://www.oaic.gov.au/privacy/australian-privacy-principles/australian-privacy-principles-guidelines/chapter-8-app-8-cross-border-disclosure-of-personal-information
