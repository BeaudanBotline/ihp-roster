# Loom Workstream Instructions

This directory holds repo-local execution context for coordinator-managed workstreams.

## Layout

Use this structure for an active tracked workstream:

```text
.loom/
  base-prompt.md
  workstreams/
    <workstream>/
      prompt.md
      context.md
      handoff.md
      history.md
```

## Rules

- `prompt.md` is the launch entrypoint for the workstream.
- `context.md` holds stable workstream scope, constraints, and required read order.
- `handoff.md` holds the current technical resume point.
- `history.md` is optional and should hold longer debug or relaunch history when it is still useful.
- When a workstream is complete and its durable learnings are reflected in repo docs, remove its `.loom/workstreams/<workstream>/` directory.

## Learning Capture

When you learn something during a workstream:

- put current resume-critical details in `handoff.md`
- put longer failed-attempt or debugging sequences in `history.md`
- promote stable repo-wide conventions into the repo's `AGENTS.md` or relevant specs
- update coordinator state or coordinator docs only if the learning affects orchestration outside this repo

Do not leave reusable learnings only in a final message.
