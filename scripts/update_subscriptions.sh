#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

python3 - <<'PY'
from bisect import bisect_right
from typing import Optional
from pathlib import Path
import ipaddress
import json
import re
import shutil
import subprocess
import tempfile
import urllib.parse
import urllib.request

repo_root = Path.cwd()
subscriptions_dir = repo_root / "subscriptions"
countries_dir = subscriptions_dir / "countries"
subscriptions_dir.mkdir(parents=True, exist_ok=True)
if countries_dir.exists():
    shutil.rmtree(countries_dir)

for item in subscriptions_dir.iterdir():
    if item.is_file():
        item.unlink()

proxyscrape_url = "https://api.proxyscrape.com/v4/free-proxy-list/get"
proxyscrape_params = {
    "request": "displayproxies",
    "protocol": "socks5",
    "country": "cn",
    "format": "json",
}
pedro_release_url = "https://github.com/pedro3pv/proxy-list/releases/latest/download/proxies_all.txt"
china_ip_url = "https://raw.githubusercontent.com/gaoyifan/china-operator-ip/ip-lists/china.txt"
raw_prefix = "https://raw.githubusercontent.com/yinyuangu/Sub-Store/main/subscriptions"
proxy_line_re = re.compile(r"^([a-z0-9+]+)://(\d{1,3}(?:\.\d{1,3}){3}):(\d+)$", re.IGNORECASE)


def fetch_json_pages(base_url: str, params: dict) -> list[dict]:
    rows = []
    skip = 0
    limit = None
    while True:
        query = params | {"skip": skip}
        url = f"{base_url}?{urllib.parse.urlencode(query)}"
        with urllib.request.urlopen(url, timeout=90) as response:
            payload = json.load(response)

        if limit is None:
            limit = int(payload.get("limit", 2000))

        proxies = payload.get("proxies", [])
        if not proxies:
            break
        rows.extend(proxies)

        if not payload.get("nextpage"):
            break
        skip += limit
    return rows


def write_named_subscription(target: Path, lines: list[str], prefix: str) -> int:
    rendered = [f"{line}#{prefix}-{idx:03d}" for idx, line in enumerate(lines, start=1)]
    content = "\n".join(rendered)
    if content:
        content += "\n"
    target.write_text(content, encoding="utf-8")
    return len(rendered)


def write_shadowrocket_nodes(target: Path, lines: list[str], prefix: str) -> int:
    rendered = []
    for idx, line in enumerate(lines, start=1):
        match = proxy_line_re.match(line)
        if not match:
            continue
        protocol, host, port = match.groups()
        name = f"{prefix}-{idx:03d}"
        protocol = protocol.lower()
        if protocol == "socks5":
            rendered.append(f"socks5://{host}:{port}#{name}")
    content = "\n".join(rendered)
    if content:
        content += "\n"
    target.write_text(content, encoding="utf-8")
    return len(rendered)


proxyscrape_rows = fetch_json_pages(proxyscrape_url, proxyscrape_params)
proxyscrape_alive = sorted(
    {
        f"socks5://{row['ip']}:{row['port']}"
        for row in proxyscrape_rows
        if row.get("alive") and row.get("ip") and row.get("port")
    }
)
proxyscrape_count = write_named_subscription(
    subscriptions_dir / "proxyscrape_cn.txt",
    proxyscrape_alive,
    "proxyscrape_cn",
)

with urllib.request.urlopen(china_ip_url, timeout=90) as response:
    china_cidrs = [line.strip() for line in response.read().decode("utf-8").splitlines() if line.strip()]

china_ranges = []
for cidr in china_cidrs:
    network = ipaddress.ip_network(cidr)
    china_ranges.append((int(network.network_address), int(network.broadcast_address)))
china_ranges.sort()
china_starts = [start for start, _ in china_ranges]


def ip_in_china_ranges(ip_text: str) -> bool:
    ip_value = int(ipaddress.ip_address(ip_text))
    idx = bisect_right(china_starts, ip_value) - 1
    return idx >= 0 and ip_value <= china_ranges[idx][1]


def normalize_ipv4(ip_text: str) -> Optional[str]:
    parts = ip_text.split(".")
    if len(parts) != 4:
        return None
    try:
        nums = [int(part, 10) for part in parts]
    except ValueError:
        return None
    if any(num < 0 or num > 255 for num in nums):
        return None
    return ".".join(str(num) for num in nums)


with urllib.request.urlopen(pedro_release_url, timeout=180) as response:
    pedro_lines = response.read().decode("utf-8", errors="replace").splitlines()

pedro_candidates = []
for line in pedro_lines:
    entry = line.strip()
    if not entry:
        continue
    match = proxy_line_re.match(entry)
    if not match:
        continue
    protocol, ip_text, _ = match.groups()
    if protocol.lower() != "socks5":
        continue
    normalized_ip = normalize_ipv4(ip_text)
    if not normalized_ip:
        continue
    if ip_in_china_ranges(normalized_ip):
        pedro_candidates.append(f"{protocol.lower()}://{normalized_ip}:{match.group(3)}")

pedro_candidates = sorted(set(pedro_candidates))

with tempfile.TemporaryDirectory(prefix="pedro3pv-cn-") as tmp_dir:
    tmp_path = Path(tmp_dir)
    candidates_file = tmp_path / "proxies_cn_candidates.txt"
    verified_file = tmp_path / "proxies_verified.txt"
    checker_repo = tmp_path / "proxy-list"

    candidates_file.write_text("\n".join(pedro_candidates) + ("\n" if pedro_candidates else ""), encoding="utf-8")

    subprocess.run(
        ["git", "clone", "--depth=1", "https://github.com/pedro3pv/proxy-list.git", str(checker_repo)],
        check=True,
        stdout=subprocess.DEVNULL,
    )

    subprocess.run(
        [
            "python3",
            str(checker_repo / "proxy_checker.py"),
            "--input",
            str(candidates_file),
            "--output",
            str(verified_file),
        ],
        check=True,
    )

    verified_lines = [
        line.strip()
        for line in verified_file.read_text(encoding="utf-8").splitlines()
        if line.strip()
    ]

pedro_count = write_shadowrocket_nodes(
    subscriptions_dir / "pedro3pv_cn.txt",
    verified_lines,
    "pedro3pv_cn",
)

summary_lines = [
    "# 订阅索引",
    "",
    "本仓库每小时生成两个中国订阅：",
    "",
    f"- [proxyscrape_cn.txt]({raw_prefix}/proxyscrape_cn.txt)：ProxyScrape 的中国 SOCKS5，按源站 alive 汇总，共 {proxyscrape_count} 条",
    f"- [pedro3pv_cn.txt]({raw_prefix}/pedro3pv_cn.txt)：pedro3pv/proxy-list 的中国 IP 过滤结果，经 proxy_checker.py 校验，只保留 socks5，共 {pedro_count} 条",
    "",
    f"ProxyScrape CN 原始 alive 候选数：{proxyscrape_count}",
    f"pedro3pv 中国 IP 候选数：{len(pedro_candidates)}",
    f"pedro3pv 中国校验通过数：{pedro_count}",
    "",
    f"China IP 范围来源：{china_ip_url}",
    f"pedro3pv 最新发布来源：{pedro_release_url}",
]
(subscriptions_dir / "README.md").write_text("\n".join(summary_lines) + "\n", encoding="utf-8")
PY
