# chnroute

[![built with Codeium](https://codeium.com/badges/main)](https://codeium.com) [![Daily Make and Commit](https://github.com/ruijzhan/chnroute/actions/workflows/main.yaml/badge.svg)](https://github.com/ruijzhan/chnroute/actions/workflows/main.yaml)

## 自动更新的中国 IP 地址和特定域名列表

本项目提供持续更新的中国 IP 地址列表和特定域名列表，并生成可用于 RouterOS 路由器的配置脚本。

### 1. 规则更新

- **中国 IP 网段**：来自 [此网站](http://www.iwik.org/ipcountry/mikrotik/CN)。
- **特定域名**：由 [gfwlist 项目](https://github.com/gfwlist/gfwlist)维护。

您可以通过以下命令来更新列表并生成 RouterOS 规则脚本：

```shell
# 更新列表并生成 RouterOS 规则脚本
make
```

生成的文件包括：

- **[CN.rsc](./CN.rsc)**：中国大陆的 IPv4 地址段，由 [IANA](https://www.iana.org/) 分配。
- **[LAN.rsc](./LAN.rsc)**：内网 IPv4 地址段。
- **[gfwlist.rsc](./gfwlist.rsc)**：从 gfwlist 生成的 RouterOS 脚本，包含特定域名。
- **[gfwlist_v7.rsc](./gfwlist_v7.rsc)**：适用于 RouterOS v7.6 及以上版本的 gfwlist 脚本。

在生成规则前，您可以通过修改 `exclude_list.txt` 和 `include_list.txt` 手动剔除或加入特定的域名。

### 2. 中国 IP 网段导入与应用

导入中国 IP 网段有助于配置流量分流。在优化网络访问的场景中，可以标记目标 IP 不属于 CN 或 LAN 列表的流量，通过特定路由规则走优化的网络路线。

#### 2.1 导入中国 IP 网段到 RouterOS

使用以下脚本将 CN 和 LAN 的 IP 网段导入 RouterOS：

```ros
/system script
add dont-require-permissions=no name=cn owner=admin policy=ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon source="
/tool fetch url=https://raw.githubusercontent.com/ruijzhan/chnroute/master/CN.rsc
import file-name=CN.rsc
file remove CN.rsc

/tool fetch url=https://raw.githubusercontent.com/ruijzhan/chnroute/master/LAN.rsc
import file-name=LAN.rsc
file remove LAN.rsc"
```

#### 2.2 网络优化规则配置

在 `PREROUTING` 链中，将目标地址不属于 CN 的流量跳转到自定义链，并在自定义链中配置以下规则：

1. 匹配目标地址属于 LAN 的流量，直接 `RETURN`。
2. 对剩余流量根据连接协议和目标端口标记路由。
3. 在路由表中将这些流量指向优化网络的网关。

### 3. 使用 gfwlist 优化 DNS 解析

[gfwlist](https://github.com/gfwlist/gfwlist) 提供了特定域名列表，配合 RouterOS 的正则表达式匹配功能，可以为特定域名和其他域名设置不同的 DNS 服务器，从而优化解析速度。

#### 3.1 配置无特殊限制的 DNS 服务器

在 RouterOS 中设置全局变量 `dnsserver` 来指定无特殊限制的 DNS 服务器（如 8.8.8.8）。以下脚本会在每次系统启动时重新设置 DNS 服务器：

```ros
/system scheduler
add name=envs on-event="{\r\
    \n  :global dnsserver 8.8.8.8;\r\
    \n}" policy=read,write,policy,test start-time=startup
```

使用以下命令查看环境变量：

```shell
[admin@RouterBoard] > /system/script/environment/print 
Columns: NAME, VALUE
#  NAME       VALUE       
0  dnsserver  8.8.8.8
```

#### 3.2 导入 gfwlist 到 RouterOS

使用以下命令将 gfwlist 列表导入 RouterOS：

```ros
/system script
add dont-require-permissions=no name=gfwlist owner=admin policy=ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon source="
/tool fetch url=https://raw.githubusercontent.com/ruijzhan/chnroute/master/gfwlist.rsc
/import file-name=gfwlist.rsc
/file remove gfwlist.rsc
:log warning \"gfwlist 域名导入成功\""
```

**注意**：RouterOS v7.6 版本新增了 `Match Subdomains` 选项，可导入 [gfwlist_v7.rsc](./gfwlist_v7.rsc) 以提升解析性能。

**注意**：几千条 DNS 规则可能超出默认缓存 2M 的大小，需将 DNS 缓存大小设为 20560KiB 或更大：

```ros
/ip/dns/set cache-size=20560KiB
```

使用以下命令查看导入的 DNS 解析规则：

```ros
/ip/dns/static/print
```

配置后的 DNS 设置示例如下：

```shell
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

所有符合规则的域名解析请求将由指定的无特殊限制 DNS 服务器（如 8.8.8.8）处理，其他域名仍由国内 DNS 服务器解析。

如果国内环境中 8.8.8.8 返回的结果依然存在问题，可以通过以下 `dst-nat` 规则将目标地址为 8.8.8.8 的流量重定向到其他 DNS 服务器：

```ros
/ip/firewall/nat
add action=dst-nat chain=output comment=BuyVM dst-address=8.8.8.8 to-addresses=192.168.9.1
```
