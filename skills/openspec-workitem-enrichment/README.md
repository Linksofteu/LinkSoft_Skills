# openspec-workitem-enrichment

This skill helps create a new OpenSpec spec from an Azure DevOps work item so the agent can reuse work item context instead of asking the developer to type it again.

## When to use it

Use this skill when the user wants to create a **new OpenSpec spec** and the spec name follows:

`wi-<azure-devops-work-item-number>-<name-of-change>`

Examples:

- `wi-12345-add-customer-export`
- `wi-9876-fix-invoice-rounding`

Typical requests:

- create a new OpenSpec spec from Azure DevOps
- enrich a spec from an Azure DevOps work item
- create `wi-12345-some-change` and pull in work item details automatically

## What changed in this version

This skill now uses:

- direct Azure DevOps REST API calls for work item retrieval
- a local PAT file for authentication
- expanded work item relations to walk the parent hierarchy
- the comments REST endpoint for comment retrieval

This skill no longer depends on Azure DevOps MCP or Azure CLI work item commands.

On Unix-like systems, create this exact file:

```bash
~/.config/linksoft-skills/azure-devops.env
```

On Windows PowerShell, create this exact file:

```powershell
%USERPROFILE%\.config\linksoft-skills\azure-devops.env
```

For Windows users, expand `%USERPROFILE%` to your actual profile folder, for example `C:\Users\YourName`. Then:

1. Create the directory `C:\Users\YourName\.config\linksoft-skills`.
2. Inside that directory, create a file named exactly `azure-devops.env`.
3. Put exactly one line in the file:

   ```text
   AZURE_DEVOPS_PAT=<your Azure DevOps PAT>
   ```

4. Replace `<your Azure DevOps PAT>` with the actual token and save the file.

The file must contain exactly one line:

```text
AZURE_DEVOPS_PAT=<your Azure DevOps PAT>
```

Do not add quotes around the token. Do not commit this file to git.

When creating the PAT in Azure DevOps, grant the minimum required scope:

```text
Work Items: Read
```

This corresponds to the Azure DevOps REST API `vso.work` permission, which allows reading work items, comments, queries, boards, area paths, and iteration paths. The token does not need write permissions, Code permissions, Build permissions, Packaging permissions, or full access for this skill.

## What it does

When invoked, the skill:

- validates the required spec naming pattern
- extracts the Azure DevOps work item id from the spec name
- tries to infer Azure DevOps org and project from the local git origin
- verifies the local PAT file exists and is correctly shaped
- fetches detailed work item fields through the Azure DevOps REST API
- fetches comments through the Azure DevOps comments REST API
- follows expanded parent relations up to the topmost parent
- emits structured hierarchy output from topmost parent to requested work item
- uses that data to enrich the new OpenSpec spec
- keeps traceability back to the original Azure DevOps work item

## Bundled scripts

The skill includes reusable helper scripts:

- `scripts/infer-azure-devops-context.sh`
- `scripts/fetch-work-item-context.sh`
- `scripts/infer-azure-devops-context.ps1`
- `scripts/fetch-work-item-context.ps1`

### Bash example

```bash
./skills/openspec-workitem-enrichment/scripts/fetch-work-item-context.sh \
  --work-item-id 12345
```

### PowerShell example

```powershell
./skills/openspec-workitem-enrichment/scripts/fetch-work-item-context.ps1 \
  -WorkItemId 12345
```

### Structured output shape

The scripts produce a top-down hierarchy like:

```markdown
## Epic: Parent title (#123)
### Description
...

### Acceptance Criteria
...

### Comments
...

## Feature: Child title (#456)
...

## User Story: Requested work item title (#789)
...
```

Only include subsection blocks that actually have content. Keep the work item heading even when a given item has no populated subsections.

## Prerequisites

For automatic enrichment, these need to be available:

- a new OpenSpec spec request
- a spec name in the required format `wi-<id>-<change-name>`
- a local PAT file at `~/.config/linksoft-skills/azure-devops.env` on Unix-like systems, or `%USERPROFILE%\.config\linksoft-skills\azure-devops.env` on Windows
- exactly one line in the PAT file: `AZURE_DEVOPS_PAT=<your Azure DevOps PAT>`
- a PAT with the Azure DevOps `Work Items: Read` scope
- access to the Azure DevOps org and project
- a repository git origin that allows Azure DevOps org/project inference, or focused user input for the missing values

## Validation notes

Before finalizing, validate that the skill is discoverable and installable:

```bash
npx skills add . --list
npx skills add . --skill openspec-workitem-enrichment
```

If scripts changed, also run syntax checks and a light smoke test such as `--help`.
