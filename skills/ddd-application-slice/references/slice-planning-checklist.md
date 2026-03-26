# Slice planning checklist

Use this reference when implementing a concrete use case and you want a stricter planning sequence than the main `SKILL.md` provides.

## 1. Write the use-case sentence first

Capture the slice in one sentence:

- **Actor** does **action** on **business concept** and expects **result**.

Examples:

- User requests a list of invoices and expects paged invoice summaries.
- Clerk approves an amendment and expects confirmation plus updated detail data.
- System records a completed import and triggers notifications without delaying the API response.

If the sentence mixes multiple concerns, split the slice.

## 2. Pick the flow type

Use this matrix:

| Intent | Default flow | Notes |
|---|---|---|
| Read data | Query | No writes or side effects |
| Change state and wait for completion | Command | Return only needed data |
| Trigger follow-up work without waiting | Event / fire-and-forget message | Good for notifications, workflows, integrations |

If the use case changes state and also launches reactions, model the primary write separately from the secondary reactions.

## 3. Plan each layer before coding

### Entrypoint

Define:

- input contract
- auth or transport concerns
- which message gets dispatched
- return contract

Entrypoint rule: if the code starts reasoning about business invariants, it is probably too thick.

### Message

Define:

- message name based on intent
- required input fields
- response type, if any

Choose names that describe intent, not implementation details.

### Handler

Define:

- what data it loads
- what mapping it performs
- whether it uses repository directly or calls a domain service
- whether it emits follow-up messages

Handler rule: it should coordinate the use case, not absorb the entire domain.

### Domain service

Add one when the write includes domain-specific rules or orchestration.

Typical responsibilities:

- enforce invariants
- manage lifecycle or stage changes
- coordinate multiple repositories or entities
- calculate derived values
- encapsulate reusable business operations

Domain service rule: it should stay independent from HTTP, controller, or UI concerns.

### Repository

Repositories should focus on:

- loading data
- persisting data
- tailored query methods needed by the slice

Repository rule: do not move application workflow decisions into persistence classes.

## 4. Apply the default read pattern

For most queries:

1. entrypoint dispatches query
2. query handler loads from repository
3. handler maps to DTO/read model
4. handler returns result

Only add more layers if the read truly needs them.

## 5. Apply the default write pattern

For simple commands:

1. entrypoint dispatches command
2. handler performs simple guards
3. handler loads and persists via repository
4. handler returns minimal result

For complex commands:

1. entrypoint dispatches command
2. handler maps input and loads prerequisite data
3. handler calls domain service
4. domain service enforces rules and uses repositories
5. handler maps and returns result
6. handler or domain layer triggers follow-up events if needed by project convention

## 6. Fire-and-forget guidance

Use an event or non-awaited message when:

- the caller should not wait for the work
- the work is a reaction to an already-completed change
- retries or eventual consistency are acceptable

Examples:

- send notifications
- invalidate caches
- start background workflows
- publish integration signals

Do not hide critical synchronous business decisions in a fire-and-forget path.

## 7. Final review checklist

- Is the entrypoint thin?
- Is the message type correct for the intent?
- Are reads free of writes?
- Does the command use a domain service only when justified?
- Are repositories handling persistence rather than orchestration?
- Are follow-up side effects separated from the immediate response path?
- Would another developer know where to put the next piece of logic?
