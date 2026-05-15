# AGENTS.md

This project may be worked on by AI coding agents. Follow these rules unless the user gives more specific instructions.

## Working Rules

1. Read the goal file before making changes.
2. Keep changes scoped to the requested task.
3. Prefer existing project patterns over new abstractions.
4. Do not modify secrets, credentials, or production deployment settings.
5. Do not run destructive commands.
6. Do not push code automatically.
7. Do not deploy to production.
8. Stop and ask for human review when product behavior is ambiguous.

## Git Rules

1. Work on a dedicated branch.
2. Do not overwrite uncommitted human changes.
3. Use clear commit messages.
4. Commit only after validation passes, unless the user asks otherwise.

## Validation

Before considering work complete, run the commands listed in the goal file.

If validation fails:

1. Try to identify and fix the cause.
2. Do not delete or skip tests just to pass validation.
3. Leave a clear explanation if the issue cannot be resolved.

## Delivery Summary

End every run with:

1. Summary of changes.
2. Files changed.
3. Commands run.
4. Results.
5. Remaining risks or follow-ups.

