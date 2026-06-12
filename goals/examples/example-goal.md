---
project: homebase
title: Add project archive workflow
priority: high
status: pending
role: feature-builder
issue:
---

# Goal

## Objective

Add a project archive workflow so old projects can be hidden without being
deleted.

## Scope

Allowed:

- project dashboard components
- project list state management
- tests for archive behavior

Forbidden:

- authentication
- billing
- production deployment files
- destructive database migrations

## Validation

Run:

```bash
npm test
npm run build
```

## Stop Conditions

Pause if the implementation requires a destructive migration, credentials, paid
services, or a product decision that is not described here.

## Delivery

Leave a summary with changed files, commands run, results, and remaining risks.

