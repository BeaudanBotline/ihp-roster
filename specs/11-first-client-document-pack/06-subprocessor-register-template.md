# Subprocessor Register Template

## Purpose

Maintain a current list of third parties that handle or may access customer data.

## Template

| Vendor | Purpose | Data categories | Region / country | Customer-facing? | Contract owner | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| `[hosting provider]` | Hosting | All service data | `[region]` | No | `[name]` | `[notes]` |
| `[email provider]` | Transactional email | Account/contact data | `[region]` | Yes | `[name]` | `[notes]` |
| `[logging provider]` | Logs / monitoring | Technical logs, limited metadata | `[region]` | No | `[name]` | `[notes]` |
| `[support tool]` | Support | Support interactions | `[region]` | Yes | `[name]` | `[notes]` |

## Review rules

- Update when adding, changing or removing a service provider.
- Review before onboarding each new paying customer.
- Check whether any provider involves offshore handling or disclosure.
