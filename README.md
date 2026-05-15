# Software Factory

Software Factory is a local AI development orchestration system for running safe, reviewable Codex goal sessions across multiple repositories.

It is inspired by the idea of a self-driving codebase: humans define intent, constraints, and review standards; AI agents execute scoped development work inside isolated Git branches and tmux sessions.

## What It Does

The MVP will:

1. Read a config file of local projects.
2. Check that the environment is ready.
3. Verify each project has a clean Git working tree.
4. Create a dedicated branch for each run.
5. Launch one tmux window per project.
6. Start Codex CLI with a structured goal prompt.
7. Track validation commands and run status.
8. Produce a morning review report.

## Why This Exists

AI coding tools are powerful, but one-off prompts are hard to manage across many projects. Software Factory turns AI-assisted coding into a repeatable workflow with safety rules, project configuration, validation, and review summaries.

## Safety Principles

- Work happens on dedicated branches.
- Existing uncommitted changes are protected.
- Code is not pushed automatically.
- Production deploys are out of scope.
- Ambiguous product decisions require human review.
- Every run should leave a clear summary.

## Planned Stack

- WSL Ubuntu
- tmux
- Codex CLI
- Git and GitHub
- Bash scripts for the MVP
- YAML project configuration

## Getting Started

Software Factory is designed to run from WSL:

```bash
cd ~/projects/software-factory
```

Before the first run, create a local config file:

```bash
cp factory.config.example.yaml factory.config.yaml
```

Then edit `factory.config.yaml` so each project points to a real local repository on your machine.

See [docs/configuration.md](docs/configuration.md) for the supported config fields and examples.

## Environment Doctor

Run the doctor before an overnight session:

```bash
./scripts/doctor.sh
```

The doctor checks:

1. Required tools: `git`, `tmux`, `codex`, `node`, and `npm`.
2. Optional tools: `pnpm`, `gh`, and `shellcheck`.
3. Whether `factory.config.yaml` exists.
4. Whether configured project paths exist.
5. Whether configured projects are Git repositories.
6. Whether enabled projects have clean working trees.

Exit codes:

- `0`: ready to run.
- non-zero: at least one blocking failure needs to be fixed.

For help:

```bash
./scripts/doctor.sh --help
```

## Single Project Runner

Use the single-project runner when you want to start one configured project:

```bash
./scripts/run-project.sh --dry-run homebase
```

If the dry run looks right, start the project run:

```bash
./scripts/run-project.sh homebase
```

The runner:

1. Reads the project from `factory.config.yaml`.
2. Blocks disabled or misconfigured projects.
3. Verifies the project path is a Git repository.
4. Blocks projects with uncommitted changes.
5. Creates a branch like `codex/night-YYYY-MM-DD-homebase`.
6. Verifies the configured goal file exists.
7. Starts or reuses the configured tmux session.
8. Creates a tmux window and starts Codex in the project folder.

After launch, attach to the session:

```bash
tmux attach -t software-factory
```

## Overnight Runner

Use the night runner when you want to launch every enabled project:

```bash
./scripts/run-night.sh --dry-run
```

If the dry run looks right, start the overnight run:

```bash
./scripts/run-night.sh
```

The night runner:

1. Reads all projects from `factory.config.yaml`.
2. Skips projects with `enabled: false`.
3. Calls `scripts/run-project.sh` for each enabled project.
4. Uses one shared tmux session.
5. Uses one tmux window per project.
6. Continues to the next project if one project fails.
7. Prints a final launch summary and attach command.

Attach to the running factory:

```bash
tmux attach -t software-factory
```

## Project Status

This project is in early MVP planning and setup.

See [docs/product-spec.md](docs/product-spec.md) for the current product spec.
