# Configuration

Software Factory uses a private local config file to know which projects it can manage.

## Create Your Local Config

From the repo root:

```bash
cp factory.config.example.yaml factory.config.yaml
```

Then edit `factory.config.yaml` for your machine.

`factory.config.yaml` is ignored by Git so your private project paths and local commands do not get committed.

## Required Project Fields

Each project must include:

| Field | Required | Example | Purpose |
|---|---|---|---|
| `name` | yes | `homebase` | Short project identifier used by scripts. |
| `enabled` | yes | `true` | Whether run scripts should include the project. Use `true` or `false`. |
| `path` | yes | `/home/mbait/projects/homebase` | Local path to the project repository. |
| `goalFile` | yes | `GOAL.md` | Goal file the agent should read inside the project. |
| `branchPrefix` | yes | `codex/night` | Prefix for generated work branches. |
| `validation` | yes | `npm test` | Commands that define whether the run is complete. |

Optional fields:

| Field | Purpose |
|---|---|
| `stopConditions` | Human-readable safety rules for when an agent should pause. |
| `notes` | Extra context for the project or for your own memory. |

## Example Project

```yaml
projects:
  - name: homebase
    enabled: true
    path: /home/mbait/projects/homebase
    goalFile: GOAL.md
    branchPrefix: codex/night
    validation:
      - npm test
      - npm run build
    stopConditions:
      - Do not push code automatically.
      - Do not deploy to production.
    notes:
      - Main full-stack app project.
```

## Enabled Versus Disabled

Use `enabled: true` when a project should be included in run scripts.

Use `enabled: false` when you want to keep a project in the config but skip it for now.

The environment doctor still validates that disabled projects have the required fields, but it skips Git readiness checks for disabled projects.

## YAML Support

The MVP intentionally supports a small YAML subset so the scripts can stay Bash-only:

1. Keep the indentation style shown in `factory.config.example.yaml`.
2. Use one project per `- name:` entry.
3. Use `true` or `false` for `enabled`.
4. Put validation commands in a list under `validation`.
5. Avoid tabs in field values.

If the config grows more complex later, the project can switch to `yq`, JSON, or a small Node-based parser.

## Validate The Config

Run:

```bash
./scripts/doctor.sh
```

The doctor checks required fields, project paths, Git repositories, and clean working trees for enabled projects.
