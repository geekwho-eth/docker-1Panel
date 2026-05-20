# 1Panel Docker 镜像（DooD 方案）

<div style="display: flex; justify-content: center; gap: 10px; align-items: center;">
  <a href="/README.md"><img alt="English" src="https://img.shields.io/badge/English-d9d9d9"></a>
  <a href="/docs/README_cn.md"><img alt="中文(简体)" src="https://img.shields.io/badge/中文(简体)-d9d9d9"></a>
  <a href="https://github.com/geekwho-eth/docker-1Panel/actions/workflows/main.yml">
    <img alt="GitHub Actions Status" src="https://github.com/geekwho-eth/docker-1Panel/actions/workflows/main.yml/badge.svg">
  </a>
</div>

## 1Panel Docker 镜像统计数据

<div style="display: flex; justify-content: center; gap: 8px; flex-wrap: wrap;">
  <a href="https://hub.docker.com/r/caijiamx/1panel"><img src="https://img.shields.io/docker/pulls/caijiamx/1panel.svg" alt="Docker Pulls"></a>
  <a href="https://hub.docker.com/r/caijiamx/1panel"><img src="https://img.shields.io/docker/stars/caijiamx/1panel.svg" alt="Docker Stars"></a>
  <a href="https://hub.docker.com/r/caijiamx/1panel"><img src="https://img.shields.io/docker/image-size/caijiamx/1panel/dood-2.0.17-alpine-cn.svg" alt="Docker Image Size"></a>
</div>

本仓库用于构建并发布 1Panel 的 Docker 镜像，采用 DooD（Docker-out-of-Docker）设计，复用宿主机 Docker 引擎，使用 supervisord 管理 1Panel 进程，避免在容器内运行 systemd 或使用 --privileged。

- 当前镜像最新版本：2.1.12
- 支持多版本：2.0.0 ~ 2.1.12（通过变量替换注入）
- 支持多系统：ubuntu、centos、alpine
- 支持多架构：amd64、arm64（buildx + QEMU）
- 镜像命名：caijiamx/1panel:dood-{version}-{os}-cn
- 构建方式：GitHub Actions 工作流 + 本地 Makefile

提示：本方案适合可信、单租户环境，生产环境使用需严格控制访问并做好防护策略（建议WAF+网络防火墙）。

## 目录

