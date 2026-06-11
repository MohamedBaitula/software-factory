# Software Factory

Software Factory is a local AI development orchestrator for running safe,
reviewable Codex sessions across multiple repositories.

It is built for a simple workflow: write clear goals before bed, launch isolated
Codex sessions in tmux, and review branches, logs, validation output, and
reports in the morning.

## What It Does

- Registers local projects in `factory.config.yaml`.
- Checks WSL, Git, tmux, Codex, Node, npm, config, project paths, and clean Git state.
- Runs one project or many enabled projects in tmux.
- Supports a private local goal queue under `goals/`.
- Records run IDs and per-project status under `logs/runs/`.
- Imports GitHub Issues into local goal files.
- Verifies projects with configured validation commands.
- Generates morning reports, metrics, and a local HTML dashboard.
- Helps prepare draft pull requests without auto-merging or deploying.
- Uses agent role templates for feature building, bug fixing, refactoring, testing, verification, and reporting.

## Safety Model

Software Factory is designed to keep the human in control.

- Work happens on dedicated branches.
- Dirty working trees block automated starts.
- Local config and local goals are ignored by Git.
- Secrets, destructive migrations, production deployment, auto-merge, and auto-deploy are out of scope.
- Validation failures are recorded instead of hidden.
- Morning reports recommend review actions instead of making merge decisions.

## Quick Start

Install or verify Linux-native Codex in WSL:

```bash
./scripts/setup-wsl-codex.sh
codex login
```

Create your private local config:

```bash
cp factory.config.example.yaml factory.config.yaml
nvim factory.config.yaml
```

Add any local repositories you want Software Factory to manage. Each project gets
its own name, path, goal file, branch prefix, agent role, and validation
commands.

Check readiness:

```bash
./scripts/doctor.sh
```

Preview one project:

```bash
./scripts/run-project.sh --dry-run my-project
```

Launch one project:

```bash
./scripts/run-project.sh my-project
```

Launch every enabled project:

```bash
./scripts/run-night.sh
```

Review in the morning:

```bash
./scripts/summarize.sh
./scripts/update-metrics.sh
./scripts/dashboard.sh
```

## Goal Queue

Create local goals under `goals/queue/`. These files are private and ignored by
Git.

```bash
./scripts/list-goals.sh
./scripts/run-goal.sh goals/queue/my-project-goal.md
./scripts/run-ready-goals.sh --dry-run
```

See `goals/examples/example-goal.md` for the format.

## GitHub Issue Workflow

If a project has `githubRepo` and `issueLabels` in config, issues can become
local goals:

```bash
./scripts/list-issues.sh my-project
./scripts/import-issue.sh my-project 12
```

The factory does not pick vague or blocked issues automatically.

## Verification And PR Prep

Run project validation and save logs:

```bash
./scripts/verify-project.sh my-project
```

Prepare a draft PR after validation passes:

```bash
./scripts/prepare-pr.sh my-project
```

This does not auto-merge and does not deploy.

## Command Center

Most commands are also available through one entry point:

```bash
./scripts/factory.sh doctor
./scripts/factory.sh goals
./scripts/factory.sh run-ready --dry-run
./scripts/factory.sh summarize
./scripts/factory.sh update-metrics
./scripts/factory.sh dashboard
```

## Documentation

- [Product spec](docs/product-spec.md)
- [Architecture](docs/architecture.md)
- [Configuration](docs/configuration.md)
- [v2 workflow](docs/v2-workflow.md)
- [Scheduling](docs/scheduling.md)
- [Troubleshooting](docs/troubleshooting.md)
