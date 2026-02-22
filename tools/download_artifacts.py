#!/usr/bin/env python3
"""Download prebuilt V8 binaries from GitHub Actions Artifacts.

Fetches artifacts from a GitHub Actions workflow run and extracts
the static library (.a / .lib) and src_binding (.rs) files.

Uses checksum files (.sum) to avoid redundant downloads.

Usage:
  python3 tools/download_artifacts.py \\
    --artifacts-url URL \\
    --lib-name NAME --lib-out PATH \\
    --binding-name NAME --binding-out PATH

Environment:
  GITHUB_TOKEN  Required for downloading artifact archives.
"""

import argparse
import json
import os
import sys
import tempfile
import time
import zipfile
from typing import IO, Any, Dict, List, Optional
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen


def github_request(
    url: str,
    token: Optional[str] = None,
    output: Optional[IO[bytes]] = None,
) -> bytes:
    """Make a GitHub API request with retry.

    If *output* is given, the response is streamed into it and b"" is
    returned.  Otherwise the full response body is returned as bytes.
    """
    headers: Dict[str, str] = {"Accept": "application/vnd.github+json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    req = Request(url, headers=headers)
    num_retries: int = 3
    retry_wait: int = 5
    while True:
        try:
            resp = urlopen(req)
            if output is not None:
                while True:
                    chunk: bytes = resp.read(65536)
                    if not chunk:
                        break
                    output.write(chunk)
                return b""
            return resp.read()
        except (HTTPError, URLError) as e:
            if num_retries == 0:
                raise
            if isinstance(e, HTTPError) and e.code in (401, 403, 404):
                raise
            num_retries -= 1
            print(f"  Retrying in {retry_wait}s ... ({e})")
            time.sleep(retry_wait)
            retry_wait *= 2


def checksum_path(out_path: str) -> str:
    """Return the checksum file path for a given output file."""
    base, _ = os.path.splitext(out_path)
    return base + ".sum"


def checksum_matches(out_path: str, expected: str) -> bool:
    """Check if the checksum file matches the expected value."""
    sum_file: str = checksum_path(out_path)
    try:
        with open(sum_file, "r") as f:
            return f.read() == expected
    except OSError:
        return False


def write_checksum(out_path: str, value: str) -> None:
    """Write a checksum file for the given output file."""
    sum_file: str = checksum_path(out_path)
    with open(sum_file, "w") as f:
        f.write(value)


def download_artifact(
    download_url: str, out_path: str, token: str
) -> None:
    """Download a GitHub artifact zip and extract the inner file."""
    os.makedirs(os.path.dirname(out_path), exist_ok=True)

    print("  Downloading artifact zip ...")
    with tempfile.TemporaryFile() as tmp:
        github_request(download_url, token, output=tmp)
        tmp.seek(0)

        with zipfile.ZipFile(tmp) as zf:
            names: List[str] = zf.namelist()
            if len(names) == 0:
                raise RuntimeError("Artifact zip is empty")
            inner_name: str = names[0]
            print(f"  Extracting '{inner_name}' -> {out_path}")
            with zf.open(inner_name) as src, open(out_path, "wb") as dst:
                while True:
                    chunk: bytes = src.read(65536)
                    if not chunk:
                        break
                    dst.write(chunk)


def main() -> int:
    parser: argparse.ArgumentParser = argparse.ArgumentParser(
        description="Download V8 prebuilt binaries from GitHub Actions Artifacts"
    )
    parser.add_argument(
        "--artifacts-url",
        required=True,
        help="GitHub Actions artifacts list API URL",
    )
    parser.add_argument(
        "--lib-name",
        required=True,
        help="Expected artifact name for the static library",
    )
    parser.add_argument(
        "--lib-out",
        required=True,
        help="Output path for the static library file",
    )
    parser.add_argument(
        "--binding-name",
        required=True,
        help="Expected artifact name for src_binding",
    )
    parser.add_argument(
        "--binding-out",
        required=True,
        help="Output path for the src_binding file",
    )
    args: argparse.Namespace = parser.parse_args()

    token: str = os.environ.get("GITHUB_TOKEN", "")
    if not token:
        print(
            "Warning: GITHUB_TOKEN not set. "
            "Artifact downloads require authentication.",
            file=sys.stderr,
        )

    base_url: str = args.artifacts_url

    for label, name, out_path in [
        ("static library", args.lib_name, args.lib_out),
        ("src_binding", args.binding_name, args.binding_out),
    ]:
        # Check checksum to avoid re-downloads
        if os.path.exists(out_path) and checksum_matches(out_path, base_url):
            print(f"\n{label}: already up-to-date, skipping.")
            continue

        print(f"\nLooking for {label}: {name}")
        # Use ?name= query parameter to filter server-side
        url: str = f"{base_url}?{urlencode({'name': name})}"
        body: bytes = github_request(url, token)
        data: Dict[str, Any] = json.loads(body)
        artifacts: List[Dict[str, Any]] = data.get("artifacts", [])
        if len(artifacts) == 0:
            print(f"Error: artifact '{name}' not found.", file=sys.stderr)
            return 1

        artifact: Dict[str, Any] = artifacts[0]
        download_artifact(artifact["archive_download_url"], out_path, token)
        write_checksum(out_path, base_url)

    print("\nDone.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
