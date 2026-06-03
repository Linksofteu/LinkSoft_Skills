#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Fetch Azure DevOps work item context using the Azure DevOps REST API.

Usage:
  fetch-work-item-context.sh --work-item-id ID [options]

Options:
  --work-item-id ID       Required numeric work item id.
  --org NAME             Azure DevOps organization. Inferred from git if omitted.
  --project NAME         Azure DevOps project. Inferred from git if omitted.
  --repo-root PATH       Repository root for git remote inference. Defaults to current directory.
  --remote-name NAME     Git remote name to inspect. Defaults to origin.
  --max-parent-depth N   Maximum number of parent levels to follow. Defaults to 10.
  --help                 Show this help text.

Authentication:
  Requires ~/.config/linksoft-skills/azure-devops.env containing exactly:
    AZURE_DEVOPS_PAT=<your Azure DevOps PAT>

Output:
  JSON containing inferred context, REST retrieval details, the parent chain from
  topmost parent to target work item, comments for each item, and a
  structuredMarkdown field ready for spec enrichment.
EOF
}

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(pwd)"
remote_name="origin"
work_item_id=""
org=""
project=""
max_parent_depth=10

while [[ $# -gt 0 ]]; do
  case "$1" in
    --work-item-id)
      work_item_id="$2"
      shift 2
      ;;
    --org)
      org="$2"
      shift 2
      ;;
    --project)
      project="$2"
      shift 2
      ;;
    --repo-root)
      repo_root="$2"
      shift 2
      ;;
    --remote-name)
      remote_name="$2"
      shift 2
      ;;
    --max-parent-depth)
      max_parent_depth="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "$work_item_id" || ! "$work_item_id" =~ ^[0-9]+$ ]]; then
  echo "--work-item-id is required and must be numeric." >&2
  exit 2
fi

if [[ ! "$max_parent_depth" =~ ^[0-9]+$ ]]; then
  echo "--max-parent-depth must be numeric." >&2
  exit 2
fi

for cmd in curl python3; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Required command not found: $cmd" >&2
    exit 1
  fi
done

pat_file="$HOME/.config/linksoft-skills/azure-devops.env"

pat_file_error() {
  cat >&2 <<EOF
Azure DevOps PAT configuration file was not found or is invalid.

Create this exact file:
  $pat_file

If the directory does not exist, create it with:
  mkdir -p "$HOME/.config/linksoft-skills"

The file must contain exactly one environment variable assignment, on one line:
  AZURE_DEVOPS_PAT=<your Azure DevOps PAT>

One way to create the file is:
  printf 'AZURE_DEVOPS_PAT=<your Azure DevOps PAT>\n' > "$pat_file"

Example file contents:
  AZURE_DEVOPS_PAT=abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789AZDOabcd

Do not add quotes around the token. Do not commit this file to git.

When creating the PAT in Azure DevOps, grant the minimum required scope:
  Work Items: Read

This corresponds to the Azure DevOps REST API vso.work permission, which allows reading work items, comments, queries, boards, area paths, and iteration paths. The token does not need write permissions, Code permissions, Build permissions, Packaging permissions, or full access for this skill.
EOF
}

if [[ ! -f "$pat_file" ]]; then
  pat_file_error
  exit 1
fi

azure_devops_pat="$(python3 - "$pat_file" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
lines = [line.strip() for line in path.read_text(encoding='utf-8').splitlines()]
if len(lines) != 1 or not lines[0].startswith('AZURE_DEVOPS_PAT='):
    sys.exit(2)
value = lines[0].split('=', 1)[1].strip()
if (value.startswith('"') and value.endswith('"')) or (value.startswith("'") and value.endswith("'")):
    sys.exit(2)
if not value:
    sys.exit(2)
print(value)
PY
)" || {
  pat_file_error
  exit 1
}

if [[ -z "$org" || -z "$project" ]]; then
  context_json="$($script_dir/infer-azure-devops-context.sh --repo-root "$repo_root" --remote-name "$remote_name")"
  if [[ -z "$org" ]]; then
    org="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["org"])' <<<"$context_json")"
  fi
  if [[ -z "$project" ]]; then
    project="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["project"])' <<<"$context_json")"
  fi
else
  context_json="$(python3 -c 'import json,sys; print(json.dumps({"org": sys.argv[1], "project": sys.argv[2]}, indent=2))' "$org" "$project")"
fi

org_url="$(python3 -c 'import json,sys; data=json.load(sys.stdin); print((data.get("collectionUri") or ("https://dev.azure.com/" + data["org"])).rstrip("/"))' <<<"$context_json")"

