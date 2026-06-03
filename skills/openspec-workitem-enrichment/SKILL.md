---
name: openspec-workitem-enrichment
description: Use this skill when creating a new OpenSpec spec whose name follows `wi-<azure-devops-work-item-id>-<change-name>` so the spec can be enriched from Azure DevOps work item REST API data, including parent hierarchy and comments, instead of manual re-entry.
metadata:
  author: David Orolin
  version: "4.1.0"
---

## Purpose

Use this skill when creating a new OpenSpec spec from an Azure DevOps work item and the spec name follows `wi-<work-item-id>-<change-name>`.

This skill does not use Azure DevOps MCP or the Azure CLI for work item retrieval. It uses the Azure DevOps REST API directly with a local PAT file.

## In scope

- creating a new OpenSpec spec with the required naming pattern
- extracting the Azure DevOps work item id from the spec name
- inferring Azure DevOps org and project from the local git remote when possible
- verifying the required local PAT file is present and correctly shaped
- using Azure DevOps REST API endpoints to fetch work item context
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
5. Verify the local PAT file exists and contains only `AZURE_DEVOPS_PAT=<token>`.
6. Fetch the target work item with `GET /_apis/wit/workitems/{id}?$expand=relations&api-version=7.1`.
7. Fetch comments with `GET /_apis/wit/workItems/{id}/comments?api-version=7.1-preview.4`.
8. Read parent relations from the expanded work item relations and walk up the hierarchy until the topmost parent is reached.
9. Build structured output from the topmost parent down to the requested work item.
10. Enrich the spec from sourced data first, and clearly label any inferences.
11. Ask follow-up questions only for critical gaps that cannot be resolved from the work item chain.

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

## Required PAT configuration

The work item fetch scripts require a local PAT file and do not fall back to Azure CLI authentication.

Unix-like environments must use this exact path:

`~/.config/linksoft-skills/azure-devops.env`

Windows PowerShell must use this exact path:

`%USERPROFILE%\.config\linksoft-skills\azure-devops.env`

When giving Windows setup instructions, expand `%USERPROFILE%` to the user's actual profile directory if known from the environment. Prefer manual, file-explorer-friendly instructions first:

1. create the directory `<expanded-user-profile>\.config\linksoft-skills`
2. inside it, create a file named exactly `azure-devops.env`
3. put exactly one line in the file: `AZURE_DEVOPS_PAT=<your Azure DevOps PAT>`
4. replace `<your Azure DevOps PAT>` with the actual token and save the file

PowerShell commands may be shown after the manual instructions as an optional shortcut, but they must not be the only Windows guidance.

The file must contain exactly one environment variable assignment, on one line:

```text
AZURE_DEVOPS_PAT=<your Azure DevOps PAT>
```

Do not add quotes around the token. Do not commit this file to git.

When creating the PAT in Azure DevOps, tell the user to grant the minimum required scope:

`Work Items: Read`

This corresponds to the Azure DevOps REST API `vso.work` permission, which allows reading work items, comments, queries, boards, area paths, and iteration paths. The token does not need write permissions, Code permissions, Build permissions, Packaging permissions, or full access for this skill.

If the PAT file is missing or invalid, stop enrichment and emit precise setup instructions that name the exact path for the current OS and show the exact one-line file shape above.

## Required retrieval order

When the work item id is already known from the spec name, use this order:

1. infer org/project from git origin
2. verify the local PAT file exists and is correctly shaped
3. detailed work item fetch with `$expand=relations`
4. fetch comments for the target item
5. extract the parent id from `System.LinkTypes.Hierarchy-Reverse` relations
6. repeat the work item and comments fetch for each parent until the topmost parent is reached
7. emit structured top-down output

Keep the first fetch light. Do not start with the heaviest possible request shape.

## Preferred REST API endpoints

Preferred documented Azure DevOps REST API endpoints for this skill:

- Work Items - Get Work Item: `GET https://dev.azure.com/{organization}/{project}/_apis/wit/workitems/{id}?$expand=relations&api-version=7.1`
- Comments - Get Comments: `GET https://dev.azure.com/{organization}/{project}/_apis/wit/workItems/{workItemId}/comments?api-version=7.1-preview.4`
- PAT authentication: send the PAT as HTTP Basic auth with an empty username and the PAT as the password.

The bundled fetch scripts fetch the target work item, its comments, its parent chain, and comments for each parent. Do not combine the `fields` query parameter with `$expand=relations`; Azure DevOps rejects that combination. A separate WIQL existence check is intentionally not required because the direct work item GET gives a simpler and more reliable success/failure signal than the previous Azure CLI flow.

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
- Do not use Azure CLI work item retrieval for this skill.
- Do not ask for the Azure DevOps org or project before trying git-origin inference.
- Do not derive substantive requirements from the spec slug.
- Do not claim Azure DevOps data was fetched if the REST API requests failed.
- Do not ask the user to re-enter fields that were already retrieved successfully.
- Do not skip comments when they are available.
- Do not stop at the requested work item if parent hierarchy is available.
- Do not jump to relation retrieval before the main work item fetch succeeds.

## Manual fallback

If REST API-based enrichment cannot be completed, ask for only the minimum details needed to continue:

- work item title
- description or business context
- acceptance criteria
- dependencies or related items if known

## Final check

Before finishing:

1. verify the spec name still matches the required pattern
2. verify the work item id used for enrichment matches the name
3. verify the org and project came from git origin or a focused user answer
4. verify REST API retrieval succeeded, or that graceful fallback was used
5. verify the parent chain was followed to the topmost available parent
6. verify sourced vs inferred content is clearly separated
