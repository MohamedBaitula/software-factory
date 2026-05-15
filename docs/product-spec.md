# Software Factory Product Spec

## Vision

Software Factory is a local AI development orchestration system for running safe, reviewable Codex goal sessions across multiple repositories.

The goal is to turn AI coding from one-off prompting into a repeatable development workflow: define clear goals, launch isolated work sessions, validate changes, and review results in the morning.

## Target User

The first target user is a student/developer managing several personal projects who wants to make steady progress across them without manually supervising every step.

## MVP

The MVP should support:

1. Registering multiple local projects in a config file.
2. Checking the local environment before any run starts.
3. Verifying that each project has a clean Git working tree.
4. Creating a safe branch for each run.
5. Launching one tmux window per project.
6. Starting Codex CLI in each project with a structured goal prompt.
7. Running or recording each project's validation commands.
8. Producing a morning report with status, changed files, tests run, and next steps.

## Non-Goals

The MVP will not:

1. Push code automatically.
2. Deploy to production.
3. Modify secrets or environment files.
4. Run destructive database migrations without human approval.
5. Replace human review.
6. Provide a web dashboard.

## Safety Rules

Every automated run should follow these rules:

1. Work on a dedicated branch.
2. Stop if the project has uncommitted changes before starting.
3. Avoid destructive commands unless explicitly approved.
4. Do not push or deploy automatically.
5. Pause when product decisions are ambiguous.
6. Leave a clear summary of what changed and what still needs review.

## Success Criteria

The MVP is successful when one command can start a safe overnight run for at least two projects and produce enough information for a human to review the results the next morning.

## Future Ideas

Possible future additions:

1. A small dashboard for project status.
2. GitHub Issues integration for work queues.
3. Pull request creation after successful validation.
4. Scheduled runs.
5. Per-project agent instructions.
6. Metrics for success rate, test pass rate, and time saved.

