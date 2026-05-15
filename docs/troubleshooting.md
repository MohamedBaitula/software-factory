# Troubleshooting

This guide covers common Software Factory setup and run failures.

## First Checks

Run these from the repo root:

```bash
./scripts/doctor.sh
git status --short
```

The doctor should be the first command you run before starting overnight work.

## Common Failures

### `factory.config.yaml is missing`

Create your private local config:

```bash
cp factory.config.example.yaml factory.config.yaml
```

Then edit `factory.config.yaml` so each enabled project points to a real local Git repository.

### `node is required but was not found on PATH`

Install Linux-native Node inside WSL. Do not rely on the Windows Node shim for overnight WSL runs.

Recommended direction:

```bash
# install nvm, then install Node 22+
nvm install 22
node --version
```

### `codex was found but could not run`

This usually means WSL is finding a Windows Codex/npm shim, but Linux Node is missing.

Fix Linux-native Node first, then install or verify Codex inside WSL:

```bash
node --version
codex --version
```

### `project has uncommitted changes`

Software Factory blocks dirty projects so it does not overwrite human work.

Go to the project and inspect:

```bash
cd /path/to/project
git status
git diff
```

Commit, stash, or discard the changes yourself before running the factory.

### `branch already exists in project`

The runner will not overwrite an existing branch.

Options:

1. Continue work manually on that branch.
2. Delete the branch yourself if it is no longer needed.
3. Change the project `branchPrefix` or wait for a new date.

### `tmux window already exists`

The runner reuses existing windows instead of creating duplicates.

Attach to the session:

```bash
tmux attach -t software-factory
```

Then switch to the project window.

### `no enabled projects found`

At least one project must have:

```yaml
enabled: true
```

Disabled projects are documented but skipped.

## Expected Output Examples

### Doctor Not Ready

```txt
== Required tools ==
[PASS] git found (git version ...)
[FAIL] node is required but was not found on PATH

== Config ==
[FAIL] factory.config.yaml is missing

Doctor result: not ready yet. Fix the failures above, then run again.
```

### Single Project Dry Run

```txt
[INFO] would create branch 'codex/night-YYYY-MM-DD-homebase' from 'main'
[INFO] would ensure tmux session 'software-factory' exists
[INFO] would create tmux window 'homebase' in /home/mbait/projects/homebase
[INFO] would start Codex with command: codex

Attach command:
  tmux attach -t software-factory
```

### Night Runner Summary

```txt
== Night Run Summary ==
Enabled projects: 2
Disabled projects skipped: 1
Successful launches: 2
Failed launches: 0

Attach command:
  tmux attach -t software-factory
```

### Morning Report

```txt
[INFO] wrote report: /home/mbait/projects/software-factory/reports/morning-YYYY-MM-DD.md
```
