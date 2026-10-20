"""Offline tests: python3 scripts/test_fetch_findings.py."""
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import Mock, patch
import fetch_findings as f


class FindingsTests(unittest.TestCase):
    def test_pr_only_branch(self):
        scope, _ = f.select_scope([], [{'key': '123', 'branch': 'feature/test'}], branch='feature/test')
        self.assertEqual(scope, {'pullRequest': '123'})

    def test_ambiguous_analysis(self):
        with self.assertRaises(f.FetchError):
            f.select_scope([{'name': 'feature/test'}], [{'key': '123', 'branch': 'feature/test'}], branch='feature/test')

    def test_missing_analysis(self):
        with self.assertRaises(f.FetchError):
            f.select_scope([{'name': 'main'}], [], branch='feature/test')

    def test_token_sources(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'token.txt'
            path.write_text('file-token\n', encoding='utf-8')
            with patch.dict(os.environ, {'SONAR_TOKEN': 'environment-token', 'SONAR_TOKEN_FILE': str(path)}, clear=True):
                self.assertEqual(f.read_token(), 'environment-token')
                self.assertEqual(f.read_token(str(path)), 'file-token')
            with patch.dict(os.environ, {'SONAR_TOKEN_FILE': str(path)}, clear=True):
                self.assertEqual(f.read_token(), 'file-token')

    def test_all_pages(self):
        client = Mock()
        client.get.side_effect = [{'paging': {'total': 2}, 'issues': [{'key': 'a'}]}, {'paging': {'total': 2}, 'issues': [{'key': 'b'}]}]
        with tempfile.TemporaryDirectory() as directory:
            self.assertEqual(len(f.collect(client, Path(directory), 'issues/search', 'issues', {})), 2)

    def test_duplicate_rejected(self):
        client = Mock()
        client.get.return_value = {'paging': {'total': 2}, 'issues': [{'key': 'a'}]}
        with tempfile.TemporaryDirectory() as directory, self.assertRaises(f.FetchError):
            f.collect(client, Path(directory), 'issues/search', 'issues', {})

    def test_permission_failure_keeps_downloaded_page(self):
        client = Mock()
        client.get.side_effect = [{'paging': {'total': 2}, 'issues': [{'key': 'a'}]}, f.FetchError('HTTP 403')]
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaises(f.FetchError):
                f.collect(client, Path(directory), 'issues/search', 'issues', {})
            self.assertTrue((Path(directory) / 'issues.json').exists())

    def test_unsafe_urls_rejected(self):
        for url in ['http://sonar.example.com', 'https://user:pass@sonar.example.com', 'https://sonar.example.com?token=secret']:
            with self.assertRaises(f.FetchError):
                f.Client(url, 'test-token')

    def test_redirect_refused(self):
        self.assertIsNone(f.NoRedirect().redirect_request(None, None, 302, '', {}, 'https://other.example.com'))


if __name__ == '__main__':
    unittest.main()
