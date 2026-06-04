#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

mkdir -p subscriptions

source_url='https://api.proxyscrape.com/v4/free-proxy-list/get?request=displayproxies&protocol=socks5&country=us&format=text'

curl -fsSL "$source_url" \
  | tr -d '\r' \
  | awk 'NF {printf "socks5://%s#US-%03d\n", $0, ++n}' \
  > subscriptions/socks5-us-uri.txt

proxy_count="$(wc -l < subscriptions/socks5-us-uri.txt | tr -d ' ')"
updated_at="$(date -u '+%Y-%m-%d %H:%M:%S UTC')"

printf '%s\n' '# Generated subscriptions' > subscriptions/README.md
printf '%s\n' '' >> subscriptions/README.md
printf '%s\n' '- socks5-us-uri.txt: line-separated socks5 URI format' >> subscriptions/README.md
printf '%s\n' '' >> subscriptions/README.md
printf '%s\n' 'Source: ProxyScrape free US SOCKS5 list' >> subscriptions/README.md
printf 'Updated: %s\n' "$updated_at" >> subscriptions/README.md
printf 'Proxy count: %s\n' "$proxy_count" >> subscriptions/README.md
