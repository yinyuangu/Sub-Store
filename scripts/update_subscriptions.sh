#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

python3 - <<'PY'
from collections import defaultdict
from pathlib import Path
import json
import urllib.parse
import urllib.request

repo_root = Path.cwd()
subscriptions_dir = repo_root / "subscriptions"
countries_dir = subscriptions_dir / "countries"
subscriptions_dir.mkdir(parents=True, exist_ok=True)
countries_dir.mkdir(parents=True, exist_ok=True)

base_url = "https://api.proxyscrape.com/v4/free-proxy-list/get"
params = {
    "request": "displayproxies",
    "protocol": "socks5",
    "country": "all",
    "format": "json",
}
raw_prefix = "https://raw.githubusercontent.com/yinyuangu/Sub-Store/main/subscriptions"

all_rows = []
skip = 0
limit = None

while True:
    query = params | {"skip": skip}
    url = f"{base_url}?{urllib.parse.urlencode(query)}"
    with urllib.request.urlopen(url, timeout=60) as response:
        payload = json.load(response)

    if limit is None:
        limit = int(payload.get("limit", 2000))

    proxies = payload.get("proxies", [])
    if not proxies:
        break

    for proxy in proxies:
        if not proxy.get("alive"):
            continue
        ip = proxy.get("ip")
        port = proxy.get("port")
        ip_data = proxy.get("ip_data") or {}
        country_code = (ip_data.get("countryCode") or "ZZ").upper()
        country_name = ip_data.get("country") or "Unknown"
        if not ip or not port:
            continue
        all_rows.append(
            {
                "country_code": country_code,
                "country_name": country_name,
                "proxy": f"{ip}:{port}",
            }
        )

    if not payload.get("nextpage"):
        break
    skip += limit

rows_by_country = defaultdict(list)
country_names = {}
for row in all_rows:
    code = row["country_code"]
    rows_by_country[code].append(row["proxy"])
    country_names[code] = row["country_name"]

for old_file in countries_dir.glob("socks5-*-uri.txt"):
    old_file.unlink()

all_lines = []
index_lines = [
    "# Generated subscriptions",
    "",
    "Source: ProxyScrape free SOCKS5 list for all countries",
    f"Total proxies: {len(all_rows)}",
    f"Country files: {len(rows_by_country)}",
    "",
    "## Files",
    "",
    f"- [socks5-all-uri.txt]({raw_prefix}/socks5-all-uri.txt): all countries combined",
    "",
    "## Countries",
    "",
    "| Country | Code | Count | URL |",
    "| --- | --- | ---: | --- |",
]

for code in sorted(rows_by_country):
    proxies = sorted(set(rows_by_country[code]))
    lines = [f"socks5://{proxy}#{code}-{idx:03d}" for idx, proxy in enumerate(proxies, start=1)]
    country_file = countries_dir / f"socks5-{code.lower()}-uri.txt"
    country_file.write_text("\n".join(lines) + "\n", encoding="utf-8")
    all_lines.extend(lines)
    raw_url = f"{raw_prefix}/countries/{country_file.name}"
    index_lines.append(f"| {country_names[code]} | `{code}` | {len(lines)} | {raw_url} |")

(subscriptions_dir / "socks5-all-uri.txt").write_text("\n".join(all_lines) + "\n", encoding="utf-8")
(subscriptions_dir / "README.md").write_text("\n".join(index_lines) + "\n", encoding="utf-8")
PY
