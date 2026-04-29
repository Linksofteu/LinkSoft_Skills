#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Fetch Azure DevOps work item context using Azure CLI and az boards only.

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

Output:
  JSON containing inferred context, WIQL confirmation, the parent chain from
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

for cmd in az python3; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Required command not found: $cmd" >&2
    exit 1
  fi
done

if ! az account show >/dev/null 2>&1; then
  echo "Azure CLI is not authenticated. Run 'az login' first." >&2
  exit 1
fi

if ! az boards -h >/dev/null 2>&1; then
  echo "Azure DevOps CLI extension is not available. Run 'az extension add --name azure-devops' first." >&2
  exit 1
fi

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

org_url="$(python3 -c 'import json,sys; data=json.load(sys.stdin); print(data.get("collectionUri") or ("https://dev.azure.com/" + data["org"]))' <<<"$context_json")"

az devops configure --defaults organization="$org_url" project="$project" >/dev/null

wiql="SELECT [System.Id], [System.Title], [System.State] FROM WorkItems WHERE [System.Id] = $work_item_id ORDER BY [System.ChangedDate] DESC"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

az boards query --wiql "$wiql" --org "$org_url" --project "$project" --output json > "$tmp_dir/wiql.json"

fields="System.Id,System.Title,System.WorkItemType,System.State,System.Reason,System.Description,Microsoft.VSTS.Common.AcceptanceCriteria,Microsoft.VSTS.TCM.ReproSteps,System.AssignedTo,System.CreatedBy,System.AreaPath,System.IterationPath,System.Tags,System.ChangedDate,System.CreatedDate,System.CommentCount,Microsoft.VSTS.Common.Priority,Microsoft.VSTS.Common.ValueArea,Microsoft.VSTS.Common.BusinessValue"

current_id="$work_item_id"
depth=0
seen_ids=()

while [[ -n "$current_id" && "$depth" -lt "$max_parent_depth" ]]; do
  if printf '%s\n' "${seen_ids[@]:-}" | grep -Fxq "$current_id"; then
    echo "Detected parent cycle at work item $current_id" >&2
    exit 1
  fi

  seen_ids+=("$current_id")

  az boards work-item show \
    --id "$current_id" \
    --org "$org_url" \
    --fields "$fields" \
    --expand none \
    --output json > "$tmp_dir/work-item-$current_id.json"

  az boards work-item relation show \
    --id "$current_id" \
    --org "$org_url" \
    --output json > "$tmp_dir/relation-$current_id.json"

  az devops invoke \
    --organization "$org_url" \
    --area wit \
    --resource comments \
    --route-parameters project="$project" workItemId="$current_id" \
    --api-version 7.1-preview \
    --output json > "$tmp_dir/comments-$current_id.json"

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

python3 - "$context_json" "$tmp_dir" "$work_item_id" "$org_url" "$project" "$max_parent_depth" <<'PY'
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
            'id': comment.get('id'),
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
    "defaultsConfigured": True,
    "wiql": load("wiql.json"),
    "hierarchy": chain_top_down,
    "structuredMarkdown": to_markdown(chain_top_down),
}

print(json.dumps(result, indent=2))
PY
