# chnroute

[![built with Codeium](https://codeium.com/badges/main)](https://codeium.com) [![Daily Make and Commit](https://github.com/ruijzhan/chnroute/actions/workflows/main.yaml/badge.svg)](https://github.com/ruijzhan/chnroute/actions/workflows/main.yaml)

[English](./README.en.md) · [Makefile 使用指南](./MAKEFILE_USER_GUIDE_CN.md)

## 项目简介

`chnroute` 是一个自动更新的网络规则工具集：每日抓取中国大陆 IP 地址段和 [gfwlist](https://github.com/gfwlist/gfwlist) 域名列表，生成可直接导入 MikroTik RouterOS 的配置脚本，同时提供纯文本域名列表等通用格式。规则由 GitHub Actions 每日自动重新生成并提交，无需手动维护。

### 主要功能

- **中国 IP 地址列表**：约 8100 条 IPv4 网段，用于国内外流量智能分流
- **gfwlist 域名规则**：约 4300 个域名，生成 RouterOS DNS 静态规则与纯域名列表
- **即用型 RouterOS 脚本**：一键导入，可安全重复执行
- **可定制、易扩展**：通过 include/exclude 列表增删域名；生成逻辑模块化于 `lib/` 目录

## 目录

- [1. 生成的文件](#1-生成的文件)
- [2. 快速开始](#2-快速开始)
- [3. RouterOS 配置指南](#3-routeros-配置指南)
- [4. 自动更新](#4-自动更新)
- [5. 本地开发与测试](#5-本地开发与测试)
- [6. 故障排除](#6-故障排除)
- [7. 贡献与反馈](#7-贡献与反馈)

## 1. 生成的文件

### 1.1 文件列表

| 文件 | 说明 | 更新状态 |
|------|------|----------|
| [CN.rsc](./CN.rsc) | 中国大陆 IPv4 地址段，导入 RouterOS `CN` 地址列表，条目永久生效 | 每日自动生成 |
| [CN_mem.rsc](./CN_mem.rsc) | CN 列表的内存优化变体，条目带 248 天超时，到期自动清理 | 每日自动生成 |
| [gfwlist_v7.rsc](./gfwlist_v7.rsc) | gfwlist 域名的 RouterOS v7.6+ DNS 静态规则 | 每日自动生成 |
| [gfwlist.txt](./gfwlist.txt) | 纯文本域名列表，每行一个域名，可用于任意系统 | 每日自动生成 |
| [LAN.rsc](./LAN.rsc) | 内网及保留网段，导入 RouterOS `LAN` 地址列表 | 静态维护 |
| [03-gfwlist.conf](./03-gfwlist.conf) | dnsmasq 格式规则（OpenWrt 等） | 历史文件，不再自动生成 |

> **提示**：OpenWrt 用户请勿直接使用上述历史文件，可参考 [5.3 与其他系统集成](#53-与其他系统集成) 自行生成最新规则。

### 1.2 数据来源

- **中国 IP 网段**：来自 [iwik.org](http://www.iwik.org/ipcountry/mikrotik/CN)，由 [IANA](https://www.iana.org/) 分配给中国大陆的地址段
- **域名列表**：由 [gfwlist 项目](https://github.com/gfwlist/gfwlist) 维护
- **更新频率**：GitHub Actions 每天 UTC 21:00（北京时间次日 05:00）自动重新生成并提交

### 1.3 自定义域名列表

通过以下两个文件定制域名列表（纯文本，每行一个域名）：

- `include_list.txt`：额外添加的域名
- `exclude_list.txt`：从 gfwlist 中排除的域名

修改后重新运行生成脚本即可生效，参见[本地开发与测试](#5-本地开发与测试)。

## 2. 快速开始

### 2.1 RouterOS 用户

无需克隆仓库，直接在 RouterOS 中通过脚本从 GitHub 拉取规则文件并导入，见 [3. RouterOS 配置指南](#3-routeros-配置指南)。

### 2.2 本地生成

```shell
git clone https://github.com/ruijzhan/chnroute.git
cd chnroute
make
```

该命令会检查依赖、下载最新的 IP 列表与域名列表，并生成全部规则文件。

**依赖项**：bash、curl、awk、sort、grep、base64、mktemp、wc。大多数 Linux 发行版默认已安装，可运行 `make check` 一键校验。

> 如需代理，请设置标准环境变量 `http_proxy` / `https_proxy`（curl 原生支持）。

## 3. RouterOS 配置指南

### 3.1 导入中国 IP 地址段

以下脚本将 CN 和 LAN 网段导入 RouterOS：

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

脚本导入前会先清空旧的 `CN` 列表，可安全重复执行。

### 3.2 配置流量分流规则

在 RouterOS 中，您可以设置以下规则实现智能路由：

1. 在 `PREROUTING` 链中，将目标地址不属于 CN 的流量跳转到自定义链
2. 在自定义链中：
   - 匹配目标地址属于 LAN 的流量，直接 `RETURN`
   - 对其他流量根据连接协议和目标端口标记路由
   - 在路由表中将标记的流量指向优化网络的网关

这种配置可以实现国内流量直连、国外流量走优化线路的分流方案。

### 3.3 使用 gfwlist 优化 DNS 解析

#### 3.3.1 配置全局 DNS 变量

gfwlist 规则使用全局变量 `$dnsserver` 作为备用 DNS 服务器，需先设置：

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

#### 3.3.2 导入 gfwlist 规则

> **注意**：`gfwlist_v7.rsc` 需要 RouterOS **v7.6 及以上**版本（使用了 `type=FWD` 静态规则与 Match Subdomains 功能）。

```ros
/system script
add dont-require-permissions=no name=gfwlist owner=admin policy=ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon source="
/tool fetch url=https://raw.githubusercontent.com/ruijzhan/chnroute/master/gfwlist_v7.rsc
/import file-name=gfwlist_v7.rsc
/file remove gfwlist_v7.rsc
:log warning \"gfwlist 域名导入成功\""
```

脚本特性：

- 导入前自动清除已有的 `forward-to=$dnsserver` 条目，可安全重复导入
- 每个域名启用 `match-subdomain=yes`，自动覆盖其所有子域名
- 解析结果会写入 `gfw_list` 地址列表，可配合防火墙规则进一步控制流量

#### 3.3.3 增加 DNS 缓存大小

规则数量较多，建议增加 DNS 缓存：

```ros
/ip/dns/set cache-size=20560KiB
```

配置完成后，可查看已加载的 DNS 静态规则：

```ros
/ip/dns/static/print
```

#### 3.3.4 DNS 请求重定向（可选）

如需将 DNS 请求重定向到其他服务器：

```ros
/ip/firewall/nat
add action=dst-nat chain=output comment=CustomDNS dst-address=8.8.8.8 to-addresses=192.168.9.1
```

## 4. 自动更新

### 4.1 GitHub Actions

- 每天 UTC 21:00（北京时间次日 05:00）自动运行 `make` 重新生成全部规则
- 有变更时以 `Automated update: <时间戳>` 为提交信息推送到仓库
- 也可在 Actions 页面手动触发（push 到 master 同样会触发）

### 4.2 RouterOS 定时更新

在 RouterOS 中设置定时任务，每天自动从 GitHub 拉取最新规则：

```ros
/system scheduler
add interval=1d name=update_chnroute on-event="/system script run cn\r\n/system script run gfwlist\r\n/log info \"chnroute rules updated\"" policy=ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon start-date=jan/01/1970 start-time=06:00:00
```

> 建议将 `start-time` 设置在北京时间 06:00 左右，确保 GitHub Actions（05:00 左右完成提交）已生成当日最新规则。

## 5. 本地开发与测试

### 5.1 常用 Make 目标

| 命令 | 说明 |
|------|------|
| `make` / `make generate` | 检查依赖并生成全部规则文件 |
| `make fast` | 跳过依赖检查，直接生成（开发迭代用） |
| `make check` | 校验依赖与脚本语法 |
| `make test` | 生成并校验输出文件 |
| `make analyze` | 统计输出文件行数与大小 |
| `make benchmark` | 生成性能基准测试 |
| `make ci-test` | 完整本地 CI 流程（clean → check → test → benchmark → analyze） |
| `sudo make install` | 安装到 `/opt/chnroute` |
| `sudo make service-setup` | 配置 systemd 定时器，实现系统级每日更新 |

完整目标说明见 [Makefile 使用指南](./MAKEFILE_USER_GUIDE_CN.md)，或运行 `make help` 查看。

### 5.2 运行测试

```shell
bash tests/run_tests.sh
```

对域名抽取、合并等核心处理逻辑运行单元测试。

### 5.3 与其他系统集成

除 RouterOS 外，可使用 `gfwlist2dnsmasq.sh` 生成适用于其他系统的规则：

```shell
# 生成 dnsmasq 规则（OpenWrt 等）
bash gfwlist2dnsmasq.sh -d 127.0.0.1 -p 5353 -s gfwlist -o 03-gfwlist.conf

# 生成纯域名列表（附加自有域名、排除指定域名）
bash gfwlist2dnsmasq.sh -l -o gfwlist.txt \
    --extra-domain-file include_list.txt \
    --exclude-domain-file exclude_list.txt
```

运行 `bash gfwlist2dnsmasq.sh -h` 查看全部选项。

### 5.4 项目结构

```text
.
├── .github/workflows/   # GitHub Actions 每日自动更新工作流
├── lib/                 # 生成脚本的核心模块
│   ├── config.sh        # 集中配置与常量
│   ├── logger.sh        # 彩色分级日志
│   ├── downloader.sh    # 带重试与超时的下载
│   ├── processor.sh     # 域名抽取 / IP 格式化（单遍处理）
│   └── ...              # 依赖检查、校验、错误处理、临时文件等
├── tests/               # 单元测试
├── generate.sh          # 主生成脚本
├── gfwlist2dnsmasq.sh   # gfwlist 转换工具（可独立使用）
├── generate_cn.sh       # 可选的中国域名列表生成脚本（遗留）
├── include_list.txt     # 附加域名列表
├── exclude_list.txt     # 排除域名列表
├── Makefile             # 构建、测试与安装入口
├── CN.rsc               # 中国 IP 地址段（每日生成）
├── CN_mem.rsc           # 内存优化版中国 IP 列表（每日生成）
├── gfwlist_v7.rsc       # RouterOS v7.6+ DNS 规则（每日生成）
├── gfwlist.txt          # 纯域名列表（每日生成）
├── LAN.rsc              # 内网网段（静态维护）
└── 03-gfwlist.conf      # dnsmasq 规则（历史文件）
```

## 6. 故障排除

**Q: 导入 gfwlist 规则时报错？**

A: `gfwlist_v7.rsc` 需要 RouterOS v7.6 及以上版本。请运行 `/system/package/print` 确认版本。

**Q: 导入规则后 DNS 解析变慢？**

A: 增大 DNS 缓存（`/ip/dns/set cache-size=20560KiB`），并确认设备有足够可用内存。

**Q: 部分网站仍然无法访问？**

A: 检查 `$dnsserver` 变量是否指向可靠的 DNS 服务器；也可通过 `include_list.txt` 添加缺失的域名后重新生成。

**Q: 如何验证规则是否生效？**

A: 在 RouterOS 中运行以下命令查看已加载的规则数量：

```ros
/ip dns static print count-only
```

**Q: 本地生成失败？**

A: 运行 `make check` 确认依赖齐全；网络问题可尝试设置 `http_proxy` / `https_proxy` 代理后重试。

## 7. 贡献与反馈

欢迎通过 [Issues](https://github.com/ruijzhan/chnroute/issues) 或 [Pull Requests](https://github.com/ruijzhan/chnroute/pulls) 提交改进建议或反馈问题。

---

[![Powered by DartNode](https://dartnode.com/branding/DN-Open-Source-sm.png)](https://dartnode.com "Powered by DartNode - Free VPS for Open Source")
