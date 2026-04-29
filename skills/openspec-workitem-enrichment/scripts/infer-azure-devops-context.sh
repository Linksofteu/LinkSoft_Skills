#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Infer Azure DevOps org, project, and repo from a git remote.

Usage:
  infer-azure-devops-context.sh [--repo-root PATH] [--remote-name origin] [--remote-url URL]

Options:
  --repo-root PATH   Repository root to inspect. Defaults to current directory.
  --remote-name NAME Git remote name to inspect. Defaults to origin.
  --remote-url URL   Parse this remote URL directly instead of reading git config.
  --help             Show this help text.

Output:
  JSON with org, project, repo, remoteName, remoteUrl, and collectionUri.
EOF
}

repo_root="$(pwd)"
remote_name="origin"
remote_url=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-root)
      repo_root="$2"
      shift 2
      ;;
    --remote-name)
      remote_name="$2"
      shift 2
      ;;
    --remote-url)
      remote_url="$2"
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

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required." >&2
  exit 1
fi

if [[ -z "$remote_url" ]]; then
  if ! command -v git >/dev/null 2>&1; then
    echo "git is required to inspect repository remotes." >&2
    exit 1
  fi

  if [[ ! -d "$repo_root" ]]; then
    echo "Repository root does not exist: $repo_root" >&2
    exit 1
  fi

  if ! remote_url="$(git -C "$repo_root" config --get "remote.${remote_name}.url")"; then
    echo "Could not read git remote '${remote_name}' from $repo_root" >&2
    exit 1
  fi
fi

python3 - "$remote_name" "$remote_url" <<'PY'
import json
import re
import sys
from urllib.parse import urlparse

remote_name = sys.argv[1]
remote_url = sys.argv[2].strip()

patterns = [
    re.compile(r"^https://dev\.azure\.com/(?P<org>[^/]+)/(?P<project>[^/]+)/_git/(?P<repo>[^/]+?)(?:\.git)?/?$", re.I),
    re.compile(r"^https://[^@]+@dev\.azure\.com/(?P<org>[^/]+)/(?P<project>[^/]+)/_git/(?P<repo>[^/]+?)(?:\.git)?/?$", re.I),
    re.compile(r"^git@ssh\.dev\.azure\.com:v3/(?P<org>[^/]+)/(?P<project>[^/]+)/(?P<repo>[^/]+?)(?:\.git)?$", re.I),
    re.compile(r"^ssh://git@ssh\.dev\.azure\.com/v3/(?P<org>[^/]+)/(?P<project>[^/]+)/(?P<repo>[^/]+?)(?:\.git)?/?$", re.I),
    re.compile(r"^https://(?P<org>[^./]+)\.visualstudio\.com/(?P<project>[^/]+)/_git/(?P<repo>[^/]+?)(?:\.git)?/?$", re.I),
]

match = None
for pattern in patterns:
    match = pattern.match(remote_url)
    if match:
        break

if not match:
    print(json.dumps({
        "error": "Could not infer Azure DevOps org/project from remote URL.",
        "remoteName": remote_name,
        "remoteUrl": remote_url,
    }, indent=2))
    sys.exit(1)

data = match.groupdict()
org = data["org"]
project = data["project"]
repo = data["repo"]
if repo.lower().endswith(".git"):
    repo = repo[:-4]

if ".visualstudio.com/" in remote_url.lower():
    collection_uri = f"https://{org}.visualstudio.com"
else:
    collection_uri = f"https://dev.azure.com/{org}"

print(json.dumps({
    "org": org,
    "project": project,
    "repo": repo,
    "remoteName": remote_name,
    "remoteUrl": remote_url,
    "collectionUri": collection_uri,
    "projectUri": f"{collection_uri}/{project}",
}, indent=2))
PY
