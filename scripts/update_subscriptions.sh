#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

python3 - <<'PY'
from collections import defaultdict
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import json
import socket
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
probe_timeout = 1.5
probe_workers = 128
country_name_map = {
    "AE": "阿联酋",
    "AM": "亚美尼亚",
    "AT": "奥地利",
    "AU": "澳大利亚",
    "BA": "波黑",
    "BD": "孟加拉国",
    "BE": "比利时",
    "BG": "保加利亚",
    "BR": "巴西",
    "CA": "加拿大",
    "CH": "瑞士",
    "CN": "中国",
    "DE": "德国",
    "EE": "爱沙尼亚",
    "ES": "西班牙",
    "FI": "芬兰",
    "FR": "法国",
    "GB": "英国",
    "GH": "加纳",
    "HK": "中国香港",
    "ID": "印度尼西亚",
    "IL": "以色列",
    "IN": "印度",
    "IR": "伊朗",
    "IT": "意大利",
    "JP": "日本",
    "KE": "肯尼亚",
    "KG": "吉尔吉斯斯坦",
    "KH": "柬埔寨",
    "KR": "韩国",
    "KZ": "哈萨克斯坦",
    "LK": "斯里兰卡",
    "LV": "拉脱维亚",
    "MX": "墨西哥",
    "MY": "马来西亚",
    "NL": "荷兰",
    "NO": "挪威",
    "PH": "菲律宾",
    "PK": "巴基斯坦",
    "PL": "波兰",
    "PS": "巴勒斯坦",
    "RO": "罗马尼亚",
    "RU": "俄罗斯",
    "SE": "瑞典",
    "SG": "新加坡",
    "TH": "泰国",
    "TR": "土耳其",
    "TZ": "坦桑尼亚",
    "UA": "乌克兰",
    "US": "美国",
    "UZ": "乌兹别克斯坦",
    "VN": "越南",
    "ZZ": "未知地区",
}

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
        proxy_flag = bool(ip_data.get("proxy", False))
        if not ip or not port:
            continue
        all_rows.append(
            {
                "country_code": country_code,
                "country_name": country_name,
                "proxy": f"{ip}:{port}",
                "proxy_flag": proxy_flag,
            }
        )

    if not payload.get("nextpage"):
        break
    skip += limit

unique_rows = {}
for row in all_rows:
    unique_rows.setdefault(row["proxy"], row)

def socks5_probe(proxy: str) -> bool:
    host, port_text = proxy.rsplit(":", 1)
    port = int(port_text)
    try:
        with socket.create_connection((host, port), timeout=probe_timeout) as sock:
            sock.settimeout(probe_timeout)
            sock.sendall(b"\x05\x01\x00")
            response = sock.recv(2)
            return response == b"\x05\x00"
    except OSError:
        return False

tested_ok = set()
with ThreadPoolExecutor(max_workers=probe_workers) as executor:
    for proxy, ok in zip(unique_rows, executor.map(socks5_probe, unique_rows)):
        if ok:
            tested_ok.add(proxy)

verified_rows = [row for proxy, row in unique_rows.items() if proxy in tested_ok]
proxy_false_rows = [row for row in verified_rows if not row["proxy_flag"]]

for old_file in countries_dir.glob("socks5-*-uri.txt"):
    old_file.unlink()
for old_file in countries_dir.glob("socks5-*-proxy-false-uri.txt"):
    old_file.unlink()
(subscriptions_dir / "socks5-all-uri.txt").unlink(missing_ok=True)
(subscriptions_dir / "socks5-proxy-false-uri.txt").unlink(missing_ok=True)

def build_rows_by_country(rows):
    rows_by_country = defaultdict(list)
    country_names = {}
    for row in rows:
        code = row["country_code"]
        rows_by_country[code].append(row["proxy"])
        country_names[code] = row["country_name"]
    return rows_by_country, country_names

def render_country_files(rows, suffix):
    rows_by_country, country_names = build_rows_by_country(rows)
    all_lines = []
    file_rows = []
    for code in sorted(rows_by_country):
        proxies = sorted(set(rows_by_country[code]))
        lines = [f"socks5://{proxy}#{code}-{idx:03d}" for idx, proxy in enumerate(proxies, start=1)]
        country_file = countries_dir / f"socks5-{code.lower()}-{suffix}.txt"
        country_file.write_text("\n".join(lines) + "\n", encoding="utf-8")
        all_lines.extend(lines)
        raw_url = f"{raw_prefix}/countries/{country_file.name}"
        display_name = country_name_map.get(code, country_names[code])
        file_rows.append((display_name, code, len(lines), raw_url))
    return all_lines, file_rows

def render_aggregate(rows, name_suffix):
    rows_by_country, _ = build_rows_by_country(rows)
    all_lines = []
    for code in sorted(rows_by_country):
        proxies = sorted(set(rows_by_country[code]))
        all_lines.extend(
            f"socks5://{proxy}#{code}-{idx:03d}"
            for idx, proxy in enumerate(proxies, start=1)
        )
    target = subscriptions_dir / f"socks5-{name_suffix}.txt"
    target.write_text("\n".join(all_lines) + "\n", encoding="utf-8")

index_lines = [
    "# 订阅索引",
    "",
    "来源：ProxyScrape 全部国家免费 SOCKS5 列表",
    f"源站去重后 alive 节点数：{len(unique_rows)}",
    f"握手通过节点数：{len(verified_rows)}",
    f"其中 proxy:false 且握手通过节点数：{len(proxy_false_rows)}",
    f"测试方式：SOCKS5 无认证握手校验，超时 {probe_timeout} 秒，并发 {probe_workers}",
    "",
    "## 文件",
    "",
    f"- [socks5-all-uri.txt]({raw_prefix}/socks5-all-uri.txt)：全部握手通过节点汇总订阅",
    f"- [socks5-proxy-false-uri.txt]({raw_prefix}/socks5-proxy-false-uri.txt)：仅 proxy:false 且握手通过节点汇总订阅",
    "",
    "## 全部握手通过国家列表",
    "",
    "| 国家 | 代码 | 数量 | 链接 |",
    "| --- | --- | ---: | --- |",
]

alive_lines, alive_file_rows = render_country_files(verified_rows, "uri")
render_aggregate(proxy_false_rows, "proxy-false-uri")

for display_name, code, count, raw_url in alive_file_rows:
    index_lines.append(f"| {display_name} | `{code}` | {count} | {raw_url} |")

(subscriptions_dir / "socks5-all-uri.txt").write_text("\n".join(alive_lines) + "\n", encoding="utf-8")
(subscriptions_dir / "README.md").write_text("\n".join(index_lines) + "\n", encoding="utf-8")
PY
