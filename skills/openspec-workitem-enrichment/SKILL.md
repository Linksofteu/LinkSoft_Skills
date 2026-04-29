---
name: openspec-workitem-enrichment
description: Use this skill when creating a new OpenSpec spec whose name follows `wi-<azure-devops-work-item-id>-<change-name>` so the spec can be enriched from Azure DevOps through Azure CLI, including parent hierarchy and comments, instead of manual re-entry.
metadata:
  author: David Orolin
  version: "4.0.2"
---

## Purpose

Use this skill when creating a new OpenSpec spec from an Azure DevOps work item and the spec name follows `wi-<work-item-id>-<change-name>`.

This skill no longer depends on Azure DevOps MCP or direct REST calls. It uses Azure CLI with the Azure DevOps extension.

## In scope

- creating a new OpenSpec spec with the required naming pattern
- extracting the Azure DevOps work item id from the spec name
- inferring Azure DevOps org and project from the local git remote when possible
- verifying Azure CLI and the Azure DevOps CLI extension are available
- using `az boards` commands, `az devops invoke`, and WIQL to fetch work item context
- walking up the parent hierarchy from the target work item to the topmost parent
- producing structured output from topmost parent down to the requested work item
- enriching the new spec from sourced work item data

## Out of scope

- general Azure DevOps triage unrelated to new spec creation
- editing an existing spec that does not map to a work item
- inventing missing requirements not supported by the work item or user input

## Required naming rule

The spec name must match:

`wi-<azure-devops-work-item-number>-<name-of-change>`

Recommended validation pattern:

`^wi-(\d+)-([a-z0-9]+(?:-[a-z0-9]+)*)$`

If the name does not match:

1. stop enrichment
2. explain the required format
3. help normalize the change name into a lowercase hyphenated slug

## Default workflow

1. Confirm the task is to create a new OpenSpec spec.
2. Validate the spec name and extract the numeric work item id.
3. Infer Azure DevOps org and project from git origin before asking the user.
4. If inference is unclear, ask only for the missing org or project.
5. Verify Azure CLI is installed and authenticated. If needed, tell the user to run `az login`.
6. Verify `az boards` is available. If not, tell the user to install the Azure DevOps extension with `az extension add --name azure-devops`.
7. Configure Azure DevOps defaults from the inferred org and project:

   ```bash
   az devops configure --defaults organization="https://dev.azure.com/ORG" project="PROJECT"
   ```

8. Use `az boards query --wiql ...` to confirm the work item exists in the target project.
9. Fetch detailed work item fields with `az boards work-item show --id <id>`.
10. Fetch comments with `az devops invoke` against the work item comments endpoint.
11. Fetch parent relations and walk up the hierarchy until the topmost parent is reached.
12. Build structured output from the topmost parent down to the requested work item.
13. Enrich the spec from sourced data first, and clearly label any inferences.
14. Ask follow-up questions only for critical gaps that cannot be resolved from the work item chain.

## Scripted helpers

Prefer the bundled scripts instead of rebuilding the flow ad hoc:

- Bash context inference: `scripts/infer-azure-devops-context.sh`
- Bash work item fetch: `scripts/fetch-work-item-context.sh`
- PowerShell context inference: `scripts/infer-azure-devops-context.ps1`
- PowerShell work item fetch: `scripts/fetch-work-item-context.ps1`

Use the Bash scripts in Unix-like environments and the PowerShell scripts in PowerShell environments.

## Project and org inference

Before asking the user for Azure DevOps details, inspect `origin`.

Accepted remote shapes include:

- `https://dev.azure.com/org/ProjectName/_git/RepoName`
- `git@ssh.dev.azure.com:v3/org/ProjectName/RepoName`
- `https://org.visualstudio.com/ProjectName/_git/RepoName`

Use the bundled inference script first. Only ask the user when the remote is missing or ambiguous.

## Required prerequisite checks

Use Azure CLI plus the Azure DevOps extension, not Azure DevOps MCP and not direct REST calls.

Expected check order:

1. verify `az` is installed
2. verify the user is logged in with `az login`
3. verify the Azure DevOps extension is available by checking `az boards`
4. if the extension is missing, tell the user to run:

   ```bash
   az extension add --name azure-devops
   ```

5. after org/project inference, configure defaults with `az devops configure --defaults ...`

If login is needed, explicitly tell the user to run:

