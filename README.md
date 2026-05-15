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
6. Whether configured projects have clean working trees.

Exit codes:

- `0`: ready to run.
- non-zero: at least one blocking failure needs to be fixed.

For help:

```bash
./scripts/doctor.sh --help
```

## Project Status

This project is in early MVP planning and setup.

See [docs/product-spec.md](docs/product-spec.md) for the current product spec.
