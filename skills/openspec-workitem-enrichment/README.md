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

- `az login` for authentication
- `az boards` commands from the Azure DevOps CLI extension
- `az devops invoke` for comment retrieval
- `az devops configure --defaults ...` after inferring org and project from git

This skill no longer depends on Azure DevOps MCP or direct REST calls.

If login is required, the user should be told to run exactly:

```bash
az login
```

If the Azure DevOps extension is missing, the user should be told to run exactly:

```bash
az extension add --name azure-devops
```

## What it does

When invoked, the skill:

- validates the required spec naming pattern
- extracts the Azure DevOps work item id from the spec name
- tries to infer Azure DevOps org and project from the local git origin
- verifies Azure CLI is installed and authenticated
- verifies the Azure DevOps CLI extension is available
- configures Azure DevOps defaults automatically from inferred org and project
- uses WIQL through `az boards query` to confirm the work item exists in the target project
- fetches detailed work item fields through `az boards work-item show`
- fetches comments through `az devops invoke`
- follows parent relations through `az boards work-item relation show` up to the topmost parent
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
az login
az extension add --name azure-devops

./skills/openspec-workitem-enrichment/scripts/fetch-work-item-context.sh \
  --work-item-id 12345
```

### PowerShell example

```powershell
az login
az extension add --name azure-devops

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
- Azure CLI installed
- Azure CLI authenticated with `az login`
- Azure DevOps CLI extension available (`az extension add --name azure-devops`)
- access to the Azure DevOps org and project
- a repository git origin that allows Azure DevOps org/project inference, or focused user input for the missing values

## Validation notes

Before finalizing, validate that the skill is discoverable and installable:

```bash
npx skills add . --list
npx skills add . --skill openspec-workitem-enrichment
```

If scripts changed, also run syntax checks and a light smoke test such as `--help`.