```bash
az login
```

If the Azure DevOps extension is also missing, explicitly tell the user to run:

```bash
az extension add --name azure-devops
```

If both are needed, present both commands in the order they should run:

```bash
az login
az extension add --name azure-devops
```

If Azure CLI is missing, not authenticated, or `az boards` is unavailable:

- do not pretend enrichment succeeded
- explain the blocker clearly
- print the exact command the user needs to run, such as `az login` and/or `az extension add --name azure-devops`, plus provide missing org/project details if inference failed
- offer manual fallback only if Azure CLI-based enrichment cannot proceed

## Required retrieval order

When the work item id is already known from the spec name, use this order:

1. infer org/project from git origin
2. verify `az boards` is available
3. configure Azure DevOps defaults from the inferred org and project
4. WIQL existence check for the known work item id
5. detailed work item fetch with focused fields
6. fetch comments for the target item
7. fetch parent relations for the target item
8. repeat the work item, comments, and parent-relation fetch for each parent until the topmost parent is reached
9. emit structured top-down output

Keep the first fetch light. Do not start with the heaviest possible request shape.

## Preferred Azure CLI commands

Preferred commands for this skill:

- `az devops configure --defaults organization="..." project="..."`
- `az boards query --wiql "..."`
- `az boards work-item show --id <id> --fields ...`
- `az boards work-item relation show --id <id>`
- `az devops invoke --area wit --resource comments ...`

The bundled fetch scripts use WIQL first, then fetch the target work item, its comments, its parent chain, and comments for each parent.

## What to fetch

Fetch as much relevant work item context as is practical, including when available:

- id, title, type, state, reason
- description, acceptance criteria, repro steps
- assigned to, created by, changed date
- area path, iteration path, tags, priority, value area, business value
- comments that clarify scope, decisions, or follow-up detail
- relation data needed to walk to the topmost parent

For hierarchy enrichment, fetch these items in the same way for every parent in the chain up to the topmost parent.

If the data is sparse, create a minimal spec shell and list unresolved gaps explicitly.

## Enrichment behavior

When drafting the spec:

1. build a top-down hierarchy from the topmost parent to the requested work item
2. for each item in the chain, include its type, title, description, acceptance criteria when present, and comments
3. use the requested work item title as the default summary anchor for the most specific implementation slice
4. use description and acceptance criteria across the hierarchy to populate the problem statement, requirements, and success criteria
5. use tags, priority, and paths to capture context and constraints
6. preserve traceability with the Azure DevOps work item ids and URLs
7. distinguish sourced facts from inferred guidance

Defaults:

- prefer concise synthesis over raw field dumps
- preserve acceptance criteria wording when it already reads like requirements
- mark inferred sections clearly
- do not replace missing fields with guessed content from the slug

Preferred structured output shape:

```markdown
## <Topmost parent type>: <Topmost parent title> (#<id>)
<Only include subsection blocks that have content>

### Description
<description>

### Acceptance Criteria
<acceptance criteria>

### Comments
<comment bullets>

## <Next child type>: <Next child title> (#<id>)
...
```

If a section has no content, omit that subsection entirely. Keep the work item heading even when an item has no populated subsections.

## Guardrails

- Do not use Azure DevOps MCP for this skill.
- Do not use direct REST calls for this skill.
- Do not ask for the Azure DevOps org or project before trying git-origin inference.
- Do not derive substantive requirements from the spec slug.
- Do not claim Azure DevOps data was fetched if Azure CLI auth or `az boards` checks failed.
- Do not ask the user to re-enter fields that were already retrieved successfully.
- Do not skip the WIQL confirmation step when following the scripted flow.
- Do not skip comments when they are available.
- Do not stop at the requested work item if parent hierarchy is available.
- Do not jump to relation retrieval before the main work item fetch succeeds.

## Manual fallback

If Azure CLI-based enrichment cannot be completed, ask for only the minimum details needed to continue:

- work item title
- description or business context
- acceptance criteria
- dependencies or related items if known

## Final check

Before finishing:

1. verify the spec name still matches the required pattern
2. verify the work item id used for enrichment matches the name
3. verify the org and project came from git origin or a focused user answer
4. verify Azure CLI plus `az boards` and `az devops invoke` retrieval succeeded, or that graceful fallback was used
5. verify the parent chain was followed to the topmost available parent
6. verify sourced vs inferred content is clearly separated
