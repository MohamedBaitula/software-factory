# Goal

## Objective

Describe the exact outcome this run should achieve.

## Context

Explain any background the agent needs before changing code.

## Scope

Allowed areas:

- 

Forbidden areas:

- Secrets and environment files
- Production deployment configuration
- Destructive database migrations
- Unrelated refactors

## Validation

Run these commands before considering the work complete:

```bash
# Example:
npm test
npm run build
```

## Stop Conditions

Pause and ask for human review if:

1. The task requires credentials, secrets, or paid external services.
2. The implementation would require destructive data changes.
3. The product behavior is ambiguous.
4. The validation commands fail and the cause is unclear.
5. The requested change conflicts with existing project rules.

## Delivery

Before stopping, leave a summary with:

1. What changed.
2. Files changed.
3. Validation commands run.
4. Test/build results.
5. Remaining risks or follow-up tasks.

Do not push code automatically.
Do not deploy to production.

