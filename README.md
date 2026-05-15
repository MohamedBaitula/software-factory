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

## Project Status

This project is in early MVP planning and setup.

See [docs/product-spec.md](docs/product-spec.md) for the current product spec.

