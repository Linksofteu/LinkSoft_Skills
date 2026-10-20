#!/usr/bin/env python3
"""Enrich context JSON on stdin with opt-in embedded screenshot downloads."""

import argparse
import base64
import hashlib
import json
from html.parser import HTMLParser
from pathlib import Path
import re
import sys
import urllib.parse
import urllib.error
import urllib.request

MAX_BYTES = 20 * 1024 * 1024
EXTENSIONS = {"image/png": ".png", "image/jpeg": ".jpg", "image/gif": ".gif", "image/webp": ".webp"}


class ImageParser(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.urls = []

    def handle_starttag(self, tag, attrs):
        if tag == "img":
            src = dict(attrs).get("src")
            if src:
                self.urls.append(src)


def extract_urls(text):
    parser = ImageParser()
    parser.feed(text or "")
    markdown = re.findall(r'!\[[^\]]*\]\(\s*(<[^>]+>|[^\s)]+)(?:\s+"[^"]*")?\s*\)', text or "")
    return list(dict.fromkeys(parser.urls + [url.strip("<>") for url in markdown]))


def trusted_attachment(url, org_url):
    parsed = urllib.parse.urlsplit(url)
    org = urllib.parse.urlsplit(org_url)
    if parsed.scheme != "https" or parsed.username or parsed.password or parsed.port not in (None, 443):
        return False
    if org.hostname == "dev.azure.com":
        name = org.path.strip("/").split("/")[0]
    elif org.hostname and org.hostname.endswith(".visualstudio.com"):
        name = org.hostname.removesuffix(".visualstudio.com")
    else:
        return False
    path = parsed.path
    decoded = urllib.parse.unquote(path)
    if any(segment in ('.', '..') for segment in decoded.split('/')) or '\\' in decoded:
        return False
    if re.search(r'%2f|%5c|%25', path, re.IGNORECASE):
        return False
    if parsed.hostname == "dev.azure.com":
        if not path.lower().startswith(f"/{name.lower()}/"):
            return False
    elif parsed.hostname != f"{name.lower()}.visualstudio.com":
        return False
    return bool(re.search(r"/_apis/wit/attachments/[0-9a-f-]+$", path, re.IGNORECASE))


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        # Never forward the PAT to a redirect destination.
        return None


def download(url, pat, opener):
    auth = base64.b64encode((":" + pat).encode()).decode()
    request = urllib.request.Request(url, headers={"Authorization": "Basic " + auth})
    with opener.open(request, timeout=30) as response:
        mime = response.headers.get_content_type()
        if mime not in EXTENSIONS:
            raise ValueError("Unsupported image content type")
        data = response.read(MAX_BYTES + 1)
        if len(data) > MAX_BYTES:
            raise ValueError("Image exceeds 20 MiB limit")
        valid = {
            "image/png": data.startswith(b"\x89PNG\r\n\x1a\n"),
            "image/jpeg": data.startswith(b"\xff\xd8\xff"),
            "image/gif": data.startswith((b"GIF87a", b"GIF89a")),
            "image/webp": data.startswith(b"RIFF") and data[8:12] == b"WEBP",
        }
        if not valid[mime]:
            raise ValueError("Image signature does not match content type")
        return data, mime


def enrich(context, output_dir, org_url, pat, opener=None):
    opener = opener or urllib.request.build_opener(NoRedirect())
    output_dir = Path(output_dir).resolve()
    output_dir.mkdir(parents=True, exist_ok=True)
    images, cache = [], {}
    for source in context.pop("imageSources", []):
        for src in extract_urls(source.get("html")):
            entry = {key: source.get(key) for key in ("workItemId", "sourceField", "commentId")}
            entry.update(sourceUrl=src, localPath=None, status="skipped")
            try:
                url = urllib.parse.urljoin(org_url.rstrip("/") + "/", src)
                entry['sourceUrl'] = url
                if not trusted_attachment(url, org_url):
                    entry["error"] = "Not an HTTPS attachment in the expected Azure DevOps organization"
                elif url in cache:
                    entry.update(cache[url])
                else:
                    data, mime = download(url, pat, opener)
                    name = hashlib.sha256(url.encode()).hexdigest() + EXTENSIONS[mime]
                    path = output_dir / name
                    # Exclusive creation prevents following symlinks or overwriting user files.
                    try:
                        with path.open("xb") as target:
                            target.write(data)
                    except FileExistsError:
                        if path.is_symlink() or path.read_bytes() != data:
                            raise ValueError("Output path already exists with different content")
                    result = dict(localPath=str(path), status="downloaded", contentType=mime, bytes=len(data))
                    cache[url] = result
                    entry.update(result)
            except urllib.error.HTTPError as exc:
                entry.update(status="failed", error=f"Image request failed with HTTP {exc.code}; redirects are not followed")
            except Exception as exc:
                # Never emit response bodies, credentials, or server-controlled exception text.
                entry.update(status="failed", error=f"Image download failed ({type(exc).__name__})")
            images.append(entry)
    context["images"] = images
    if images:
        lines = [context.get("structuredMarkdown", ""), "", "### Embedded screenshots"]
        for image in images:
            label = f"Work item {image['workItemId']}, {image['sourceField']}"
            if image["commentId"] is not None:
                label += f", comment {image['commentId']}"
            if image["status"] == "downloaded":
                lines.append(f"![{label}](<{Path(image['localPath']).as_uri()}>)")
            else:
                lines.append(f"- {label}: {image['status']} — {image['error']}")
        context["structuredMarkdown"] = "\n".join(lines)
    return context


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", required=True)
    parser.add_argument("--org-url", required=True)
    parser.add_argument("--pat-file", required=True)
    args = parser.parse_args()
    lines = Path(args.pat_file).read_text(encoding="utf-8").splitlines()
    if len(lines) != 1 or not lines[0].startswith("AZURE_DEVOPS_PAT="):
        parser.error("Invalid PAT file; expected exactly one AZURE_DEVOPS_PAT assignment")
    pat = lines[0].split("=", 1)[1].strip()
    if not pat or pat.startswith(('"', "'")):
        parser.error("Invalid PAT value")
    context = enrich(json.load(sys.stdin), args.output_dir, args.org_url, pat)
    print(json.dumps(context, indent=2))
    return 1 if any(image["status"] == "failed" for image in context["images"]) else 0


if __name__ == "__main__":
    sys.exit(main())
