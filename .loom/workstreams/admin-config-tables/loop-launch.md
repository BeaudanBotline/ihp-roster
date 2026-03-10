# Loop Launcher

Do not implement the workstream directly in this outer session.

From the repo root, run exactly:

```bash
bash ./.loom/bin/codex-workstream-loop.sh \
  --workstream admin-config-tables \
  --iterations 3 \
  --model gpt-5
```

After the script exits:

- if it succeeded, report that the loop completed and summarize the last iteration result from the generated logs
- if it failed, report the failing iteration number and the command failure without trying to continue manually

Do not make manual repo edits outside the loop unless the script itself fails before the first Codex iteration starts.