- [使用说明](#使用说明)
  - [特性与设计](#特性与设计)
  - [支持系统与命名规范](#支持系统与命名规范)
  - [快速开始](#快速开始)
    - [docker run](#docker-run)
    - [docker-compose](#docker-compose)
  - [镜像拉取](#镜像拉取)
  - [目录结构](#目录结构)
- [实现方案](#实现方案)
  - [systemctl 注释说明](#systemctl-注释说明)
  - [supervisord 说明](#supervisord-说明)
  - [DooD说明](#DooD说明)
  - [为什么选择DooD](#为什么选择DooD)
  - [DooD vs DinD vs Sysbox对比](#DooD-vs-DinD-vs-Sysbox对比)
- [构建说明](#构建说明)
  - [本地构建（Makefile）](#本地构建makefile)
  - [GitHub Actions 构建](#github-actions-构建)
- [升级说明](#升级说明)
  - [版本升级步骤](#版本升级步骤)
- [常见问题](#常见问题)
  - [服务&功能限制](#服务&功能限制)
  - [FAQ](#FAQ)

## 使用说明

### 特性与设计

- DooD：容器共享宿主机 Docker 引擎与缓存，构建更快、占用更小。
- 进程管理：容器内不运行 systemd，改用 supervisord 前台托管 1panel-core 与 1panel-agent。
- 版本变量注入：Dockerfile 中包含占位符，示例（ubuntu）：
  ```
  RUN bash /1panel/quick_start.sh v{%OnePanel_Version%}
  ```
  构建时以 sed 将 {%OnePanel_Version%} 替换为具体版本（2.0.0~2.0.15）。
- 多架构：buildx + QEMU 生成 linux/amd64、linux/arm64 镜像；脚本会自动识别归档架构并下载对应包。

### 支持系统与命名规范

- 系统：ubuntu、centos、alpine
- 版本：2.0.0 ~ 2.0.15
- 架构：amd64、arm64（自动匹配下载包）
- 标签规范：
  - caijiamx/1panel:dood-{version}-{os}-cn
  - 例：caijiamx/1panel:dood-2.0.15-ubuntu-cn

### 快速开始

#### docker run
容器构建自动生成用户名、密码、端口，可启动后在容器内调整。这里假设面板默认端口为 8888。运行命令示例：

```bash
docker run -d --name 1panel --restart unless-stopped \
  -p 8888:8888 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /var/lib/docker/volumes:/var/lib/docker/volumes \
  -v /1panel_app/data/:/opt/ \
  caijiamx/1panel:dood-2.0.15-ubuntu-cn
```

初始化（容器内）：

**重要的事情讲三遍！！！**

**首次部署务必修改用户名/密码/入口!**

**首次部署务必修改用户名/密码/入口!**

**首次部署务必修改用户名/密码/入口!**

```bash
docker exec -it 1panel bash
# 查看安全入口与当前配置
1panel user-info

# 修改端口/用户/密码
1panel update port
1panel update username
1panel update password
```

#### docker-compose

仓库内提供示例 docker-compose.yml（DooD 必要挂载已包含）：
```yaml
services:
  one_panel:
    image: caijiamx/1panel:dood-2.0.15-ubuntu-cn
    container_name: 1panel
    restart: unless-stopped
    ports:
      - "8888:8888"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - /var/lib/docker/volumes:/var/lib/docker/volumes
      - /1panel_app/data/:/opt/
```

docker-compose.yml关键字段：

- image：镜像标签如 caijiamx/1panel:dood-2.0.15-ubuntu-cn
- ports：对外端口映射，示例 8888:8888
- volumes（DooD 必要挂载）：
  - /var/run/docker.sock:/var/run/docker.sock
  - /var/lib/docker/volumes:/var/lib/docker/volumes
  - /panel_app/data/:/opt/  # 建议统一此路径，便于数据持久化
- healthcheck：简单进程检查（core/agent 是否存在）
- extra_hosts：host-gateway 方便访问宿主机
- networks：使用外部网络 one_panel（先创建网络）

启动服务：

```
docker network create one_panel
docker compose up -d
```

提示：

- 不使用 --privileged、不挂载 /sys/fs/cgroup，不在容器内运行 systemd。
- 持久化 /opt/（默认安装到 /opt/1panel）。

### 镜像拉取

```bash
# Ubuntu
docker pull caijiamx/1panel:dood-2.0.15-ubuntu-cn
# CentOS
docker pull caijiamx/1panel:dood-2.0.15-centos-cn
# Alpine
docker pull caijiamx/1panel:dood-2.0.15-alpine-cn
```

将 {version} 替换为 2.0.0~2.0.15，{os} 替换为 ubuntu/centos/alpine。

### 目录结构

```
alpine/   # Alpine Dockerfile 模板
centos/   # CentOS Dockerfile 模板
ubuntu/   # Ubuntu Dockerfile 模板
hack/     # 安装与 systemctl 注释脚本、supervisord 配置
hack_cn/     # 安装与 systemctl 注释脚本、supervisord 配置
.github/workflows/main.yml  # GitHub Action CI 多版本/多系统/多架构构建与推送
docker-compose.yml          # 容器运行配置
Makefile                    # 本地构建/推送/矩阵任务
```
## 实现方案

### systemctl 注释说明

- 脚本：hack/fix_systemctl_start_cmd.sh
- 作用：在安装包解压后、执行 install.sh 前，注释掉 systemctl 相关步骤，避免容器依赖 systemd。
- 影响：面板内基于 systemctl 的检查/操作可能不可用或显示异常；进程管理交由 supervisord。



#### 涉及 systemctl 管理的服务

20250909 由GitHub copilot 生成

根据 1Panel-dev/1Panel 仓库代码，涉及 systemctl 管理的服务主要有以下几类。如果 systemctl 不可用（如 WSL、部分容器、极简发行版等），这些服务的启动/停止/重启/状态查询都将受到影响，面板功能也会有部分不可用或异常。

| 服务名称                      | 作用/描述                    | systemctl不可用时影响                    | 代码依据/说明                                                | 说明                                            |
| ----------------------------- | ---------------------------- | ---------------------------------------- | ------------------------------------------------------------ | ----------------------------------------------- |
| 1panel-core.service           | 1Panel 核心服务              | 无法启动/重启/查询状态，面板核心功能异常 | core/app/service/setting.go, common.go、core/app/service/upgrade.go、RestartService (common.go), UpdateBindInfo/UpdatePort/UpdateSSL (setting.go), UpgradeService.Upgrade | 面板配置、端口、SSL、主控服务、升级、回滚等重启 |
| 1panel-agent.service          | 1Panel Agent服务（节点服务） | 无法启动/重启/查询状态，节点管理异常     | agent/utils/common.go, common.go、core/app/service/upgrade.go、RestartService (common.go), UpgradeService.Upgrade | 节点服务重启、升级后重启、节点异常恢复          |
| docker.service, docker.socket | Docker 守护进程              | 容器管理、重启、停止等功能不可用         | agent/app/service/docker.go                                  | 容器服务、应用容器管理、配置变更后重启          |
| fail2ban.service              | 防暴力破解服务（Fail2Ban）   | 防护规则无法启停、重载或查询状态         | agent/utils/toolbox/fail2ban.go                              | 防护规则启停、重载、状态查询                    |
| clamav/clamd/freshclam        | 病毒扫描服务（ClamAV）       | 杀毒、病毒库更新相关功能不可用           | agent/app/service/clam.go                                    | 杀毒服务启停、查杀操作、病毒库更新              |
| ssh/sshd.service              | SSH 服务                     | 远程管理、SSH配置功能异常                | agent/app/service/ssh.go                                     | SSH服务启停、配置变更、安全加固                 |
| supervisor/supervisord        | 进程守护服务（Supervisor）   | 守护进程管理功能不可用                   | 前端文案、脚本管理相关                                       | 守护进程启停、自动化任务、脚本运行              |

#### 代码说明

1. **所有涉及 systemctl 的服务都依赖 systemd**
   - 代码中通过 systemctl 命令（如 restart, start, stop, status, is-active, is-enabled）管理服务。
   - 如 systemctl 不可用，这些命令将执行失败，服务无法被面板控制。
2. **Docker、SSH、Fail2Ban、ClamAV、Supervisor 这些常用服务都通过 systemctl 集成**
   - 面板会自动调用 systemctl 重启、检测状态，如果命令失败则功能不可用或报错。
   - 部分服务有 snap 或其它方式检测
   - 代码如 agent/utils/systemctl/systemctl.go 有 snap 服务的检测和操作，但依赖 snap 环境，非 systemctl 的通用替代。
3. **面板自身服务（core/agent）也通过 systemctl 管理**
   - 面板自身无法自我重启/恢复，也无法远程管理节点。

------

#### systemctl 不可用时影响的面板功能

- 面板显示服务异常或未运行
- 无法通过面板启停 Docker、Agent、SSH、守护进程等
- 部分面板配置修改后无法自动生效（如端口、SSL等）

详细参考：[服务&功能限制](#服务&功能限制)

#### 主要接口/函数举例

- `/api/v1/setting/update_port` —— 端口修改，涉及 `RestartService` 调用 systemctl 重启 core 服务
- `/api/v1/setting/update_ssl` —— SSL 配置修改后，涉及 systemctl 重启 core 服务
- `/api/v1/upgrade/upgrade` —— 升级接口，涉及 `UpgradeService.Upgrade`，systemctl 重启 core/agent 服务
- `/api/v1/upgrade/rollback` —— 回滚接口，涉及 `UpgradeService.handleRollback`，systemctl 重启 core/agent 服务
- `/api/v1/docker/restart` —— 容器管理，调用 `OperateDocker`，systemctl 重启 docker 服务
- `/api/v1/agent/restart` —— 节点管理，重启 agent 服务
- `/api/v1/fail2ban/operate` —— 安全防护策略启停
- `/api/v1/clam/operate` —— 病毒查杀服务启停
- `/api/v1/ssh/operate` —— SSH 服务启停与配置
- `/api/v1/supervisor/operate` —— 守护进程服务启停



Upgrade 相关 systemctl 调用补全说明

- 代码如 `core/app/service/upgrade.go` 的 `UpgradeService.Upgrade` 实现，升级成功后会调用：
  - `systemctl daemon-reload`
  - `systemctl restart 1panel-agent.service`
  - `systemctl restart 1panel-core.service`
- 回滚也会涉及 systemctl 重启相关服务。
- 其他分支或历史版本中，升级、回滚等函数如 `handleRollback`、`handleBackup` 也会调用 `systemctl daemon-reload && systemctl restart 1panel.service`。

### supervisord 说明

- 配置：hack/supervisord.conf（nodaemon=true 前台运行）
- 托管：
  - program:1panel-core -> /usr/bin/1panel-core
  - program:1panel-agent -> /usr/bin/1panel-agent
- 常用命令：
```bash
supervisorctl status
supervisorctl restart all
supervisorctl reload
```

#### 为什么不使用systemd

运行一个 systemd ，通常需要这样设置：

```shell
docker run -d -it \
  --name ubuntu2404-systemd \
  --privileged \
  --cgroupns=host \
  --tmpfs=/run \
  --tmpfs=/tmp \
  --volume=/sys/fs/cgroup:/sys/fs/cgroup:rw \
  trfore/docker-ubuntu2404-systemd:latest
```


核心风险点在于 `--privileged + --cgroupns=host + --volume /sys/fs/cgroup`：

1. **宿主机隔离被打破**
   - `--privileged` 让容器有所有 Linux capabilities（cap_sys_admin、cap_net_admin 等），等同 root。
   - 可以直接操作宿主机设备文件、网络栈，甚至加载内核模块。

2. **cgroup 控制泄露**
   - `--cgroupns=host` + 挂载 `/sys/fs/cgroup` → 容器能操作宿主机的 cgroups，修改 CPU/内存限制、杀死其他容器的进程。

3. **宿主机提权/逃逸**
   - 特权容器几乎等于在宿主机上直接跑 root，隔离形同虚设。
   - 如果攻击者拿到这个容器的 shell，就相当于拿到了宿主机 root。

## 结论

1. 不要在生产环境使用 `--privileged` 参数。
2. 现有阶段 docker 运行 systemd 不可行。
3. 作为备用方案，可使用 supervisord 来服务管理。

参考版本库：

1. https://github.com/trfore/docker-ubuntu2404-systemd
2. https://github.com/antmelekhin/docker-systemd
3. 建议只在开发环境使用。

### DooD说明

本指南提供一种“非官方”的 1Panel Docker 部署方案：

1. 所谓的 DooD，就是 Docker Out of Docker。简单来讲，就是在一个 docker 容器内部调用外部的 Docker。
   最简单的实现方式，共享 Host docker 的 sock 和 volumes。
2. 使用 DooD（Docker‑out‑of‑Docker）复用宿主机 Docker 引擎，配合 supervisord 管理进程，避免在容器内运行 systemd 与 --privileged。
3. 请在可信/单租户场景谨慎使用。需单独配置安全规则，如 WAF、防火墙。



容器内需复用宿主机 Docker 以安装/编排应用，需挂载：

- /var/run/docker.sock:/var/run/docker.sock
- /var/lib/docker/volumes:/var/lib/docker/volumes
- 数据持久化目录（示例将 /1panel_app/data/ 映射到容器内 /opt/）

参考docker-compose.yml：

```yml
# 关键配置
volumes:
      # make docker out of docker work
      - /var/run/docker.sock:/var/run/docker.sock
      - /var/lib/docker/volumes:/var/lib/docker/volumes
      - /1panel_app/data/:/opt/
```



### 为什么选择DooD

### 方案选型：DooD vs DinD vs Sysbox

- DooD（本指南采用）
  - 优点：共享宿主机镜像缓存，构建快、占用少；实现简单
  - 缺点：安全风险高（容器可控制宿主机 Docker），不适合多租户
  - 适用：本机/可信环境、个人或单租户 CI
- DinD
  - 优点：容器内外引擎隔离
  - 缺点：需要 --privileged，存在逃逸风险
  - 适用：临时环境/非生产安全场景，谨慎使用
- Sysbox
  - 相对更安全的 DinD 替代，但对内核/发行版有要求，生态不如官方成熟

结论：

在当前条件下选用 DooD + supervisord，明确拒绝在生产环境用 --privileged 跑 systemd。

### DooD vs DinD vs Sysbox对比

| 特性维度     | **DooD (Docker-out-of-Docker)**                              | **DinD (Docker-in-Docker)**                                  | **Sysbox**                                                   |
| ------------ | ------------------------------------------------------------ | ------------------------------------------------------------ | ------------------------------------------------------------ |
| **基本原理** | 容器内挂载宿主机 Docker socket，直接复用宿主机 Docker 引擎   | 在容器中运行独立的 Docker 引擎（DinD 镜像）                  | 使用 Sysbox 作为底层 runtime，容器内可安全运行 Docker / K8s 等系统级 workload |
| **优点**     | - 共享宿主机镜像缓存，构建速度快- 节省磁盘空间               | - 简单易用，官方有现成 DinD 镜像- 容器内外引擎隔离，避免直接操作宿主机容器 | - 无需 privileged 容器- 使用 Linux user namespace 提供强隔离- 支持系统级 workload（Docker/K8s）- 与 Docker/K8s 无缝集成，使用方式类似 `runc` |
| **缺点**     | - 安全风险极大：容器可直接控制宿主机 Docker，甚至删除宿主机所有容器- 不适合多租户环境- bind mount 限制，某些功能（如 volume 挂载）可能失效 | - 需要 privileged 权限运行，容器内 root = 宿主机 root- root 拥有全部 Linux capabilities，存在逃逸风险- 可直接访问宿主机设备和 /proc、/sys，能修改内核状态 | - 需要较新的 Linux 内核- 目前只支持部分 Linux 发行版- 仍在社区发展中，生态不如 Docker 官方成熟 |
| **安全风险** | 高：容器内用户几乎等于宿主机 root 权限                       | 高：privileged 容器 = 宿主机 root + 全 capability，容易被利用 | 相对低：用户隔离（userns）、procfs/sysfs 虚拟化、syscall 拦截，避免直接 root 映射 |
| **适用场景** | - 本地开发临时测试- 单人或可信环境                           | - CI/CD 流水线需要独立 Docker 环境- 简单快速的沙箱环境       | - CI/CD 多租户 runner- 安全沙箱环境- 在容器中运行系统级 workload（如 Docker/K8s） |
| **推荐程度** | ✅ 推荐（需控制访问权限）                                     | ⚠️ 谨慎使用（非生产安全场景）                                 | ❌ 不推荐（配置复杂）                                         |

参考链接：

1. [Docker-in-Docker: Containerized CI Workflows](https://www.docker.com/resources/docker-in-docker-containerized-ci-workflows-dockercon-2023/)

## 构建说明

### 本地构建（Makefile）

依赖：Docker Desktop（含 buildx），已登录 DockerHub（如需推送）。

列出命令：
```bash
make help
```

常用命令：
- 初始化构建器（一次）：make builder
- 构建单个镜像（不推送）：make build OS=ubuntu VERSION=2.0.15 ONEPANEL_TYPE=cn
- 推送单个镜像：make push OS=centos VERSION=2.0.0 ONEPANEL_TYPE=cn
- 本机调试（加载到本地）：make load OS=ubuntu VERSION=2.0.15
- 多架构构建（不推送）：make buildx OS=centos VERSION=2.0.0
- 多架构构建并推送：make push OS=alpine VERSION=2.0.15
- 批量矩阵推送（3 OS × 2.0.0~2.0.15）：make matrix-push

变量：
- OS=ubuntu|centos|alpine
- VERSION=2.0.0~2.0.15（注入到 {%OnePanel_Version%}）
- ONEPANEL_TYPE=pro|cn（注入到 {%OnePanel_Type%}）
- PLATFORMS=linux/amd64,linux/arm64（可改为单架构）
- IMAGE_REPO=caijiamx/1panel，IMAGE_TAG_PREFIX=dood

构建示例

```bash
# 调试单个命令
make -n build OS=ubuntu VERSION=2.0.15 ONEPANEL_TYPE=cn

# 构建单个镜像
make build OS=ubuntu VERSION=2.0.15 ONEPANEL_TYPE=cn
```

命名规范：caijiamx/1panel:dood-{version}-{os}-cn

### GitHub Actions 构建

工作流：.github/workflows/main.yml（“Build and Push 1Panel Images”）

- 触发方式：推送分支 main/dev 或手动 workflow_dispatch
- 构建矩阵：OS=[ubuntu, centos, alpine]；VERSION=[2.0.0..2.0.15]
- 多架构：linux/amd64, linux/arm64（使用 setup-qemu + buildx）
- 版本替换：构建前用 sed 将 Dockerfile 中 v{%OnePanel_Version%} 替换为具体版本
- 推送目标：caijiamx/1panel:dood-{version}-{os}
- 凭据：需要在仓库 Secrets 配置
  - DOCKERHUB_USERNAME
  - DOCKERHUB_TOKEN
- 使用方式：Actions 页面选择 main 工作流，点 Run workflow，选择 os 与 version

## 升级说明

从 v2.0.0 -> v2.0.11升级为例，准备工作：

1. 备份原始镜像，如 v2.0.0
2. 备份挂载数据。
3. 停止容器。

### 版本升级步骤

开始升级步骤：

1. 构建/拉取新版本镜像（例如 2.0.11）
2. 手动修改版本号
3. 启动新服务。

### 手动修改版本号

官方安装会自动维护版本号；本镜像方案需手动同步版本号（示例使用 sqlite3）：
```bash
sudo apt-get update && apt-get install -y sqlite3
cp /opt/1panel/db/core.db  /opt/1panel/db/core.db.bak
cp /opt/1panel/db/agent.db /opt/1panel/db/agent.db.bak
sqlite3 /opt/1panel/db/core.db "UPDATE settings SET value='v2.0.11' WHERE key='SystemVersion';"
sqlite3 /opt/1panel/db/agent.db "UPDATE settings SET value='v2.0.11' WHERE key='SystemVersion';"
```
更新镜像后重启容器（保留 /opt/ 数据卷）。

## 常见问题

### 服务&功能限制

1. 面板->右下角更新->“立即升级”不可用。官方升级逻辑依赖 systemctl 停启服务。
2. ~~面板->容器功能不可用。服务判定 docker 存活依赖 systemctl status，后续会优化不再依赖 systemctl。~~
3. nginx_status 默认仅监听 127.0.0.1，需自行调整。参考：[OpenResty 当前状态报错](#OpenResty 当前状态报错)
4. 部分应用安装时挂载路径出现异常，需按实际路径修正。
5. 1panel-core&1panel-agent 运行用户为 root。指定用户 nobody 运行的话，服务 1panel-agent 会挂掉。
6. 工具箱->进程守护、FTP、Fail2ban 不可用。
7. v2.0.11 版本改进了 docker 服务判定逻辑，面板->容器功能基本可用（完整功能未全面测试）。
8. v2.0.11 新增磁盘管理，不建议使用该功能。
9. v2.0.12 - v2.0.15 待验证兼容性。

面板不可用功能表格如下：

| 功能                                                         | 是否可用 | 备注       |
| ------------------------------------------------------------ | -------- | ---------- |
| 面板->立即升级（右下角）                                     | ❌        |            |
| 网站->网站->OpenResy设置->当前状态<br/>网站->运行环境->php-fpm容器状态检查 | ❌        |            |
| 工具箱->进程守护、FTP、Fail2ban、磁盘管理                    | ❌        | 功能未测试 |
| 高级功能                                                     | ❌        | 功能未测试 |

### FAQ

#### 安装应用报错 “Are you trying to mount a directory onto a file”

- 原因：主机路径与容器内路径不匹配（文件/目录）
- 处理：按应用需求修正宿主机路径与映射关系

举例：

```yml
# 容器内docker-compose.yml配置
- ${WEBSITE_DIR}:/www -> /1panel_app/data/1panel/www:/www
# 容器内默认 1panel 项目目录:/opt/1panel
```



常用变量

```
# 1panel 使用变量，用于文件 docker-compose.yml
${CONTAINER_NAME} # 自定义容器名

${IMAGE_NAME} # 自定义镜像名

${PANEL_APP_PORT_HTTP} # 自定义端口

${PANEL_WEBSITE_DIR} # 默认为 /opt/1panel/www

${WEBSITE_DIR} # 默认为 /opt/1panel/www
```



#### OpenResty 当前状态报错

报错信息：

```
服务内部错误: Get "http://127.0.0.1/nginx_status": dial tcp 127.0.0.1:80: connect: connection refused
```

原因：健康检查 127.0.0.1 访问失败，容器内访问 127.0.0.1 会访问 1panel 监听80端口，而 openresty 是单独的容器，1panel -> openresty 可以走 `http://openresty`。

处理：可为健康检查添加 `host：server_name 127.0.0.1 openresty;` 正确访问地址：<http://openresty/nginx_status>。

彻底解决问题，需要修改官方实现代码：

```go
# 文件路径：agent/app/service/nginx.go
func (n NginxService) GetStatus() (response.NginxStatus, error) {
  // bala
  url := "http://127.0.0.1/nginx_status"
	if httpPort != 80 {
		url = fmt.Sprintf("http://127.0.0.1:%v/nginx_status", httpPort)
	}
	useDoodMode := true
	if useDoodMode {
		localServerName := "127.0.0.1"
		openrestyContainerName := "openresty"
		url = strings.ReplaceAll(url, localServerName, openrestyContainerName)
	}
  // bala
}
```



#### 反向代理配置

WebSocket/升级头

```nginx
proxy_http_version 1.1;
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection "upgrade";
proxy_set_header Host $host;  # 若需要固定后端 Host，请显式设置
```



#### 安全入口与账户信息

- 开启安全入口后，通过容器内命令查看：1pctl user-info

- 首次部署务必修改用户名/密码/入口

- 建议WAF+网络防火墙做好访问控制。

  

#### Cloudflare 常见端口

- HTTP：80, 8080, 8880, 2052, 2082, 2086, 2095
- HTTPS：443, 2053, 2083, 2087, 2096, 8443



#### 资源与超时

CPU 限额过低可能导致接口超时（偶尔 5xx/超时），建议 1.0~1.5 core。



## 安全提示

- DooD 允许容器控制宿主机 Docker，有一定安全风险。仅在可信、单租户环境使用。
- 建议配置网络防火墙允许访问的IP以及端口。
- 建议对面板做访问控制：域名限制、IP端口、机器隔离。

## 参考项目

1. [okxlin/docker-1panel](https://github.com/okxlin/docker-1panel)、[tangger2000/1panel-dood](https://github.com/tangger2000/1panel-dood)（项目已归档）
2. [purainity/docker-1panel-v2](https://github.com/purainity/docker-1panel-v2)：[dph5199278/docker-1panel](https://github.com/dph5199278/docker-1panel)、[Xeath/1panel-in-docker](https://github.com/Xeath/1panel-in-docker)
3. 

## 维护者

- GeekWho <geekwho_eth@outlook.com>



[返回首页](index.html)