# 中国代理订阅仓库

这个仓库每小时生成两个中国订阅链接：

- `proxyscrape_cn`
  https://raw.githubusercontent.com/yinyuangu/Sub-Store/main/subscriptions/proxyscrape_cn.txt
- `pedro3pv_cn`
  https://raw.githubusercontent.com/yinyuangu/Sub-Store/main/subscriptions/pedro3pv_cn.txt

说明：

- `proxyscrape_cn` 只引用 `https://api.proxyscrape.com/v4/free-proxy-list/get?request=displayproxies&protocol=socks5&country=cn&format=json`
- `pedro3pv_cn` 先从 `pedro3pv/proxy-list` 最新发布获取 `proxies_all.txt`
- 再用 `https://raw.githubusercontent.com/gaoyifan/china-operator-ip/ip-lists/china.txt` 做中国 IP 范围比对
- 命中中国 IP 范围后，使用 `pedro3pv/proxy-list` 的 `proxy_checker.py` 导出 `proxies_verified.txt`
- `pedro3pv_cn` 已剔除 `socks4`
