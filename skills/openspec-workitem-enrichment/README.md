# openspec-workitem-enrichment

This skill helps create a new OpenSpec spec from an Azure DevOps work item so the agent can reuse work item context instead of asking the developer to type it again.

## When to use it

Use this skill when the user wants to create a **new OpenSpec spec** and the spec name follows this format:

`wi-<azure-devops-work-item-number>-<name-of-change>`

Examples:

- `wi-12345-add-customer-export`
- `wi-9876-fix-invoice-rounding`

Typical requests:

- create a new OpenSpec spec from Azure DevOps
- enrich a spec from an Azure DevOps work item
- create `wi-12345-some-change` and pull in work item details automatically

## What it does

When invoked, the skill:

- validates the required spec naming pattern
- extracts the Azure DevOps work item id from the spec name
- tries to infer the Azure DevOps project from the local git origin
- fetches work item context through Azure DevOps MCP
- uses that data to enrich the new OpenSpec spec
- keeps traceability back to the original Azure DevOps work item

## Prerequisites

For the enrichment flow to work automatically, these things need to be available:

- a new OpenSpec spec request
- a spec name in the required format `wi-<id>-<change-name>`
- Azure DevOps MCP installed and usable
- Azure DevOps MCP authenticated if authentication is required
- a repository git origin that allows Azure DevOps project inference, or the project name provided by the user

Azure DevOps MCP setup and configuration:

- https://github.com/microsoft/azure-devops-mcp

If Azure DevOps MCP is unavailable or cannot be used, the skill should fail gracefully and ask for the minimum manual details needed to continue.

## Validation notes

Before finalizing, validate that the skill is discoverable and installable:

```bash
npx skills add . --list
npx skills add . --skill openspec-workitem-enrichment
```
