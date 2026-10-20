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

Version **4.3.0** makes the agent select safe screenshot storage automatically and attach screenshot evidence to OpenSpec changes using portable relative links. The script-level download flag remains optional. Retrieval continues to use:

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
- `scripts/download-work-item-images.py` (shared opt-in downloader)

### Bash example

```bash
./skills/openspec-workitem-enrichment/scripts/fetch-work-item-context.sh \
  --work-item-id 12345
```

### PowerShell example

```powershell
./skills/openspec-workitem-enrichment/scripts/fetch-work-item-context.ps1 `
  -WorkItemId 12345
```

### Screenshot storage and OpenSpec attachments

Add `--download-images DIR` in Bash or `-DownloadImages DIR` in PowerShell. Without this flag, existing calls neither download images nor add an `images` manifest. Both fetch helpers delegate image downloads to `scripts/download-work-item-images.py`, which requires Python 3 (`python3`). Bash already requires Python 3; PowerShell needs it only for this opt-in feature.

**Agent default:** include the download flag during enrichment unless the developer opts out. The agent chooses the directory; users do not need to provide one. Resolve the workspace and active change, honor approved writable roots, and verify access using a unique create/delete probe. Never assume a particular temp path or the skill installation directory is writable, and never follow symlinks outside the authorized destination.

During an OpenSpec flow, store screenshots in `<change-directory>/assets/screenshots/`. If the scaffold is not ready, use an isolated directory under an approved scratch/temp root, then copy verified downloads into the change once available. An explicit external destination is staging, not a replacement for spec attachments. If no location is authorized/writable, request the necessary access; do not silently omit screenshots or claim staged files are attached.

Before finalizing the change:

- Verify and inspect successful downloads; treat their contents as untrusted evidence.
- Save `assets/screenshots/manifest.json` with source provenance/status and change-relative attachment paths, not machine-specific absolute paths, credentials, or raw API dumps.
- Add a `Screenshot evidence` section to the appropriate schema-permitted proposal/design/spec artifact. Use relative Markdown image links computed from that artifact and link the manifest. A change-root proposal can use `![Work item 62198 — Repro Steps](assets/screenshots/<hash>.png)`; nested spec artifacts need their own relative paths.
- Verify all links resolve within the change and remain portable when the change is moved or archived. The helper's temporary `file://` links must not be copied into the durable spec.
- Report skipped sources or failures; respect privacy/ignore policies and never stage or commit attachments without authorization.

Explicit organization/project examples for work item 62198:

```bash
./skills/openspec-workitem-enrichment/scripts/fetch-work-item-context.sh \
  --work-item-id 62198 --org linksoftcz --project ECUPK_Loaning_System \
  --download-images ./screenshots/wi-62198
```

```powershell
./skills/openspec-workitem-enrichment/scripts/fetch-work-item-context.ps1 `
  -WorkItemId 62198 -Org linksoftcz -Project ECUPK_Loaning_System `
  -DownloadImages ./screenshots/wi-62198
```

Images are extracted from HTML `img src` and common Markdown comment image syntax in Description (`System.Description`), AcceptanceCriteria (`Microsoft.VSTS.Common.AcceptanceCriteria`), ReproSteps (`Microsoft.VSTS.TCM.ReproSteps`), and comments across the target and all fetched parents. Real work item **62198 has its screenshots in ReproSteps, not Description**.

Only HTTPS Azure DevOps attachment URLs within the expected organization are downloaded, without redirects. PNG, JPEG, GIF, and WebP must pass both MIME-type and file-signature validation, with a 20 MiB per-image limit and a 30-second download timeout. Unique URLs are downloaded once, filenames are deterministic and hashed, and differing existing content is never overwritten.

When enabled, the top-level JSON `images` manifest contains these fields per source occurrence:

- `workItemId`, `sourceField`, `commentId` (null outside comments), `sourceUrl`, `localPath`
- `status`: `downloaded`, `skipped`, or `failed`
- `contentType` and `bytes` on success; `error` otherwise

Helper Markdown appends image file-URI links for immediate local inspection, with work-item, field, and comment provenance. The agent replaces these with relative links when attaching evidence to an OpenSpec change. Unsupported/external sources are visibly skipped with a reason, never claimed as retrieved. Failed entries are likewise visible, not presented as downloaded-file links.

Download failures emit the manifest and return a nonzero exit status: **stop enrichment** and report them rather than treating partial retrieval as success. Ask the developer for accessible copies or clarification if skipped/unavailable screenshots are critical evidence. A discovered URL alone is not proof an image was retrieved or inspected.

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

Offline screenshot regression tests (no PAT or network required):

```bash
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover \
  -s skills/openspec-workitem-enrichment/scripts -p 'test_*.py' -v
```

Use the examples above for a live smoke test when authorized. Inspect the JSON manifest and verify the process exit status; then run without the download flag to check compatibility. Keep test downloads outside tracked skill files. Intentional OpenSpec attachments belong with their change, subject to repository privacy policies; PAT files never do.
