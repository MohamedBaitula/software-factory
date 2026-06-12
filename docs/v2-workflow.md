# Software Factory v2 Workflow

Software Factory v2 turns the original tmux launcher into a local workflow
system: define goals, launch Codex sessions, record run logs, verify changes,
summarize results, and optionally prepare draft pull requests.

## First Real Run

1. Install or verify Linux-native Node and Codex inside WSL:

   ```bash
   ./scripts/setup-wsl-codex.sh
   codex login
   ```

2. Create a private local config:

   ```bash
   cp factory.config.example.yaml factory.config.yaml
   nvim factory.config.yaml
   ```

3. Add a `GOAL.md` to the target project.

4. Check readiness:

   ```bash
   ./scripts/doctor.sh
   ```

5. Preview the run:

   ```bash
   ./scripts/run-project.sh --dry-run homebase
   ```

6. Start one project:

   ```bash
   ./scripts/run-project.sh homebase
   ```

7. Attach to tmux:

   ```bash
   tmux attach -t software-factory
   ```

8. Generate review output:

   ```bash
   ./scripts/summarize.sh
   ./scripts/update-metrics.sh
   ./scripts/dashboard.sh
   ```

## Goal Queue

Private goal files live under `goals/queue/` and are ignored by Git.

List goals:

```bash
./scripts/list-goals.sh
```

Run one goal:

```bash
./scripts/run-goal.sh goals/queue/homebase-dashboard.md
```

Run every pending or ready goal:

```bash
./scripts/run-ready-goals.sh
```

## GitHub Issues

Configured projects can include:

```yaml
githubRepo: MohamedBaitula/homebase
issueLabels:
  - software-factory
  - ready
```

List ready issues:

```bash
./scripts/list-issues.sh homebase
```

Import an issue into the local goal queue:

```bash
./scripts/import-issue.sh homebase 12
```

Issues with `blocked` or `needs-human` labels are not imported.

## Verification

Run configured validation commands and save logs:

```bash
./scripts/verify-project.sh homebase
```

Validation output is saved under:

```txt
logs/runs/<run-id>/projects/<project>/validation.log
```

## Draft PRs

Prepare a draft pull request only after validation passes:

```bash
./scripts/prepare-pr.sh homebase
```

This script does not auto-merge and does not deploy.

## Command Center

`scripts/factory.sh` provides a single entry point:

```bash
./scripts/factory.sh doctor
./scripts/factory.sh goals
./scripts/factory.sh run-goal goals/queue/example.md
./scripts/factory.sh run-ready --dry-run
./scripts/factory.sh summarize
./scripts/factory.sh update-metrics
./scripts/factory.sh dashboard
```

