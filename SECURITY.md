# Security

## Reporting a problem
Please do not open a public issue for a security problem. Email the shop owner
(address on the GitHub profile) with what you found and how to reproduce it.

## What this repository never contains
No shop data, customer data, bills, real backups, real price lists, service-account
keys, keystores, passwords, tokens, or real Firebase configuration. Only synthetic
demo data is committed. Config files are git-ignored; `.example` versions are committed.

## How access is protected
Firestore security rules deny everything except signed-in members of one shop.
See `docs/threat-model.md`.