wiql="SELECT [System.Id], [System.Title], [System.State] FROM WorkItems WHERE [System.Id] = $work_item_id ORDER BY [System.ChangedDate] DESC"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

encoded_project="$(python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=""))' "$project")"

api_get() {
  local url="$1"
  local output_file="$2"
  local status_file="$tmp_dir/http-status.txt"
  local body_file="$tmp_dir/http-body.txt"

  local status
  status="$(curl --silent --show-error --location \
    --user ":$azure_devops_pat" \
    --header "Accept: application/json" \
    --output "$body_file" \
    --write-out "%{http_code}" \
    "$url")"
  printf '%s' "$status" > "$status_file"

  if [[ "$status" -lt 200 || "$status" -ge 300 ]]; then
    echo "Azure DevOps REST API request failed with HTTP $status: $url" >&2
    python3 - "$body_file" >&2 <<'PY'
import json
import pathlib
import sys

body = pathlib.Path(sys.argv[1]).read_text(encoding='utf-8', errors='replace').strip()
if not body:
    sys.exit(0)
try:
    data = json.loads(body)
    message = data.get('message') or data.get('Message') or body
except Exception:
    message = body
print(message)
PY
    exit 1
  fi

  mv "$body_file" "$output_file"
}

current_id="$work_item_id"
depth=0
seen_ids=()

while [[ -n "$current_id" && "$depth" -lt "$max_parent_depth" ]]; do
  if printf '%s\n' "${seen_ids[@]:-}" | grep -Fxq "$current_id"; then
    echo "Detected parent cycle at work item $current_id" >&2
    exit 1
  fi

  seen_ids+=("$current_id")

  item_url="$org_url/$encoded_project/_apis/wit/workitems/$current_id?%24expand=relations&api-version=7.1"
  comments_url="$org_url/$encoded_project/_apis/wit/workItems/$current_id/comments?%24top=200&order=asc&api-version=7.1-preview.4"

  api_get "$item_url" "$tmp_dir/work-item-$current_id.json"
  cp "$tmp_dir/work-item-$current_id.json" "$tmp_dir/relation-$current_id.json"
  api_get "$comments_url" "$tmp_dir/comments-$current_id.json"

  next_id="$(python3 - "$tmp_dir/relation-$current_id.json" <<'PY'
import json
import re
import sys

data = json.load(open(sys.argv[1], 'r', encoding='utf-8'))
relations = data.get('relations') or []
for relation in relations:
    rel = relation.get('rel', '')
    name = ((relation.get('attributes') or {}).get('name')) or ''
    if rel == 'System.LinkTypes.Hierarchy-Reverse' or name == 'Parent':
        url = relation.get('url', '')
        match = re.search(r'/workItems/(\d+)$', url)
        if match:
            print(match.group(1))
            sys.exit(0)
sys.exit(0)
PY
)"

  current_id="$next_id"
  depth=$((depth + 1))
done

python3 - "$context_json" "$tmp_dir" "$work_item_id" "$org_url" "$project" "$max_parent_depth" "$wiql" <<'PY'
import json
import html
from html.parser import HTMLParser
import pathlib
import re
import sys

context = json.loads(sys.argv[1])
tmp_dir = pathlib.Path(sys.argv[2])
work_item_id = int(sys.argv[3])
org_url = sys.argv[4]
project = sys.argv[5]
max_parent_depth = int(sys.argv[6])
wiql = sys.argv[7]

class HtmlToText(HTMLParser):
    def __init__(self):
        super().__init__()
        self.parts = []
    def handle_starttag(self, tag, attrs):
        if tag in {"br", "p", "div", "li", "ul", "ol"}:
            self.parts.append("\n")
    def handle_endtag(self, tag):
        if tag in {"p", "div", "li"}:
            self.parts.append("\n")
    def handle_data(self, data):
        self.parts.append(data)

def html_to_text(value):
    if not value:
        return ""
    parser = HtmlToText()
    parser.feed(html.unescape(value))
    text = ''.join(parser.parts)
    text = re.sub(r'\r', '', text)
    text = re.sub(r'\n\s*\n+', '\n\n', text)
    return text.strip()

def load(name):
    return json.loads((tmp_dir / name).read_text(encoding='utf-8'))

