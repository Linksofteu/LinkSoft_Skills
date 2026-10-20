#!/usr/bin/env python3
"""Read-only SonarQube findings export; standard library only."""
import argparse
from collections import Counter
import json
import os
from pathlib import Path
import sys
import tempfile
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode, urlsplit
from urllib.request import Request, build_opener, HTTPRedirectHandler


class FetchError(Exception):
    pass


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def read_token(token_file=None):
    path = token_file or (None if os.environ.get('SONAR_TOKEN') else os.environ.get('SONAR_TOKEN_FILE'))
    token = Path(path).expanduser().read_text(encoding='utf-8-sig').strip() if path else os.environ.get('SONAR_TOKEN', '').strip()
    if not token or any(c.isspace() for c in token):
        raise FetchError('Provide SONAR_TOKEN or a token file containing one non-empty token.')
    return token


class Client:
    def __init__(self, url, token):
        parsed = urlsplit(url)
        if parsed.scheme != 'https' or not parsed.hostname or parsed.username or parsed.password or parsed.query or parsed.fragment:
            raise FetchError('Use an HTTPS server URL without credentials, query, or fragment.')
        self.url = url.rstrip('/')
        self.token = token
        self.opener = build_opener(NoRedirect())

    def get(self, endpoint, params):
        request = Request(self.url + '/api/' + endpoint + '?' + urlencode(params),
                          headers={'Authorization': 'Bearer ' + self.token, 'Accept': 'application/json'})
        try:
            with self.opener.open(request, timeout=60) as response:
                return json.load(response)
        except HTTPError as error:
            # Do not echo remote bodies, headers or requests (may contain secrets).
            raise FetchError(f'{endpoint}: HTTP {error.code}; check permissions, scope, and server API documentation.') from None
        except (URLError, TimeoutError, ValueError):
            raise FetchError(f'{endpoint}: network/TLS error or invalid JSON response.') from None


def save(directory, name, data):
    (directory / (name + '.json')).write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding='utf-8')


def select_scope(branches, prs, branch=None, pr=None, branch_only=False):
    if pr:
        matches = [('pullRequest', p) for p in prs if p['key'] == pr]
    else:
        matches = [('branch', b) for b in branches if b['name'] == branch]
        if not branch_only:
            matches += [('pullRequest', p) for p in prs if p['branch'] == branch]
    if len(matches) != 1:
        raise FetchError('Analysis missing or ambiguous. Inspect discovery files; specify --pull-request or --branch-analysis explicitly.')
    kind, analysis = matches[0]
    return {kind: analysis['key'] if kind == 'pullRequest' else analysis['name']}, analysis


def collect(client, directory, endpoint, field, params):
    items, seen, total = [], set(), None
    page = 1
    while True:
        data = client.get(endpoint, {**params, 'ps': 100, 'p': page})
        save(directory, f'{field}-page-{page}', data)
        reported = data.get('paging', {}).get('total', data.get('total'))
        if not isinstance(reported, int) or reported < 0 or (total is not None and reported != total):
            raise FetchError(f'{field}: missing/changing total; retry after analysis completes.')
        total = reported
        batch = data[field]
        for item in batch:
            if item['key'] in seen:
                raise FetchError(f'{field}: duplicate key across pages; export incomplete.')
            seen.add(item['key'])
            items.append(item)
        save(directory, field, items)
        if len(items) == total:
            return items
        if not batch or len(items) > total:
            raise FetchError(f'{field}: pagination did not match reported total.')
        page += 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--url', required=True)
    parser.add_argument('--project', required=True)
    scope = parser.add_mutually_exclusive_group(required=True)
    scope.add_argument('--branch')
    scope.add_argument('--pull-request')
    parser.add_argument('--branch-analysis', action='store_true', help='Use branch analysis only, not matching PRs')
    parser.add_argument('--token-file', help='UTF-8 token file; otherwise SONAR_TOKEN or SONAR_TOKEN_FILE')
    parser.add_argument('--output', help='New output directory; default is a unique OS temporary directory')
    args = parser.parse_args()
    if args.branch_analysis and not args.branch:
        parser.error('--branch-analysis requires --branch')
    directory = None
    try:
        client = Client(args.url, read_token(args.token_file))
        if args.output:
            directory = Path(args.output).expanduser()
            directory.mkdir(parents=True, exist_ok=False)
        else:
            directory = Path(tempfile.mkdtemp(prefix='sonar-findings-'))
        branches = client.get('project_branches/list', {'project': args.project})
        save(directory, 'branches', branches)
        prs = client.get('project_pull_requests/list', {'project': args.project})
        save(directory, 'pull-requests', prs)
        selected, analysis = select_scope(branches['branches'], prs['pullRequests'], args.branch, args.pull_request, args.branch_analysis)
        manifest = {'server': client.url, 'project': args.project, 'scope': selected, 'analysis': analysis, 'counts': {}, 'errors': []}
        for endpoint, field, project_param in [('issues/search', 'issues', 'componentKeys'), ('hotspots/search', 'hotspots', 'project')]:
            try:
                params = {project_param: args.project, **selected}
                if field == 'issues':
                    params['additionalFields'] = '_all'
                items = collect(client, directory, endpoint, field, params)
                manifest['counts'][field] = len(items)
                manifest[field + 'Statuses'] = dict(Counter(item.get('status', 'unknown') for item in items))
                if field == 'hotspots':
                    details = []
                    for item in items:
                        try:
                            details.append(client.get('hotspots/show', {'hotspot': item['key']}))
                        except FetchError as error:
                            manifest['errors'].append(str(error))
                    save(directory, 'hotspot-details', details)
            except FetchError as error:
                manifest['errors'].append(str(error))
        try:
            save(directory, 'quality-gate', client.get('qualitygates/project_status', {'projectKey': args.project, **selected}))
        except FetchError as error:
            manifest['errors'].append(str(error))
        manifest['complete'] = not manifest['errors']
        save(directory, 'manifest', manifest)
        print(json.dumps({'output': str(directory), **manifest}, ensure_ascii=False, indent=2))
        return 0 if manifest['complete'] else 2
    except (FetchError, OSError, KeyError, TypeError) as error:
        # Avoid dumping arbitrary exception content or credentials.
        message = str(error) if isinstance(error, FetchError) else 'File access or API schema error; check inputs and server documentation.'
        print(message, file=sys.stderr)
        if directory:
            print(f'Partial files: {directory}', file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
