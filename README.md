# chnroute

[![built with Codeium](https://codeium.com/badges/main)](https://codeium.com) [![Daily Make and Commit](https://github.com/ruijzhan/chnroute/actions/workflows/main.yaml/badge.svg)](https://github.com/ruijzhan/chnroute/actions/workflows/main.yaml)

## 持续更新的中国 IP 地址列表和 gfwlist 域名列表

生成的脚本可用于 RouterOS 路由器系统

### 1 更新规则

中国的所有 IP 网段来自 [这个网页](http://www.iwik.org/ipcountry/mikrotik/CN)。被 gfw 污染的域名列表被项目 [gfwlist](https://github.com/gfwlist/gfwlist) 所维护。我们可以运行下面的命令来获取最新的列表，并生成相应的 RouterOS 规则导入脚本：

```shell
# 更新列表并生成 RouterOS 规则导入脚本
make
```

这个脚本会生成以下几个文件：

- [CN.rsc](./CN.rsc): 由 [IANA](https://www.iana.org/) 组织分配给中国大陆使用的 IPv4 地址段
- [LAN.rsc](./LAN.rsc): 内网 IPv4 地址段
- [gfwlist.rsc](./gfwlist.rsc): 从 gfwlist 项目生成的 RouterOS 脚本，包含了已知的被污染的域名
- [gfwlist_v7.rsc](./gfwlist_v7.rsc): 适用于 > RouterOS v7.6 的 gfwlist 脚本

在生成规则前，也可以将域名加入 exlucde_list.txt 和 include_list.txt 列表来手动**剔除/加入**被特殊解析的域名。

### 2 中国 IP 网段列表的导入和使用

中国的 IP 网段可以帮助配置流量分流。科学上网时，dst IP 地址为非 CN 且非 LAN 地址列表中的请求，可以标记路由走科学上网的路线。

#### 2.1 可以使用以下脚本将 CN 和 LAN 的 IP 网段列表导入 RouterOS

```ros
/system script
add dont-require-permissions=no name=cn owner=admin policy=ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon source="/tool fetch url=https://raw.githubusercontent.com/ruijzhan/chnroute/master/CN.rsc\r\
    \nimport file-name=CN.rsc\r\
    \nfile remove CN.rsc\r\
    \n\r\
    \n/tool fetch url=https://raw.githubusercontent.com/ruijzhan/chnroute/master/LAN.rsc\r\
    \nimport file-name=LAN.rsc\r\
    \nfile remove LAN.rsc"
```

#### 2.2 科学上网规则的配置

为了筛选出目标 IP 国外的地址的连接，在 PREROUTING 链中，配置目标地址为非 CN 的连接，JUMP 到一个自定义链中。然后在自定义链中的第一条规则上，配置目标地址为 LAN 的连接直接进行 RETURN 操作。在余下的规则中，自行指定连接协议以及目标端口号进行路由标记 (mark routing) 。最后在路由表中将这些连接路由到科学上网的网关。

### 3 使用 gfwlist 避免域名解析污染，同时优化解析和线路速度

开源项目 [chinadns](https://github.com/shadowsocks/ChinaDNS) 的工作原理是同时将一个域名发往国内和未被污染的国外的 DNS 上游服务器进行解析，然后根据返回的结果决定是使用国内服务器返回的结果还是国外的结果。这样做虽然可以解决域名污染的问题，并尽量使用 CDN 友好的解析结果。但是由于解析任何域名都必须等待国外 DNS 服务器的响应才能做出判断，所以通常一次解析要耗时 300 ms 以上。

[gfwlist](https://github.com/gfwlist/gfwlist) 维护了一个较为齐全的被 gfw 污染的域名的列表，而 RouterOS 又提供了指定匹配正则表达式的域名用指定的上游 DNS 服务器进行解析。将两者结合起来可以实现未被污染的域名直接用速度较快的国内 DNS 服务器解析；而被污染的域名使用速度较慢的却无污染的国外 DNS 服务器进行解析。

#### 3.1 在 RouterOS 中用环境变量指定无污染 DNS 服务器

可以使用 VPN 的远端网关 IP 或者翻墙 8.8.8.8 这类 IP，在 RouterOS 上得到一个无污染的 DNS 服务器，然后将其 IP 设置为 RouerOS 的全局变量。由于每次 RouterOS 重启后环境变量会丢失，所以要用 scheduler 在每次开机的时候重新设置。以 DNS 服务器 192.168.9.1 为例：

```ros
/system scheduler
add name=envs on-event="{\r\
    \n  :global dnsserver 8.8.8.8;\r\
    \n}" policy=read,write,policy,test start-time=startup

```

达到以下效果：

```shell
[admin@RouterBoard] > /system/script/environment/print 
Columns: NAME, VALUE
#  NAME       VALUE       
0  dnsserver  8.8.8.8

```

#### 3.2 导入 gfwlist 列表到 RouterOS 中

用下面的命令将脚本导入 RouterOS：

```ros
/system script
add dont-require-permissions=no name=gfwlist owner=admin policy=ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon source=\
    "{\r\
    \n    /tool fetch url=https://raw.githubusercontent.com/ruijzhan/chnroute/master/gfwlist.rsc\r\
    \n    /import file-name=gfwlist.rsc\r\
    \n    /file remove gfwlist.rsc\r\
    \n    :log warning \"gfwlist\D3\F2\C3\FB\B5\BC\C8\EB\CD\EA\B3\C9\"\r\
    \n}"
```

**注意**：RouterOS v7.6 版本中，DNS FWD 规则支持了 Match Subdomains 选项，在上方脚本中导入 [gfwlist_v7.rsc](./gfwlist_v7.rsc) 解析会更高。

**注意**：几千条规则会用尽 DNS 的默认 2M 大小的缓存，需要将 DNS 缓存的大小设置为 20560KiB 或者更大：

```ros
/ip/dns/set cache-size=20560KiB
```

用命令查看导入的解析规则：

```ros
/ip/dns/static/print
```

此时的整个 dns 的设置为：

```ros
[admin@RouterBoard] > /ip/dns/print 
                      servers: 223.5.5.5,223.6.6.6
              dynamic-servers: 
               use-doh-server: 
              verify-doh-cert: no
        allow-remote-requests: yes
          max-udp-packet-size: 4096
         query-server-timeout: 2s
          query-total-timeout: 10s
       max-concurrent-queries: 100
  max-concurrent-tcp-sessions: 20
                   cache-size: 20560KiB
                cache-max-ttl: 1w
                   cache-used: 16957KiB

```

此时所有满足规则中正则表达式的域名，都会走指定的例如 8.8.8.8 这样干净且查询缓慢的服务器进行解析。而其他绝大多数没有被污染的域名依然走 223.5.5.5 这类国内服务器解析在几 ms 内得到结果。

但在绝大多数国内的环境下，8.8.8.8 返回的结果也是被污染的。我们需要随时更换 gfwlist 中的域名的 DNS 服务器，而重新设置 $dnsserver 变量和导入脚本是耗时的操作。此时我们可以在路由器的 output 链上设置以下 dnat 规则，将目标地址为 8.8.8.8 的请求，转发到任意 IP 上：

```ros
/ip/firewall/nat
add action=dst-nat chain=output comment=BuyVM dst-address=8.8.8.8 to-addresses=\
    192.168.9.1
```
