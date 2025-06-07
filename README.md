# chnroute

[![built with Codeium](https://codeium.com/badges/main)](https://codeium.com) [![Daily Make and Commit](https://github.com/ruijzhan/chnroute/actions/workflows/main.yaml/badge.svg)](https://github.com/ruijzhan/chnroute/actions/workflows/main.yaml)

## 项目简介

`chnroute` 是一个自动更新的工具集，提供中国大陆 IP 地址列表和特定域名列表，并为 RouterOS 路由器生成即用型配置脚本。本项目通过 GitHub Actions 实现每日自动更新，确保您始终使用最新的网络规则。

### 主要功能

- **自动更新的中国 IP 地址列表**：用于智能路由和流量分流
- **特定域名列表**：基于 gfwlist，用于优化 DNS 解析
- **RouterOS 配置脚本**：即用型脚本，轻松导入到 MikroTik 设备
- **内存优化版本**：针对资源受限设备提供的优化脚本

## 1. 数据来源与文件说明

### 1.1 数据来源

- **中国 IP 网段**：来自 [iwik.org](http://www.iwik.org/ipcountry/mikrotik/CN)，由 [IANA](https://www.iana.org/) 分配的中国大陆 IP 地址段
- **特定域名列表**：由 [gfwlist 项目](https://github.com/gfwlist/gfwlist) 维护的域名列表
- **更新频率**：数据源每日更新，本项目通过 GitHub Actions 自动同步

### 1.2 生成的文件

| 文件名 | 说明 |
|--------|------|
| [CN.rsc](./CN.rsc) | 中国大陆 IPv4 地址段，RouterOS 格式 |
| [CN_mem.rsc](./CN_mem.rsc) | 内存优化版中国 IP 地址列表，避免磁盘读写 |
| [LAN.rsc](./LAN.rsc) | 内网 IPv4 地址段 |
| [gfwlist.rsc](./gfwlist.rsc) | 从 gfwlist 生成的 RouterOS DNS 规则脚本 |
| [gfwlist_v7.rsc](./gfwlist_v7.rsc) | 适用于 RouterOS v7.6+ 版本的优化脚本（使用 Match Subdomains 功能） |
| [03-gfwlist.conf](./03-gfwlist.conf) | dnsmasq 格式的 gfwlist 规则（可用于 OpenWrt 等系统） |
| [gfwlist.txt](./gfwlist.txt) | 处理后的纯文本域名列表 |

### 1.3 自定义列表

您可以通过修改以下文件来自定义域名列表：

- `exclude_list.txt`：需要从 gfwlist 中排除的域名
- `include_list.txt`：需要额外添加的域名

这些文件使用纯文本格式，每行一个域名。修改后需要重新运行生成脚本以更新规则文件。

## 2. 使用方法

### 2.1 手动更新规则

克隆仓库后，执行以下命令更新所有列表并生成 RouterOS 规则脚本：

```shell
make
```

这将执行 `generate.sh` 脚本，下载最新的 IP 列表和域名列表，并生成所有配置文件。

#### 2.1.1 依赖项

脚本需要以下依赖：

- bash
- curl 或 wget
- awk
- sort
- base64

大多数 Linux 发行版默认已安装这些工具。

### 2.2 中国 IP 网段导入与应用

#### 2.2.1 导入中国 IP 网段到 RouterOS

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

#### 2.2.2 配置流量分流规则

在 RouterOS 中，您可以设置以下规则来优化网络访问：

1. 在 `PREROUTING` 链中，将目标地址不属于 CN 的流量跳转到自定义链
2. 在自定义链中：
   - 匹配目标地址属于 LAN 的流量，直接 `RETURN`
   - 对其他流量根据连接协议和目标端口标记路由
   - 在路由表中将标记的流量指向优化网络的网关

这种配置可以实现国内流量直连，国外流量走优化线路的智能路由方案。

### 2.3 使用 gfwlist 优化 DNS 解析

#### 2.3.1 配置全局 DNS 变量

在 RouterOS 中设置全局变量 `dnsserver` 来指定备用 DNS 服务器：

```ros
/system scheduler
add name=envs on-event="{\r\
    \n  :global dnsserver 8.8.8.8;\r\
    \n}" policy=read,write,policy,test start-time=startup
```

查看环境变量：

```shell
[admin@RouterBoard] > /system/script/environment/print 
Columns: NAME, VALUE
#  NAME       VALUE       
0  dnsserver  8.8.8.8
```

#### 2.3.2 导入 gfwlist 到 RouterOS

使用以下脚本导入 gfwlist 规则：

```ros
/system script
add dont-require-permissions=no name=gfwlist owner=admin policy=ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon source="
/tool fetch url=https://raw.githubusercontent.com/ruijzhan/chnroute/master/gfwlist.rsc
/import file-name=gfwlist.rsc
/file remove gfwlist.rsc
:log warning \"gfwlist 域名导入成功\""
```

> **提示**：RouterOS v7.6+ 用户可以导入 [gfwlist_v7.rsc](./gfwlist_v7.rsc) 以获得更好的性能

#### 2.3.3 增加 DNS 缓存大小

由于规则数量较多，需要增加 DNS 缓存大小：

```ros
/ip/dns/set cache-size=20560KiB
```

配置完成后，您可以查看 DNS 设置：

```ros
/ip/dns/static/print
```

#### 2.3.4 DNS 请求重定向（可选）

如果需要将 DNS 请求重定向到其他服务器：

```ros
/ip/firewall/nat
add action=dst-nat chain=output comment=CustomDNS dst-address=8.8.8.8 to-addresses=192.168.9.1
```

## 3. 自动更新机制

本项目通过 GitHub Actions 实现每日自动更新：

- 每天 UTC 21:00（北京时间次日 05:00）自动运行更新脚本
- 自动提交更新后的规则文件到仓库
- 您可以通过定时任务从 GitHub 获取最新规则

### 3.1 RouterOS 自动更新配置

您可以在 RouterOS 中设置定时任务，自动从 GitHub 获取最新规则：

```ros
/system scheduler
add interval=1d name=update_chnroute on-event="/system script run cn\r\n/system script run gfwlist\r\n/log info \"chnroute rules updated\"" policy=ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon start-date=jan/01/1970 start-time=04:30:00
```

此配置将每天凌晨 4:30 自动更新规则。

## 4. 项目结构

```text
.
├── .github/workflows/  # GitHub Actions 工作流配置
├── CN.rsc             # 中国大陆 IP 地址段 RouterOS 脚本
├── CN_mem.rsc         # 内存优化版中国 IP 地址列表
├── LAN.rsc            # 内网 IP 地址段 RouterOS 脚本
├── Makefile           # 构建脚本
├── README.md          # 中文文档
├── README.en.md       # 英文文档
├── exclude_list.txt   # 排除域名列表
├── generate.sh        # 主生成脚本
├── generate_cn.sh     # 中国 IP 列表生成脚本
├── gfwlist.txt        # 处理后的域名列表
├── gfwlist2dnsmasq.sh # gfwlist 转换脚本
├── gfwlist_v7.rsc     # RouterOS v7+ 版本的 gfwlist 脚本
└── include_list.txt   # 包含域名列表
```

## 5. 故障排除

### 5.1 常见问题

**Q: 导入规则后 DNS 解析变慢？**

A: 尝试增加 DNS 缓存大小，或考虑使用 RouterOS v7.6+ 版本的优化脚本。

**Q: 部分网站仍然无法访问？**

A: 检查您的 DNS 服务器配置，确保 `$dnsserver` 变量指向可靠的 DNS 服务器。您也可以通过修改 `include_list.txt` 添加未包含的域名。

**Q: 如何验证规则是否生效？**

A: 在 RouterOS 中运行以下命令查看已加载的规则：

```ros
/ip dns static print count-only
```

## 6. 高级用法

### 6.1 自定义脚本

您可以修改 `generate.sh` 脚本来自定义生成过程，例如添加更多的 IP 列表源或调整域名处理逻辑。

### 6.2 与其他系统集成

除了 RouterOS，本项目生成的规则也可以用于其他系统：

- **OpenWrt**: 使用 `03-gfwlist.conf` 与 dnsmasq 集成
- **其他路由系统**: 可以参考脚本逻辑，将规则转换为适合您系统的格式

## 7. 贡献与反馈

欢迎通过 [Issues](https://github.com/ruijzhan/chnroute/issues) 或 [Pull Requests](https://github.com/ruijzhan/chnroute/pulls) 提交改进建议或反馈问题。

---

[English Version](./README.en.md)
