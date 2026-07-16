# 订阅索引

本仓库每小时生成两个中国订阅：

- [proxyscrape_cn.txt](https://raw.githubusercontent.com/yinyuangu/Sub-Store/main/subscriptions/proxyscrape_cn.txt)：ProxyScrape 的中国 SOCKS5，按源站 alive 汇总，共 76 条
- [pedro3pv_cn.txt](https://raw.githubusercontent.com/yinyuangu/Sub-Store/main/subscriptions/pedro3pv_cn.txt)：pedro3pv/proxy-list 的中国 IP 过滤结果，经 proxy_checker.py 校验，只保留 socks5，共 13 条

ProxyScrape CN 原始 alive 候选数：76
pedro3pv 中国 IP 候选数：34286
pedro3pv 中国校验通过数：13

China IP 范围来源：https://raw.githubusercontent.com/gaoyifan/china-operator-ip/ip-lists/china.txt
pedro3pv 最新发布来源：https://github.com/pedro3pv/proxy-list/releases/latest/download/proxies_all.txt
