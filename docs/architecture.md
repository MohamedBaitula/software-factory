# Architecture

Software Factory is a local orchestration layer around Git, tmux, and Codex CLI.

## Core Pieces

## Config

`factory.config.yaml` defines the projects that can be run by the factory.

Each project includes:

- project name
- enabled/disabled status
- local path
- goal file
- branch prefix
- validation commands
- stop conditions

Config parsing lives in `scripts/lib/config.sh` so every script reads project entries the same way.

## Templates

Templates provide reusable instructions for projects and runs:

- `templates/GOAL.md` defines the structure of a scoped task.
- `templates/AGENTS.md` defines general AI agent working rules.
- `templates/MORNING_REPORT.md` defines the review format after a run.

## Scripts

The MVP scripts will be:

- `scripts/doctor.sh`: checks required tools and project readiness.
- `scripts/run-project.sh`: starts one project run.
- `scripts/run-night.sh`: starts multiple project runs in tmux.
- `scripts/summarize.sh`: generates a morning report.

## Runtime Flow

1. User writes or updates project goals.
2. User runs the environment doctor.
3. Factory checks configured projects.
4. Factory creates safe branches.
5. Factory starts tmux windows.
6. Codex runs inside each project.
7. Validation commands are run or recorded.
8. Morning report is generated for review.

## Safety Model

The factory is designed to keep human review in control.

- Work happens on branches.
- Dirty working trees block automated runs.
- Local config is ignored by Git.
- Logs and reports are generated locally.
- Pushing and deployment are not automatic in the MVP.
