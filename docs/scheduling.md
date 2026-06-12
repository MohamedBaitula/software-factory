# Scheduling

Software Factory can be scheduled with cron or systemd timers, but scheduled
runs should be treated carefully.

## Safety Requirements

- Keep the machine plugged in.
- Disable sleep and hibernate while scheduled runs are active.
- Keep network access available.
- Run `./scripts/doctor.sh` successfully before scheduling.
- Do not schedule destructive goals.
- Do not enable automatic pushing, merging, or deployment.

## Scheduled Script

Use:

```bash
./scripts/scheduled-night-run.sh
```

It runs:

1. `doctor.sh`
2. `run-night.sh`
3. `summarize.sh`
4. `update-metrics.sh`
5. `dashboard.sh`

## Cron Example

Open crontab:

```bash
crontab -e
```

Example schedule for 11:30 PM:

```cron
30 23 * * * cd /home/mbait/projects/software-factory && ./scripts/scheduled-night-run.sh >> logs/scheduled.log 2>&1
```

## Morning Review

After a scheduled run:

```bash
cd ~/projects/software-factory
./scripts/list-runs.sh
./scripts/summarize.sh
./scripts/dashboard.sh
```

