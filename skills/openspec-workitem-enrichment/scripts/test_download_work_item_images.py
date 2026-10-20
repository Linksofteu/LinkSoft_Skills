"""Offline regression tests: python3 -m unittest discover -s <scripts> -p 'test_*.py'."""

from email.message import Message
import io
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch
import urllib.error
import urllib.request

spec = importlib.util.spec_from_file_location('images', Path(__file__).with_name('download-work-item-images.py'))
images = importlib.util.module_from_spec(spec)
spec.loader.exec_module(images)

ORG = 'https://dev.azure.com/example'
URL = ORG + '/project/_apis/wit/attachments/1234-abcd?fileName=image.png'
PNG = b'\x89PNG\r\n\x1a\nexample'


class Response(io.BytesIO):
    def __init__(self, body=PNG, mime='image/png'):
        super().__init__(body)
        self.headers = Message()
        self.headers['Content-Type'] = mime


class Opener:
    def __init__(self, body=PNG, mime='image/png'):
        self.body, self.mime, self.requests = body, mime, []

    def open(self, request, timeout):
        self.requests.append(request)
        return Response(self.body, self.mime)


def context(*sources):
    return {'structuredMarkdown': '## Bug #62198', 'imageSources': list(sources)}


def source(url=URL, field='Microsoft.VSTS.TCM.ReproSteps', comment=None, item=62198):
    return dict(workItemId=item, sourceField=field, commentId=comment, html=f'<img src="{url}">')


class DownloadTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.opener = Opener()

    def enrich(self, data, opener=None):
        return images.enrich(data, self.temp.name, ORG, 'secret', opener or self.opener)

    def test_html_and_markdown_extract_and_deduplicate(self):
        self.assertEqual(images.extract_urls('<IMG SRC="a?x=1&amp;y=2"><img src=b> ![x](<c d>) ![x](b)'), ['a?x=1&y=2', 'b', 'c d'])

    def test_repro_image_traceability_and_markdown(self):
        result = self.enrich(context(source()))
        entry = result['images'][0]
        self.assertEqual(entry['status'], 'downloaded')
        self.assertEqual(entry['workItemId'], 62198)
        self.assertEqual(entry['sourceField'], 'Microsoft.VSTS.TCM.ReproSteps')
        self.assertEqual(Path(entry['localPath']).read_bytes(), PNG)
        self.assertIn(Path(entry['localPath']).as_uri(), result['structuredMarkdown'])
        self.assertNotIn('imageSources', result)

    def test_duplicate_images_keep_provenance_and_download_once(self):
        result = self.enrich(context(source(), source(field='comment', comment=42, item=12)))
        self.assertEqual(len(self.opener.requests), 1)
        self.assertEqual(len(result['images']), 2)
        self.assertEqual(result['images'][1]['commentId'], 42)
        self.assertEqual(result['images'][0]['localPath'], result['images'][1]['localPath'])

    def test_untrusted_urls_never_receive_credentials(self):
        urls = ['https://evil.test/x.png', URL.replace('/example/', '/other/'), URL.replace('https:', 'http:'), URL.replace('dev.azure.com', 'dev.azure.com.evil.test'), 'data:image/png;base64,abc', ORG + '/_apis/other/123', URL.replace('dev.azure.com', 'user@dev.azure.com')]
        result = self.enrich(context(*(source(url) for url in urls)))
        self.assertTrue(all(entry['status'] == 'skipped' for entry in result['images']))
        self.assertEqual(self.opener.requests, [])

    def test_legacy_host_same_organization(self):
        self.assertTrue(images.trusted_attachment('https://example.visualstudio.com/project/_apis/wit/attachments/abcd', ORG))
        self.assertTrue(images.trusted_attachment(URL, 'https://example.visualstudio.com'))

    def test_path_traversal_rejected(self):
        for path in ['/example/../other/', '/example/%2e%2e/other/', '/example/%2Fother/', '/example/%252e%252e/other/']:
            self.assertFalse(images.trusted_attachment('https://dev.azure.com' + path + '_apis/wit/attachments/abcd', ORG))

    def test_relative_attachment(self):
        self.assertEqual(self.enrich(context(source('/example/project/_apis/wit/attachments/abcd')))['images'][0]['status'], 'downloaded')

    def test_wrong_mime(self):
        self.assertEqual(self.enrich(context(source()), Opener(mime='text/html'))['images'][0]['status'], 'failed')

    def test_wrong_signature(self):
        self.assertEqual(self.enrich(context(source()), Opener(body=b'not png'))['images'][0]['status'], 'failed')

    def test_other_supported_formats(self):
        for mime, data in [('image/jpeg', b'\xff\xd8\xfftest'), ('image/gif', b'GIF89atest'), ('image/webp', b'RIFF1234WEBPtest')]:
            self.assertEqual(self.enrich(context(source()), Opener(body=data, mime=mime))['images'][0]['status'], 'downloaded')

    def test_http_failure_reports_status_without_response_body(self):
        with patch.object(self.opener, 'open', side_effect=urllib.error.HTTPError(URL, 403, 'secret', {}, None)):
            result = self.enrich(context(source()))
        self.assertIn('HTTP 403', result['images'][0]['error'])
        self.assertNotIn('secret', json.dumps(result))

    def test_output_symlink_not_followed(self):
        result = self.enrich(context(source()))
        path = Path(result['images'][0]['localPath'])
        path.unlink()
        target = Path(self.temp.name) / 'untouched'
        target.write_bytes(b'private')
        path.symlink_to(target)
        self.assertEqual(self.enrich(context(source()))['images'][0]['status'], 'failed')
        self.assertEqual(target.read_bytes(), b'private')

    def test_svg_not_downloaded(self):
        self.assertEqual(self.enrich(context(source()), Opener(mime='image/svg+xml'))['images'][0]['status'], 'failed')

    def test_size_limit(self):
        with patch.object(images, 'MAX_BYTES', 8):
            self.assertEqual(self.enrich(context(source()))['images'][0]['status'], 'failed')

    def test_no_images(self):
        self.assertEqual(self.enrich(context())['images'], [])
        self.assertEqual(self.opener.requests, [])

    def test_repeat_run_preserves_existing_identical_image(self):
        first = self.enrich(context(source()))
        second = self.enrich(context(source()))
        self.assertEqual(first['images'], second['images'])

    def test_different_existing_content_not_overwritten(self):
        first = self.enrich(context(source()))
        path = Path(first['images'][0]['localPath'])
        path.write_bytes(b'existing')
        self.assertEqual(self.enrich(context(source()))['images'][0]['status'], 'failed')
        self.assertEqual(path.read_bytes(), b'existing')

    def test_errors_do_not_leak_credentials(self):
        with patch.object(self.opener, 'open', side_effect=ValueError('secret')):
            result = self.enrich(context(source()))
        self.assertNotIn('secret', json.dumps(result))

    def test_redirect_refused(self):
        handler = images.NoRedirect()
        request = urllib.request.Request(URL, headers={'Authorization': 'Basic secret'})
        self.assertIsNone(handler.redirect_request(request, None, 302, 'redirect', {}, 'https://evil.test'))

    def test_cli_failure_emits_manifest_and_nonzero_exit(self):
        pat = Path(self.temp.name) / 'pat.env'
        pat.write_text('AZURE_DEVOPS_PAT=test\n')
        # Invalid port fails before any network request.
        cmd = ['python3', str(Path(images.__file__)), '--output-dir', self.temp.name, '--org-url', ORG, '--pat-file', str(pat)]
        result = subprocess.run(cmd, input=json.dumps(context(source(URL.replace('dev.azure.com', 'dev.azure.com:bad')))), text=True, capture_output=True)
        self.assertEqual(result.returncode, 1)
        self.assertEqual(json.loads(result.stdout)['images'][0]['status'], 'failed')


if __name__ == '__main__':
    unittest.main()
