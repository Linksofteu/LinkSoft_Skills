---
name: openspec-workitem-enrichment
description: Use this skill when creating a new OpenSpec spec whose name follows `wi-<azure-devops-work-item-id>-<change-name>` so the spec can be enriched automatically from the Azure DevOps work item instead of asking the developer to re-enter that context.
metadata:
  author: David Orolin
  version: "1.0.2"
---

## Purpose

Use this skill when a new OpenSpec spec should be created from an Azure DevOps work item and the spec name follows the required pattern `wi-<work-item-id>-<change-name>`.

## In scope

- creating a new OpenSpec spec with the required name pattern
- extracting the Azure DevOps work item id from the spec name
- fetching available work item context through Azure DevOps MCP
- enriching the spec so the developer does not need to retype existing work item information

## Out of scope

- general Azure DevOps issue triage unrelated to spec creation
- editing an existing spec that does not map to a work item
- inventing missing requirements that are not supported by the work item or user input

## Required naming rule

New OpenSpec specs handled by this skill must use this pattern:

`wi-<azure-devops-work-item-number>-<name-of-change>`

Examples:

- `wi-12345-add-customer-export`
- `wi-9876-fix-invoice-rounding`

If the name does not match this pattern:

1. do not continue with enrichment yet
2. tell the user the required format
3. help normalize the change name into a lowercase hyphenated slug if needed

Use this validation rule:

- work item id must be numeric
- change name should be lowercase and hyphenated
- recommended match pattern: `^wi-(\d+)-([a-z0-9]+(?:-[a-z0-9]+)*)$`

## Workflow

1. Confirm the task is about creating a new OpenSpec spec.
2. Extract the Azure DevOps work item id from the spec name.
3. Infer the Azure DevOps project name from the local git remote origin before asking the user.
4. Verify Azure DevOps MCP is available and usable before relying on enrichment.
5. Fetch all reasonably available work item information using Azure DevOps MCP.
6. Prefer first-party work item data over asking the developer to repeat it.
7. Use the fetched data to prefill the spec with sourced content first, then clearly marked inferences only when helpful.
8. Ask follow-up questions only for critical gaps that cannot be resolved from the work item.

## Azure DevOps project detection

Before asking the user for an Azure DevOps project name, first inspect the repository git remote origin.

Default behavior:

1. read the `origin` remote URL or path
2. extract the Azure DevOps project name from that origin
3. use the inferred project name for Azure DevOps MCP calls when the match is clear
4. only ask the user for the project name if the origin is missing, unreadable, or does not allow a confident project-name extraction

Assume the git origin normally contains the project name.

Examples of acceptable sources:

- Azure DevOps HTTPS remotes such as `https://dev.azure.com/org/ProjectName/_git/RepoName`
- Azure DevOps SSH remotes or equivalent origin paths where the project segment is still present

If inference fails, ask one focused follow-up question for the Azure DevOps project name instead of asking the user to restate other details already available.

## Azure DevOps MCP preflight

Before enrichment, verify that Azure DevOps MCP is:

- installed or otherwise available to the agent runtime
- reachable and functioning
- authenticated if authentication is required
- supplied with the inferred project name when one was confidently derived from git origin

If Azure DevOps MCP is available, continue with work item lookup.

If Azure DevOps MCP is not available or not usable:

1. fail gracefully instead of pretending enrichment succeeded
2. tell the user that Azure DevOps MCP could not be used
3. state the likely reason when known, such as not installed, not configured, not authenticated, or inaccessible
4. offer a manual fallback so the user can still continue creating the spec

Recommended fallback message shape:

- explain that automatic enrichment could not be completed
- say whether the blocker is availability, configuration, or authentication
- ask for the minimum manual details needed to continue

Recommended minimum manual fallback details:

- work item title
- description or business context
- acceptance criteria
- related dependencies or linked items if known

## What to fetch from Azure DevOps MCP

Fetch as much relevant context as the MCP exposes for the work item, including when available:

- id, title, type, state, reason, priority, severity, value area
- description, acceptance criteria, repro steps, business context
- assigned to, created by, iteration path, area path, tags
- parent, child, related, blocked-by, and other linked work items
- comments, discussion, history, or recent updates
- URLs or identifiers that help trace the work item back to Azure DevOps

If linked work items materially clarify scope, include the important details in the spec summary instead of copying everything verbatim.

## Enrichment behavior

When drafting the spec:

1. Use the work item title as the default starting point for the spec title or summary.
2. Use the description and acceptance criteria to populate the problem statement, goals, requirements, or success criteria.
3. Use tags, type, priority, links, and hierarchy to capture implementation context, dependencies, and affected areas.
4. Preserve traceability by including the Azure DevOps work item id and link in the spec.
5. Distinguish sourced facts from inferred guidance.

Defaults:

- prefer concise synthesis over dumping raw fields
- quote or preserve exact wording for acceptance criteria when they already read like requirements
- mark inferred sections with labels such as `Inferred from work item` when not directly stated
- if the work item is sparse, create a minimal spec shell and list the unresolved gaps clearly

## Guardrails

- Do not fabricate requirements, user journeys, or technical decisions that are absent from the work item and user request.
- Do not hide uncertainty; call out ambiguity explicitly.
- Do not ignore naming violations.
- Do not ask for the Azure DevOps project name before trying to derive it from git origin.
- Do not ask the user to re-enter work item fields that were already retrieved successfully.
- Do not act as though Azure DevOps enrichment succeeded when MCP is unavailable or failing.

## Suggested spec content

When the target OpenSpec format is not otherwise prescribed, prefer including:

- spec identifier or name
- linked Azure DevOps work item
- summary or problem statement
- goals or intended outcome
- requirements or acceptance criteria
- dependencies, related items, or constraints
- open questions or missing information

## Final check

Before finishing:

1. verify the spec name still matches the required pattern
2. verify the Azure DevOps work item id used for enrichment matches the name
3. verify Azure DevOps MCP was available, or that graceful fallback behavior was used
4. verify fetched work item context was incorporated where relevant
5. verify any inferred content is clearly marked
