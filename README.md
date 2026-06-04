# SOCKS5 国家订阅仓库

这个仓库会每小时从 ProxyScrape 自动更新一次全量 SOCKS5 代理，先做一轮 SOCKS5 握手可用性测试，再按国家拆分成不同的订阅链接。

主订阅链接：
https://raw.githubusercontent.com/yinyuangu/Sub-Store/main/subscriptions/socks5-all-uri.txt

仅 `proxy:false` 且通过测试的订阅链接：
https://raw.githubusercontent.com/yinyuangu/Sub-Store/main/subscriptions/socks5-proxy-false-uri.txt

国家索引：
https://raw.githubusercontent.com/yinyuangu/Sub-Store/main/subscriptions/README.md

国家订阅示例：
- 美国：https://raw.githubusercontent.com/yinyuangu/Sub-Store/main/subscriptions/countries/socks5-us-uri.txt
- 日本：https://raw.githubusercontent.com/yinyuangu/Sub-Store/main/subscriptions/countries/socks5-jp-uri.txt
- 英国：https://raw.githubusercontent.com/yinyuangu/Sub-Store/main/subscriptions/countries/socks5-gb-uri.txt

`proxy:false` 国家订阅示例：
- 美国：https://raw.githubusercontent.com/yinyuangu/Sub-Store/main/subscriptions/countries/socks5-us-proxy-false-uri.txt
- 日本：https://raw.githubusercontent.com/yinyuangu/Sub-Store/main/subscriptions/countries/socks5-jp-proxy-false-uri.txt

在 Shadowrocket 中导入：
1. 点右上角 `+`
2. 类型选择 `Subscribe`
3. 粘贴上面的订阅链接
4. 保存后按需刷新
