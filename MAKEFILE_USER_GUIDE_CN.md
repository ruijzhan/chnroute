# chnroute Makefile 用户指南

## 目录

- [概述](#概述)
- [先决条件](#先决条件)
- [安装](#安装)
- [快速开始](#快速开始)
- [命令参考](#命令参考)
  - [基础目标](#基础目标)
  - [开发目标](#开发目标)
  - [系统目标](#系统目标)
- [使用示例](#使用示例)
- [开发工作流程](#开发工作流程)
- [故障排除](#故障排除)
- [高级配置](#高级配置)
- [贡献指南](#贡献指南)

---

## 概述

chnroute Makefile 提供了一个全面的构建系统，用于生成中国网络路由规则和域名列表。它提供了广泛的目标用于开发、测试、部署和系统管理。

### 核心功能

- **自动生成**：构建中国 IP 路由和 GFW 域名列表
- **依赖管理**：自动检查所需工具和依赖项
- **性能监控**：内置基准测试和内存分析
- **开发工具**：Shell 别名、Tab 补全和开发环境设置
- **系统集成**：完整的 systemd 服务支持，用于自动更新
- **包管理**：创建用于部署的分发包
- **验证**：全面的输出验证和语法检查

### 目标分类

1. **基础目标**：路由生成的核心功能
2. **开发目标**：开发者和高级用户的工具
3. **系统目标**：安装和系统管理功能

---

## 先决条件

### 必需工具

Makefile 会自动检查这些必需的依赖项：

- **bash** (4.0+) - Shell 解释器
- **curl** - 网络下载
- **awk** - 文本处理
- **sort** - 数据排序
- **base64** - Base64 编码/解码
- **grep** - 模式搜索
- **sed** - 流编辑
- **tar** - 归档创建

### 可选工具

这些工具增强功能但不是严格必需的：

- **shellcheck** - Shell 脚本的静态分析
- **python3** - 高级基准测试计算
- **/usr/bin/time** (GNU time) - 详细的时间和内存分析
- **systemctl** - Systemd 服务管理

### 系统要求

- **操作系统**：Linux（在 Ubuntu、CentOS、Debian 上测试）
- **内存**：最低 512MB 可用内存
- **磁盘空间**：最低 100MB 可用空间
- **网络**：下载源数据的互联网连接
- **权限**：系统安装目标需要 root 权限

---

## 安装

### 1. 克隆仓库

```bash
git clone https://github.com/ruijzhan/chnroute.git
cd chnroute
```

### 2. 验证依赖项

```bash
make check
```

此命令将验证所有必需工具都可用并报告任何缺失的依赖项。

### 3. 测试基本功能

```bash
make generate
```

这将生成路由规则并验证输出文件。

---

## 快速开始

### 对于基本用户

```bash
# 生成中国路由规则（默认目标）
make

# 或显式指定：
make generate

# 清理临时文件
make clean

# 获取帮助
make help
```

### 对于开发者

```bash
# 设置开发环境
make dev-setup
source .make.d/setup.sh

# 使用便捷别名
cn-gen          # 生成路由
cn-clean        # 清理文件
cn-bench        # 运行基准测试
cn-analyze      # 分析输出

# 运行全面测试
make ci-test
```

### 对于系统管理员

```bash
# 系统范围安装（需要 root）
sudo make install

# 设置自动每日更新
sudo make service-setup

# 启用服务
sudo systemctl enable --now chnroute.timer

# 检查服务状态
sudo systemctl status chnroute.timer
```

---

## 命令参考

### 基础目标

#### `generate`（默认）
生成中国 IP 路由和 GFW 域名列表，包含完整验证。

```bash
make generate
# 或简单地：
make
```

**功能说明：**
- 检查所有依赖项
- 验证脚本语法
- 从源下载最新数据
- 生成 RouterOS 配置文件
- 验证输出文件

**创建的输出文件：**
- `CN.rsc` - 中国 IP 地址列表（永久超时）
- `CN_mem.rsc` - 中国 IP 地址列表（248天超时）
- `gfwlist_v7.rsc` - RouterOS v7+ 的 GFW 域名规则
- `gfwlist.txt` - 纯文本域名列表
- `03-gfwlist.conf` - dnsmasq 配置格式

#### `fast`
跳过依赖检查快速生成路由。

```bash
make fast
```

**使用场景：** 当您确信所有依赖项都可用并希望获得最大速度时。

#### `clean`
删除所有临时文件和构建工件。

```bash
make clean
```

**删除的文件：**
- `logs/` 目录
- `*.tmp` 和 `*.processed` 文件
- `chnroute_*` 临时目录
- `.make.d/` 开发文件
- 各种缓存文件

#### `check`
验证依赖项和脚本语法。

```bash
make check
```

**检查组件：**
- 必需命令的可用性
- Shell 脚本语法
- 可选工具警告
- 配置文件验证

#### `validate`
验证生成的输出文件。

```bash
make validate
```

**验证标准：**
- 文件存在性
- 文件大小（非空）
- 基本格式验证

#### `test`
运行包括生成和验证的全面测试。

```bash
make test
```

**测试序列：**
1. 生成路由
2. 验证所有输出
3. 显示文件统计信息

#### `help`
显示全面的帮助信息。

```bash
make help
```

显示可用目标、使用示例和描述。

---

### 开发目标

#### `benchmark`
通过详细计时测量生成性能。

```bash
make benchmark
```

**功能特性：**
- 冷缓存计时
- 热缓存计时
- 3次运行的平均值（如果 python3 可用）
- GNU time 集成以获得详细指标

**示例输出：**
```
[12:34:56] Running performance benchmark...
  Cold cache run:
    real 0m45.234s  user 0m42.123s  sys 0m3.111s
  Warm cache run:
    real 0m15.678s  user 0m14.234s  sys 0m1.444s
  Average of 3 runs:
    Run 1: 15.234 s
    Run 2: 14.987 s
    Run 3: 15.123 s
  Average: 15.115 s
[12:35:41] [OK] Benchmark completed
```

#### `memory-profile`
收集生成期间的内存使用信息。

```bash
make memory-profile
```

**需要：** GNU time (`/usr/bin/time`)

**输出包括：**
- 最大常驻集大小
- 用户时间
- 系统时间
- CPU 使用百分比

#### `analyze`
分析和总结生成的输出文件。

```bash
make analyze
```

**提供统计信息：**
- 文件大小（字节）
- 行数
- 总体统计

**示例输出：**
```
[12:36:12] Analyzing output files...
  CN.rsc: 8923 lines, 245678 bytes
  CN_mem.rsc: 8923 lines, 245678 bytes
  gfwlist_v7.rsc: 2345 lines, 123456 bytes
  gfwlist.txt: 2345 lines, 45678 bytes
  03-gfwlist.conf: 4689 lines, 234567 bytes
  Totals: 27225 lines, 894075 bytes
```

#### `dev-setup`
设置包含别名和 shell 补全的开发环境。

```bash
make dev-setup
```

**创建：**
- `.make.d/aliases` - 常用命令的 Shell 别名
- `.make.d/completion.bash` - make 目标的 Tab 补全
- `.make.d/setup.sh` - 加载环境的设置脚本

**设置后：**
```bash
source .make.d/setup.sh
```

**可用别名：**
- `cn-gen` - `make generate`
- `cn-fast` - `make fast`
- `cn-clean` - `make clean`
- `cn-test` - `make test`
- `cn-bench` - `make benchmark`
- `cn-analyze` - `make analyze`

#### `ci-test`
运行完整的 CI 工作流程进行测试。

```bash
make ci-test
```

**工作流程：**
1. 清理之前的构建
2. 检查依赖项和语法
3. 运行全面测试
4. 执行基准测试
5. 分析输出

---

### 系统目标

#### `install`
系统范围安装 chnroute（需要 root 权限）。

```bash
sudo make install
```

**安装位置：**
- `/opt/chnroute/` - 主程序文件
- `/etc/chnroute/` - 配置文件
- 具有适当权限的脚本和数据文件
- 创建默认配置文件

#### `service-setup`
配置 systemd 服务以进行自动每日更新。

```bash
sudo make service-setup
```

**创建：**
- `/etc/systemd/system/chnroute.service` - 服务单元
- `/etc/systemd/system/chnroute.timer` - 定时器单元
- 重新加载 systemd 守护进程

**服务配置：**
- 每天在随机时间运行
- 持久执行（如果错过会补上）
- 以 root 用户运行
- 适当的环境和安全设置

**安装后：**
```bash
# 启用并启动定时器
sudo systemctl enable --now chnroute.timer

# 检查状态
sudo systemctl status chnroute.timer
sudo systemctl status chnroute.service

# 查看日志
journalctl -u chnroute.service -f
```

#### `uninstall`
删除所有已安装的文件和服务。

```bash
sudo make uninstall
```

**删除：**
- 所有已安装的文件
- Systemd 服务和定时器单元
- 配置目录
- 重新加载 systemd 守护进程

#### `package`
创建用于部署的分发包。

```bash
make package
```

**创建：**
- `dist/chnroute-<version>.tar.gz` - 完整包
- 包含所有必需文件和文档
- 包信息文件

**包内容：**
- 生成的输出文件
- 脚本和库
- 配置文件
- 文档
- 包元数据

---

#### `info`
显示项目信息和当前状态。

```bash
make info
```

**显示：**
- 项目版本
- 安装路径
- 输出文件统计
- 仓库信息

---

## 使用示例

### 日常使用

```bash
# 使用验证的快速生成
make

# 跳过依赖检查生成（更快）
make fast

# 生成后清理
make clean && make generate

# 检查一切是否正常
make test
```

### 开发工作流程

```bash
# 1. 设置开发环境
make dev-setup
source .make.d/setup.sh

# 2. 对脚本进行更改
vim generate.sh

# 3. 测试更改
cn-gen
cn-test

# 4. 运行性能测试
cn-bench

# 5. 分析结果
cn-analyze

# 6. 运行完整 CI 测试
make ci-test
```

### 系统管理

```bash
# 1. 系统范围安装
sudo make install

# 2. 设置自动更新
sudo make service-setup
sudo systemctl enable --now chnroute.timer

# 3. 监控服务
sudo systemctl status chnroute.timer
sudo journalctl -u chnroute.service --since "1 hour ago"

# 4. 手动更新（如果需要）
sudo systemctl start chnroute.service

# 5. 检查日志
sudo journalctl -u chnroute.service -f

# 6. 更新配置
sudo vim /etc/chnroute/config.conf
sudo systemctl restart chnroute.service
```

### 故障排除

```bash
# 1. 检查系统依赖项
make check

# 2. 验证语法
make validate-syntax

# 3. 使用详细日志运行
bash generate.sh

# 4. 检查系统资源
make memory-profile

# 5. 清理并重试
make clean
make generate
```

### 性能分析

```bash
# 1. 基准测试
make benchmark > benchmark-report.txt

# 2. 内存使用分析
make memory-profile >> benchmark-report.txt

# 3. 输出分析
make analyze >> benchmark-report.txt

# 4. 创建性能报告
make benchmark > benchmark-report.txt
make analyze >> benchmark-report.txt
make memory-profile >> benchmark-report.txt
```

---

## 开发工作流程

### 对于贡献者

1. **设置环境**
   ```bash
   git clone https://github.com/ruijzhan/chnroute.git
   cd chnroute
   make dev-setup
   source .make.d/setup.sh
   ```

2. **开发周期**
   ```bash
   # 进行更改
   vim generate.sh

   # 测试更改
   cn-test

   # 运行完整测试套件
   make ci-test

   # 检查性能影响
   cn-bench
   ```

3. **质量保证**
   ```bash
   # 语法检查
   make check

   # 静态分析（如果 shellcheck 可用）
   shellcheck *.sh

   # 手动测试
   make clean && make generate
   ```

4. **创建包**
   ```bash
   make package
   # 在干净环境中测试包
   ```

### 性能优化

1. **基准测试当前状态**
   ```bash
   make benchmark > baseline.txt
   ```

2. **实施优化**
   ```bash
   # 进行代码更改
   ```

3. **比较性能**
   ```bash
   make benchmark > optimized.txt
   diff baseline.txt optimized.txt
   ```

4. **内存分析**
   ```bash
   make memory-profile
   # 分析内存使用模式
   ```

---

## 故障排除

### 常见问题

#### 依赖项问题

**问题：** `make check` 报告缺少工具

**解决方案：**
```bash
# 在 Ubuntu/Debian 上
sudo apt-get update
sudo apt-get install bash curl awk grep sed coreutils tar

# 在 CentOS/RHEL 上
sudo yum install bash curl awk grep sed coreutils tar

# 在 macOS 上（使用 Homebrew）
brew install bash curl gnu-sed gnu-tar
```

#### 权限问题

**问题：** 安装期间权限被拒绝

**解决方案：**
```bash
# 确保对系统目标使用 sudo
sudo make install
sudo make service-setup
```

#### 生成失败

**问题：** 路由生成失败

**故障排除步骤：**
```bash
# 1. 检查网络连接
curl -I https://www.iwik.org/ipcountry/mikrotik/CN

# 2. 验证脚本语法
make validate-syntax

# 3. 检查磁盘空间
df -h

# 4. 使用详细输出运行
bash -x generate.sh

# 5. 检查日志
ls -la logs/
cat logs/*.log
```

#### 服务问题

**问题：** Systemd 服务不工作

**故障排除：**
```bash
# 检查服务状态
sudo systemctl status chnroute.service
sudo systemctl status chnroute.timer

# 查看日志
sudo journalctl -u chnroute.service -n 50

# 检查定时器计划
sudo systemctl list-timers chnroute.timer

# 手动服务启动
sudo systemctl start chnroute.service
```

#### 性能问题

**问题：** 生成速度慢

**分析：**
```bash
# 检查系统资源
free -h
df -h

# 运行基准测试
make benchmark

# 分析内存使用
make memory-profile

# 检查网络速度
curl -o /dev/null http://www.iwik.org/ipcountry/mikrotik/CN
```

### 调试模式

对于详细调试，直接运行脚本：

```bash
# 启用调试日志
export LOG_LEVEL=DEBUG

# 使用 bash 调试运行
bash -x generate.sh

# 监控系统资源
htop
iotop
```

### 获取帮助

1. **内置帮助：**
   ```bash
   make help
   ```

2. **版本信息：**
   ```bash
   make info
   ```

3. **检查配置：**
   ```bash
   make check
   make validate-syntax
   ```

4. **GitHub Issues：**
   - 在 https://github.com/ruijzhan/chnroute/issues 报告错误
   - 包含系统信息和错误日志

---

## 高级配置

### 环境变量

您可以使用环境变量自定义行为：

```bash
# 设置日志级别
export LOG_LEVEL=DEBUG
make generate

# 跳过验证以更快执行
export SKIP_VALIDATION=true
make fast

# 设置自定义线程数
export PARALLEL_THREADS=8
make generate

# 使用自定义 DNS 服务器
export CUSTOM_DNS_SERVERS="8.8.8.8,1.1.1.1"
make generate
```

### 配置文件

#### 系统配置
安装后编辑 `/etc/chnroute/config.conf`：

```bash
sudo vim /etc/chnroute/config.conf
```

**示例配置：**
```bash
# 日志级别：DEBUG, INFO, WARN, ERROR
LOG_LEVEL=INFO

# 并行处理线程数
PARALLEL_THREADS=4

# 自定义 DNS 服务器
CUSTOM_DNS_SERVERS=8.8.8.8,1.1.1.1

# 启用性能监控
ENABLE_PERFORMANCE_MONITORING=true
```

#### 域名列表

可以通过编辑添加自定义域名列表：

```bash
# 包含其他域名
vim include_list.txt

# 排除特定域名
vim exclude_list.txt

# 更改后重新生成
make generate
```

### Make 变量

您可以覆盖 Makefile 变量：

```bash
# 自定义安装目录
sudo make install INSTALL_DIR=/usr/local/chnroute

# 自定义脚本名称
make generate SCRIPT=custom_generate.sh

# 自定义输出目录
make generate OUTPUT_DIR=/tmp/chnroute
```

### 并行执行

控制并行执行：

```bash
# 限制并行作业
make -j2

# 使用所有 CPU 核心
make -j$(nproc)

# 禁用并行执行
make -j1
```

---

## 贡献指南

### 开发设置

1. **Fork 和克隆**
   ```bash
   git clone https://github.com/yourusername/chnroute.git
   cd chnroute
   ```

2. **设置开发环境**
   ```bash
   make dev-setup
   source .make.d/setup.sh
   ```

3. **创建功能分支**
   ```bash
   git checkout -b feature-name
   ```

4. **进行更改**
   ```bash
   # 编辑文件
   vim generate.sh

   # 测试更改
   cn-test
   make ci-test
   ```

5. **运行质量检查**
   ```bash
   make check
   shellcheck *.sh
   make benchmark
   ```

6. **提交更改**
   ```bash
   git add .
   git commit -m "更改描述"
   ```

7. **测试包创建**
   ```bash
   make package
   # 测试包
   ```

8. **推送并创建拉取请求**
   ```bash
   git push origin feature-name
   # 在 GitHub 上创建拉取请求
   ```

### 代码风格

- 遵循现有代码格式
- 使用有意义的变量名
- 为复杂逻辑添加注释
- 确保所有函数都有适当的错误处理
- 提交前测试所有更改

### 测试

- 提交前运行 `make ci-test`
- 如果可能，在多个系统上测试
- 验证性能不会下降
- 检查所有输出文件是否正确生成

### 文档

- 为新功能更新本指南
- 为新目标添加示例
- 更新 Makefile 中的帮助文本
- 记录任何破坏性更改

---

## 性能调优

### 系统优化

1. **内存配置**
   ```bash
   # 确保足够的内存
   free -h

   # 如果 RAM 可用，为临时文件使用 tmpfs
   sudo mount -t tmpfs -o size=1G tmpfs /tmp
   ```

2. **网络优化**
   ```bash
   # 测试到数据源的网络速度
   curl -o /dev/null http://www.iwik.org/ipcountry/mikrotik/CN

   # 使用本地 DNS 缓存
   sudo systemctl enable --now dnsmasq
   ```

3. **CPU 优化**
   ```bash
   # 监控 CPU 使用情况
   htop

   # 根据 CPU 核心数调整线程数
   export PARALLEL_THREADS=$(nproc)
   ```

### 基准测试

定期性能监控：

```bash
# 创建基准历史
mkdir -p benchmarks
make benchmark > "benchmarks/benchmark-$(date +%Y%m%d-%H%M%S).txt"

# 随时间比较性能
diff benchmarks/benchmark-20240101-120000.txt benchmarks/benchmark-20240102-120000.txt
```

### 优化策略

1. **缓存**：启用下载的本地缓存
2. **并行处理**：根据系统资源调整线程数
3. **网络优化**：在可用时使用本地镜像或 CDN
4. **内存管理**：监控和优化内存使用模式

---

## 安全考虑

### 网络安全

- 在可用时使用 HTTPS 下载
- 默认启用 TLS 证书验证
- 用户代理头适当标识客户端

### 文件权限

- 脚本以当前用户权限执行
- 系统安装使用适当的权限（脚本 755，数据 644）
- 使用适当权限保护配置文件

### 系统集成

- Systemd 服务以最小所需权限运行
- 明确设置环境变量
- 验证文件路径以防止目录遍历

### 建议

1. **定期更新**：保持脚本和依赖项更新
2. **监控**：监控系统日志中的异常活动
3. **访问控制**：限制谁可以修改配置文件
4. **审计跟踪**：为生产部署启用日志记录

---

## 常见问题

### Q: 我应该多久运行一次生成？
A: 对于大多数用户，通过 systemd 定时器进行的每日自动更新就足够了。定时器配置为每天运行一次，时间随机化以避免服务器负载峰值。

### Q: 我可以自定义生成的 RouterOS 脚本吗？
A: 可以，您可以修改 `lib/processor.sh` 文件中的模板，但在部署前务必彻底测试更改。

### Q: 如果下载源不可用怎么办？
A: Makefile 包含重试逻辑和超时处理。如果源仍然不可用，考虑使用缓存数据或替代镜像。

### Q: 如何减少生成期间的内存使用？
A: 您可以减少 `PARALLEL_THREADS` 环境变量，或使用跳过某些验证步骤的 `fast` 目标。

### Q: 我可以在非 Linux 系统上使用吗？
A: Makefile 主要为 Linux 设计，但经过修改可能适用于其他 Unix 类系统。Systemd 目标需要 Linux。

### Q: 如何备份我的配置？
A: 备份配置目录和任何自定义域名列表：
   ```bash
   sudo cp -r /etc/chnroute /path/to/backup/
   ```

### Q: 我可以同时运行多个实例吗？
A: 不建议，因为这可能导致冲突。临时目录系统使用唯一名称，但输出文件会发生冲突。

---

## 支持和社区

### 获取帮助

- **文档**：本指南和 `make help` 命令
- **问题**：GitHub Issues 位于 https://github.com/ruijzhan/chnroute/issues
- **讨论**：GitHub Discussions 用于一般问题
- **Wiki**：项目 Wiki 用于其他文档

### 贡献

我们欢迎贡献！请参阅[贡献指南](#贡献指南)部分获取指导。

### 许可证

本项目根据仓库 LICENSE 文件中指定的条款获得许可。

---

*最后更新：$(date '+%Y年%m月%d日')*