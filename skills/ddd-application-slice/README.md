# ddd-application-slice

Guide an agent or developer through implementing a DDD-style application slice with thin entrypoints, mediator-pattern messages, focused handlers, optional domain services, and repositories.

## Contents

- `SKILL.md`: core workflow for choosing and implementing query, command, and fire-and-forget flows
- `references/slice-planning-checklist.md`: deeper checklist for planning responsibilities and layer placement
- `evals/evals.json`: starter evaluation prompts for this skill

## What this skill covers

- choosing between query, command, and fire-and-forget message flows
- keeping controllers, endpoints, and application services thin
- deciding when a handler can use a repository directly
- deciding when a command should call a domain service
- separating primary state changes from secondary side effects
- preserving architecture without tying the design to one mediator library

## Architecture assumptions

This skill assumes a layered application with some variation of:

- controller, endpoint, or application service
- mediator-style dispatch
- query, command, event, notification, or equivalent message types
- handlers
- domain services for richer business logic
- repositories for persistence

The exact technology may vary. The skill focuses on responsibilities, not framework APIs.

## Validation notes

Before finalizing, validate that the skill is discoverable and installable:

```bash
npx skills add . --list
npx skills add . --skill ddd-application-slice
```