def parent_id_from_relations(relations_data):
    relations = relations_data.get('relations') or []
    for relation in relations:
        rel = relation.get('rel', '')
        name = ((relation.get('attributes') or {}).get('name')) or ''
        if rel == 'System.LinkTypes.Hierarchy-Reverse' or name == 'Parent':
            url = relation.get('url', '')
            match = re.search(r'/workItems/(\d+)$', url)
            if match:
                return int(match.group(1))
    return None

def normalize_identity(value):
    if isinstance(value, dict):
        name = value.get('displayName') or value.get('uniqueName') or ''
        email = value.get('uniqueName') or ''
        return {'displayName': name, 'uniqueName': email}
    if isinstance(value, str):
        return {'displayName': value, 'uniqueName': value}
    return None

def normalize_comments(data):
    comments = []
    for comment in data.get('comments', []):
        comments.append({
            'id': comment.get('id') or comment.get('commentId'),
            'text': html_to_text(comment.get('text') or ''),
            'createdDate': comment.get('createdDate'),
            'modifiedDate': comment.get('modifiedDate'),
            'createdBy': normalize_identity(comment.get('createdBy')),
        })
    return comments

def item_to_summary(item_data, relation_data, comments_data):
    fields = item_data.get('fields', {})
    return {
        'id': item_data.get('id'),
        'url': item_data.get('url'),
        'type': fields.get('System.WorkItemType'),
        'title': fields.get('System.Title'),
        'state': fields.get('System.State'),
        'reason': fields.get('System.Reason'),
        'priority': fields.get('Microsoft.VSTS.Common.Priority'),
        'valueArea': fields.get('Microsoft.VSTS.Common.ValueArea'),
        'businessValue': fields.get('Microsoft.VSTS.Common.BusinessValue'),
        'areaPath': fields.get('System.AreaPath'),
        'iterationPath': fields.get('System.IterationPath'),
        'assignedTo': normalize_identity(fields.get('System.AssignedTo')),
        'createdBy': normalize_identity(fields.get('System.CreatedBy')),
        'createdDate': fields.get('System.CreatedDate'),
        'changedDate': fields.get('System.ChangedDate'),
        'tags': fields.get('System.Tags'),
        'description': html_to_text(fields.get('System.Description') or ''),
        'acceptanceCriteria': html_to_text(fields.get('Microsoft.VSTS.Common.AcceptanceCriteria') or ''),
        'reproSteps': html_to_text(fields.get('Microsoft.VSTS.TCM.ReproSteps') or ''),
        'commentCount': fields.get('System.CommentCount'),
        'parentId': parent_id_from_relations(relation_data),
        'comments': normalize_comments(comments_data),
    }

def to_markdown(items):
    blocks = []
    for item in items:
        blocks.append(f"## {item.get('type') or 'Work Item'}: {item.get('title') or 'Untitled'} (#{item.get('id')})")
        description = item.get('description') or ''
        acceptance = item.get('acceptanceCriteria') or ''
        comments = item.get('comments') or []
        if description:
            blocks.append("### Description")
            blocks.append(description)
            blocks.append("")
        if acceptance:
            blocks.append("### Acceptance Criteria")
            blocks.append(acceptance)
            blocks.append("")
        if comments:
            blocks.append("### Comments")
            for comment in comments:
                author = (comment.get('createdBy') or {}).get('displayName') or 'Unknown'
                created = comment.get('createdDate') or 'Unknown date'
                text = comment.get('text') or ''
                blocks.append(f"- {author} ({created}): {text}")
        blocks.append("")
    return '\n'.join(blocks).strip()

chain = []
current = work_item_id
visited = set()

while current and current not in visited and len(chain) < max_parent_depth:
    visited.add(current)
    item_data = load(f'work-item-{current}.json')
    relation_data = load(f'relation-{current}.json')
    comments_data = load(f'comments-{current}.json')
    summary = item_to_summary(item_data, relation_data, comments_data)
    chain.append(summary)
    current = summary['parentId']

chain_top_down = list(reversed(chain))

result = {
    "context": context,
    "workItemId": work_item_id,
    "organization": org_url,
    "project": project,
    "defaultsConfigured": False,
    "retrieval": {
        "method": "Azure DevOps REST API",
        "workItemEndpoint": "/_apis/wit/workitems/{id}?$expand=relations&api-version=7.1",
        "commentsEndpoint": "/_apis/wit/workItems/{id}/comments?api-version=7.1-preview.4",
        "patFile": "~/.config/linksoft-skills/azure-devops.env",
    },
    "wiql": wiql,
    "hierarchy": chain_top_down,
    "structuredMarkdown": to_markdown(chain_top_down),
}

print(json.dumps(result, indent=2))
PY
