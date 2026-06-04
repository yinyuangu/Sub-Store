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
country_name_map = {
    "AE": "阿联酋",
    "AM": "亚美尼亚",
    "AT": "奥地利",
    "AU": "澳大利亚",
    "BA": "波黑",
    "BD": "孟加拉国",
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
    "JP": "日本",
    "KG": "吉尔吉斯斯坦",
    "KH": "柬埔寨",
    "KR": "韩国",
    "KZ": "哈萨克斯坦",
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
    "UA": "乌克兰",
    "US": "美国",
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
    "# 订阅索引",
    "",
    "来源：ProxyScrape 全部国家免费 SOCKS5 列表",
    f"代理总数：{len(all_rows)}",
    f"国家文件数：{len(rows_by_country)}",
    "",
    "## 文件",
    "",
    f"- [socks5-all-uri.txt]({raw_prefix}/socks5-all-uri.txt)：全部国家汇总订阅",
    "",
    "## 国家列表",
    "",
    "| 国家 | 代码 | 数量 | 链接 |",
    "| --- | --- | ---: | --- |",
]

for code in sorted(rows_by_country):
    proxies = sorted(set(rows_by_country[code]))
    lines = [f"socks5://{proxy}#{code}-{idx:03d}" for idx, proxy in enumerate(proxies, start=1)]
    country_file = countries_dir / f"socks5-{code.lower()}-uri.txt"
    country_file.write_text("\n".join(lines) + "\n", encoding="utf-8")
    all_lines.extend(lines)
    raw_url = f"{raw_prefix}/countries/{country_file.name}"
    display_name = country_name_map.get(code, country_names[code])
    index_lines.append(f"| {display_name} | `{code}` | {len(lines)} | {raw_url} |")

(subscriptions_dir / "socks5-all-uri.txt").write_text("\n".join(all_lines) + "\n", encoding="utf-8")
(subscriptions_dir / "README.md").write_text("\n".join(index_lines) + "\n", encoding="utf-8")
PY
