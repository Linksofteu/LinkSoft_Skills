---
name: ddd-application-slice
description: "Use this skill when adding or extending functionality in a DDD project so the implementation fits the intended layers: controllers, application services, mediator-style commands, queries, or events, handlers, domain services, and repositories."
metadata:
  author: David Orolin
  version: "1.0.0"
---

## Purpose

Use this skill to design or implement one coherent DDD application slice in a standardized structure:

- entrypoint (`controller`, `endpoint`, or `application service`)
- mediator-style message (`query`, `command`, or `event`/fire-and-forget message)
- handler
- optional domain service
- repository and mapping

Keep the skill technology-agnostic. The mediator library can vary. Preserve the architectural responsibilities.

## Core model

Treat each new use case as one of these three flows:

1. **Query for data**
   - use a request/response read model such as a query + query handler
   - keep it side-effect free
   - usually inject repository directly in the handler and map/return the result

2. **Trigger a change and wait for a result**
   - use a command-style request handled synchronously from the caller's perspective
   - return only the data the caller actually needs
   - for simple changes, handler-to-repository is acceptable
   - for business rules, orchestration, invariants, or multi-entity logic, call a domain service that uses repositories

3. **Trigger a change and do not wait for a result**
   - use an event, notification, local message, queued command, or equivalent fire-and-forget concept from the chosen stack
   - use this for follow-up work, integration reactions, notifications, cache invalidation, workflows, or other side effects that should not shape the immediate response contract

## Workflow

### 1. Identify the entrypoint

Start from the caller-facing surface:

- controller
- HTTP endpoint
- application service
- background entrypoint

Keep the entrypoint thin.

It should mainly:

- accept input
- enforce coarse authorization or transport concerns if needed
- create the mediator message
- dispatch it
- return the result

Do not place business rules or repository orchestration in the entrypoint unless the existing project convention explicitly requires it.

### 2. Choose the message type before writing code

Ask:

- Is this only reading data? Use a **query**.
- Is this changing state and the caller needs completion or returned data? Use a **command**.
- Is this changing state or reacting to a change without the caller waiting for completion? Use an **event** or other fire-and-forget message.

If a single request both mutates state and kicks off secondary reactions, split the responsibilities:

- command handles the primary state change
- event or fire-and-forget message handles follow-up reactions

### 3. Design the handler responsibilities

Handlers should coordinate one use case, not become a dumping ground.

Default handler responsibilities:

- load required data
- perform simple guard checks that are specific to the use case
- map transport DTOs to domain/application models where needed
- delegate business logic to the right place
- persist through repositories, directly or via domain service
- map the result to the response type
- publish follow-up events when appropriate

### 4. Decide between direct repository usage and domain service

Use this default decision rule:

**Use repository directly from the handler when** the action is simple, localized, and has little business logic.

Examples:

- straightforward lookup
- simple create, update, or delete
- toggling or saving user preferences
- fetching and mapping data for a query

**Use a domain service when** the use case includes meaningful business behavior.

Typical signals:

- invariants or business rules
- multiple validation steps
- multiple entities or aggregates involved
- workflow or stage transitions
- derived values or generated identifiers
- repeated logic likely to be reused
- domain events or follow-up reactions tied to domain behavior

The preferred chain for complex writes is:

`entrypoint -> mediator message -> handler -> domain service -> repository`

### 5. Shape the output deliberately

For queries:

- return DTOs or read models
- optimize for read concerns and mapping clarity
- do not return domain entities directly unless the project standard explicitly does so

For commands:

- return nothing when the caller only needs success/failure
- return a DTO, identifier, or summary only when the caller truly needs it

For fire-and-forget messages:

- avoid response coupling
- treat the contract as a trigger, not a conversational API

### 6. Keep business logic out of the wrong layers

Avoid these common mistakes:

- controller or app service contains repository logic
- query handler performs writes
- command handler accumulates deep domain logic that belongs in a domain service
- domain service depends on transport-specific concerns
- event handler becomes the primary write path for synchronous user workflows

### 7. Validate the slice before finishing

Check that:

- the entrypoint is thin
- the message type matches the intent
- reads stay separate from writes
- complex business rules live in a domain service
- repositories handle persistence, not application orchestration
- fire-and-forget work is separated from the immediate response path
- naming reflects intent clearly (`Get...Query`, `Create...Command`, `...Event`, `...Handler` or equivalent project naming)

## Defaults

- Prefer thin entrypoints and focused handlers.
- Prefer queries for reads, commands for awaited writes, and events or equivalent messages for non-awaited follow-up work.
- For queries, repository + mapping in the handler is usually enough.
- For simple commands, handler + repository is acceptable.
- For complex commands, route through a domain service.
- Keep the guidance abstract enough to fit MediatR-style libraries, Wolverine-style handlers, ABP local message bus patterns, or similar mediator architectures.

## Reference

- Read `references/slice-planning-checklist.md` when you need a more explicit planning sequence, a responsibility matrix, or a concrete implementation checklist for a new slice.
