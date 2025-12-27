# 1Panel Docker Image (DooD Approach)

<p align="center">
  <a href="/README.md"><img alt="English" src="https://img.shields.io/badge/English-d9d9d9"></a>
  <a href="/docs/README_cn.md"><img alt="中文(简体)" src="https://img.shields.io/badge/中文(简体)-d9d9d9"></a>
  <a href="https://github.com/geekwho-eth/docker-1Panel/actions/workflows/main.yml">
    <img alt="GitHub Actions Status" src="https://github.com/geekwho-eth/docker-1Panel/actions/workflows/main.yml/badge.svg">
  </a>
</p>

## 1Panel Docker Image Stats

[![Docker Pulls](https://img.shields.io/docker/pulls/caijiamx/1panel.svg)](https://hub.docker.com/r/caijiamx/1panel)
[![Docker Stars](https://img.shields.io/docker/stars/caijiamx/1panel.svg)](https://hub.docker.com/r/caijiamx/1panel)
[![Docker Image Size (dood-2.0.16-alpine-cn)](https://img.shields.io/docker/image-size/caijiamx/1panel/dood-2.0.16-alpine-cn.svg)](https://hub.docker.com/r/caijiamx/1panel)

This repository builds and publishes Docker images for 1Panel using the DooD (Docker-out-of-Docker) design. It reuses the host Docker engine and uses supervisord to manage 1Panel processes, avoiding running systemd in containers or using --privileged.

- Current latest image version: 2.0.16
- Multi-version support: 2.0.0 ~ 2.0.16 (injected by placeholder replacement)
- Multiple OS: ubuntu, centos, alpine
- Multi-arch: amd64, arm64 (buildx + QEMU)
- Image naming: caijiamx/1panel:dood-{version}-{os}
- Build method: GitHub Actions workflow + local Makefile

Note: This solution targets trusted, single-tenant environments. For production, strictly control access and deploy proper protections (recommend WAF + network firewall).

## Table of Contents

- [Usage](#usage)
  - [Features & Design](#features--design)
  - [Supported OS and Tag Convention](#supported-os-and-tag-convention)
  - [Quick Start](#quick-start)
    - [docker run](#docker-run)
    - [docker-compose](#docker-compose)
  - [Pull Images](#pull-images)
  - [Directory Layout](#directory-layout)
- [Implementation](#implementation)
  - [systemctl Notes](#systemctl-notes)
  - [supervisord Notes](#supervisord-notes)
  - [About DooD](#about-dood)
  - [Why DooD](#why-dood)
  - [DooD vs DinD vs Sysbox Comparison](#dood-vs-dind-vs-sysbox-comparison)
- [Build Guide](#build-guide)
  - [Local Build (Makefile)](#local-build-makefile)
  - [GitHub Actions Build](#github-actions-build)
- [Upgrade Guide](#upgrade-guide)
  - [Version Upgrade Steps](#version-upgrade-steps)
- [FAQ](#faq)
  - [Service & Feature Limitations](#service--feature-limitations)
  - [Q&A](#qa)

## Usage

### Features & Design

- DooD: Containers share the host Docker engine and cache for faster builds and smaller footprint.
- Process management: Do not run systemd in the container; instead use supervisord (foreground) to manage 1panel-core and 1panel-agent.
- Version variable injection: Dockerfile contains placeholders, example (ubuntu):
  ```
  RUN bash /1panel/quick_start.sh v{%OnePanel_Version%}
  ```
  During build, sed replaces {%OnePanel_Version%} with a concrete version (2.0.0~2.0.11).
- Multi-arch: buildx + QEMU produce linux/amd64 and linux/arm64 images; scripts auto-detect archive arch and download the correct package.

### Supported OS and Tag Convention

- OS: ubuntu, centos, alpine
- Versions: 2.0.0 ~ 2.0.11
- Architectures: amd64, arm64 (auto-match download)
- Tag format:
  - caijiamx/1panel:dood-{version}-{os}
  - Example: caijiamx/1panel:dood-2.0.11-ubuntu

### Quick Start

#### docker run
Username, password, and port are auto-generated at image build; you can adjust them after the container starts. Assume the panel port is 8888. Example:

```bash
docker run -d --name 1panel --restart unless-stopped \
  -p 8888:8888 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /var/lib/docker/volumes:/var/lib/docker/volumes \
  -v /1panel_app/data/:/opt/ \
  caijiamx/1panel:dood-2.0.11-ubuntu
```

Initialization (inside container):

Important reminder x3:

Change username/password/entry on first deployment!

Change username/password/entry on first deployment!

Change username/password/entry on first deployment!

```bash
docker exec -it 1panel bash
# Check security entry and current settings
1panel user-info

# Change port/user/password
1panel update port
1panel update username
1panel update password
```

#### docker-compose

An example docker-compose.yml is provided (with required DooD mounts):

```yaml
services:
  one_panel:
    image: caijiamx/1panel:dood-2.0.11-ubuntu
    container_name: 1panel
    restart: unless-stopped
    ports:
      - "8888:8888"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - /var/lib/docker/volumes:/var/lib/docker/volumes
      - /1panel_app/data/:/opt/
```

Key fields in docker-compose.yml:

- image: e.g., caijiamx/1panel:dood-2.0.11-ubuntu
- ports: external port mapping, e.g., 8888:8888
- volumes (required for DooD):
  - /var/run/docker.sock:/var/run/docker.sock
  - /var/lib/docker/volumes:/var/lib/docker/volumes
  - /panel_app/data/:/opt/  # unify this path for data persistence
- healthcheck: simple process check (core/agent present)
- extra_hosts: host-gateway to access the host
- networks: use external network one_panel (create first)

Start:

```
docker network create one_panel
docker compose up -d
```

Notes:

- No --privileged, no /sys/fs/cgroup mount, no systemd inside the container.
- Persist /opt/ (default install path /opt/1panel).

### Pull Images

```bash
# Ubuntu
docker pull caijiamx/1panel:dood-2.0.11-ubuntu
# CentOS
docker pull caijiamx/1panel:dood-2.0.11-centos
# Alpine
docker pull caijiamx/1panel:dood-2.0.11-alpine
```

Replace {version} with 2.0.0~2.0.11 and {os} with ubuntu/centos/alpine.

### Directory Layout

```
alpine/   # Alpine Dockerfile template
centos/   # CentOS Dockerfile template
ubuntu/   # Ubuntu Dockerfile template
hack/     # install and systemctl-comment scripts, supervisord config
hack_cn/  # install and systemctl-comment scripts, supervisord config
.github/workflows/main.yml  # GitHub Actions: multi-version/os/arch build & push
docker-compose.yml          # container run config
Makefile                    # local build/push/matrix
```

## Implementation

### systemctl Notes

- Script: hack/fix_systemctl_start_cmd.sh
- Purpose: After extracting the installer and before running install.sh, comment out systemctl-related steps to avoid systemd dependency.
- Impact: Panel checks/operations based on systemctl may not work or display incorrectly; process management is handled by supervisord.

#### Services managed by systemctl

Generated by GitHub Copilot on 2025-09-09

Based on 1Panel-dev/1Panel code, the following services are mainly managed by systemctl. If systemctl is unavailable (e.g., WSL, some containers, minimal distros), start/stop/restart/status will be affected and some panel features will be unavailable or abnormal.

| Service Name                 | Description                         | Impact when systemctl unavailable          | Code references                                            | Notes                                          |
| --------------------------- | ----------------------------------- | ------------------------------------------ | ---------------------------------------------------------- | ----------------------------------------------|
| 1panel-core.service         | 1Panel core service                 | Cannot start/restart/query; core broken    | core/app/service/setting.go, common.go, core/app/service/upgrade.go, RestartService (common.go), UpdateBindInfo/UpdatePort/UpdateSSL (setting.go), UpgradeService.Upgrade | Config, port, SSL, master, upgrade, rollback  |
| 1panel-agent.service        | 1Panel agent (node)                 | Cannot start/restart/query; node issues    | agent/utils/common.go, common.go, core/app/service/upgrade.go, RestartService (common.go), UpgradeService.Upgrade | Node restart, post-upgrade restart, recovery  |
| docker.service, docker.socket | Docker daemon                      | Container mgmt features unusable           | agent/app/service/docker.go                                  | Container services, config changes restart     |
| fail2ban.service            | Fail2Ban anti-bruteforce            | Rules cannot be toggled/reloaded/status    | agent/utils/toolbox/fail2ban.go                              | Enable/disable/reload/status                   |
| clamav/clamd/freshclam      | ClamAV antivirus                    | AV and DB updates unusable                 | agent/app/service/clam.go                                    | Start/stop/scan/update                         |
| ssh/sshd.service            | SSH service                         | Remote mgmt/SSH config issues              | agent/app/service/ssh.go                                     | Start/stop/config/hardening                    |
| supervisor/supervisord      | Supervisor process manager          | Process guarding unavailable               | Frontend copy/scripts                                        | Start/stop tasks, automation, script run       |

#### Code notes

1. All services managed by systemctl depend on systemd.
   - Code invokes systemctl (restart, start, stop, status, is-active, is-enabled).
   - If systemctl is unavailable, commands fail; panel cannot control services.
2. Docker, SSH, Fail2Ban, ClamAV, Supervisor are integrated via systemctl.
   - Panel calls systemctl to restart/check status; failures break features.
   - Some detection via snap exists (agent/utils/systemctl/systemctl.go) but depends on snap and is not a general replacement.
3. Panel self-services (core/agent) are also managed via systemctl.
   - The panel cannot self-restart/recover; cannot manage nodes remotely.

------

#### Panel feature impact without systemctl

- Panel shows services abnormal or not running
- Cannot start/stop Docker, Agent, SSH, Supervisor via panel
- Some config changes won’t take effect automatically (e.g., port, SSL)

See also: Service & Feature Limitations.

#### Main API/function examples

- /api/v1/setting/update_port — after change, RestartService uses systemctl to restart core
- /api/v1/setting/update_ssl — triggers systemctl restart core
- /api/v1/upgrade/upgrade — UpgradeService.Upgrade calls systemctl restart core/agent
- /api/v1/upgrade/rollback — handleRollback calls systemctl to restart core/agent
- /api/v1/docker/restart — OperateDocker triggers systemctl restart docker
- /api/v1/agent/restart — restart agent service
- /api/v1/fail2ban/operate — toggle security rules
- /api/v1/clam/operate — toggle antivirus
- /api/v1/ssh/operate — toggle SSH service
- /api/v1/supervisor/operate — toggle supervisor

Upgrade-related systemctl calls:

- In core/app/service/upgrade.go, UpgradeService.Upgrade may call:
  - systemctl daemon-reload
  - systemctl restart 1panel-agent.service
  - systemctl restart 1panel-core.service
- Rollback also restarts related services.
- In other branches/history, functions like handleRollback/handleBackup may call systemctl daemon-reload && systemctl restart 1panel.service.

### supervisord Notes

- Config: hack/supervisord.conf (nodaemon=true, foreground)
- Programs:
  - program:1panel-core -> /usr/bin/1panel-core
  - program:1panel-agent -> /usr/bin/1panel-agent
- Common commands:
```bash
supervisorctl status
supervisorctl restart all
supervisorctl reload
```

#### Why not systemd

To run systemd in Docker typically:

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

Key risks of --privileged + --cgroupns=host + /sys/fs/cgroup mount:

1. Host isolation breaks
   - --privileged grants all Linux capabilities (cap_sys_admin, cap_net_admin, etc.), effectively root.
   - Can operate host devices, network stack, even load kernel modules.
2. cgroup leakage
   - With --cgroupns=host and /sys/fs/cgroup mounted, the container can manipulate host cgroups, change CPU/mem limits, kill processes of other containers.
3. Host privilege escalation/escape
   - A privileged container is effectively host root; isolation is compromised.
   - If an attacker gets a shell, they effectively get host root.

## Conclusion

1. Do not use --privileged in production.
2. Running systemd in Docker is not feasible in current stage.
3. Use supervisord as an alternative for service management.

Reference repos:

1. https://github.com/trfore/docker-ubuntu2404-systemd
2. https://github.com/antmelekhin/docker-systemd
3. Use only for development environments.

### About DooD

This guide provides an “unofficial” 1Panel Docker deployment:

1. DooD (Docker Out of Docker) means invoking the external Docker from within a container.
   The simplest approach is to share the host Docker sock and volumes.
2. With DooD, reuse the host Docker engine and manage processes with supervisord, avoiding systemd and --privileged within the container.
3. Use cautiously in trusted/single-tenant scenarios. Configure security rules (WAF, firewall).

The container must reuse the host Docker for app install/orchestration; mount:

- /var/run/docker.sock:/var/run/docker.sock
- /var/lib/docker/volumes:/var/lib/docker/volumes
- Data persistence (map /1panel_app/data/ to /opt/ in the container)

docker-compose.yml snippet:

```yml
# Key configuration
volumes:
      # make docker out of docker work
      - /var/run/docker.sock:/var/run/docker.sock
      - /var/lib/docker/volumes:/var/lib/docker/volumes
      - /1panel_app/data/:/opt/
```

### Why DooD

### Option comparison: DooD vs DinD vs Sysbox

- DooD (used in this guide)
  - Pros: share host image cache; fast builds, small footprint; simple to implement
  - Cons: high security risk (container controls host Docker), not for multi-tenant
  - Use cases: local/trusted, personal or single-tenant CI
- DinD
  - Pros: isolates engine inside container
  - Cons: requires --privileged, escape risk
  - Use cases: temporary/non-production security scenarios, use cautiously
- Sysbox
  - Safer DinD alternative, but requires specific kernels/distros; ecosystem less mature

Conclusion:

Adopt DooD + supervisord for now; explicitly avoid running systemd with --privileged in production.

### Dood vs DinD vs Sysbox Comparison

| Dimension     | DooD (Docker-out-of-Docker)                                 | DinD (Docker-in-Docker)                                      | Sysbox                                                     |
| ------------- | ------------------------------------------------------------ | ------------------------------------------------------------ | ---------------------------------------------------------- |
| Principle     | Mount host Docker socket; reuse host engine                  | Run an independent Docker engine inside the container        | Use Sysbox runtime; safely run Docker/K8s-like system workloads in containers |
| Pros          | - Reuse host cache → fast builds, low disk usage             | - Easy to use, official DinD images exist - Engine isolation | - No privileged container - User namespace isolation - Proc/sysfs virtualization - Good for system workloads |
| Cons          | - High security risk: container can control host Docker; not for multi-tenant - Bind mount limitations may affect some features | - Needs privileged; root in container ~= root on host; escape risk | - Requires newer kernels/distros; community still evolving |
| Security      | High risk                                                    | High risk                                                    | Relatively lower risk                                      |
| Scenarios     | Local dev/testing; single/trusted environment                | CI/CD requiring separate Docker env; simple sandbox          | Multi-tenant CI runners; secure sandbox; run system workloads |
| Recommendation| Recommended with access control                              | Use with caution (non-production)                            | Not recommended (complex setup)                            |

Reference:
1. Docker-in-Docker: Containerized CI Workflows: https://www.docker.com/resources/docker-in-docker-containerized-ci-workflows-dockercon-2023/

## Build Guide

### Local Build (Makefile)

Dependencies: Docker Desktop (with buildx), logged in to DockerHub (for push if needed).

List commands:
```bash
make help
```

Common commands:
- Initialize builder (once): make builder
- Build single image (no push): make build OS=ubuntu VERSION=2.0.11 ONEPANEL_TYPE=cn
- Push single image: make push OS=centos VERSION=2.0.0 ONEPANEL_TYPE=cn
- Local debug (load to local): make load OS=ubuntu VERSION=2.0.11
- Multi-arch build (no push): make buildx OS=centos VERSION=2.0.0
- Multi-arch build and push: make push OS=alpine VERSION=2.0.11
- Matrix push (3 OS × 2.0.0~2.0.11): make matrix-push

Variables:
- OS=ubuntu|centos|alpine
- VERSION=2.0.0~2.0.11 (inject into {%OnePanel_Version%})
- ONEPANEL_TYPE=pro|cn (inject into {%OnePanel_Type%})
- PLATFORMS=linux/amd64,linux/arm64 (can set single)
- IMAGE_REPO=caijiamx/1panel, IMAGE_TAG_PREFIX=dood

Examples

```bash
# Dry-run a target
make -n build OS=ubuntu VERSION=2.0.11 ONEPANEL_TYPE=pro

# Build a single image
make build OS=ubuntu VERSION=2.0.11 ONEPANEL_TYPE=pro
```

Tag convention: caijiamx/1panel:dood-{version}-{os}

### GitHub Actions Build

Workflow: .github/workflows/main.yml (“Build and Push 1Panel Images”)

- Triggers: push to main/dev or manual workflow_dispatch
- Matrix: OS=[ubuntu, centos, alpine]; VERSION=[2.0.0..2.0.11]
- Multi-arch: linux/amd64, linux/arm64 (setup-qemu + buildx)
- Version replacement: sed replaces v{%OnePanel_Version%} in Dockerfile before build
- Push target: caijiamx/1panel:dood-{version}-{os}
- Secrets required in repo:
  - DOCKERHUB_USERNAME
  - DOCKERHUB_TOKEN
- Usage: On Actions page, select main workflow, click Run workflow, choose os and version

## Upgrade Guide

Upgrade example from v2.0.0 -> v2.0.11. Preparations:

1. Backup the original image (e.g., v2.0.0)
2. Backup mounted data
3. Stop the container

### Version Upgrade Steps

1. Build/pull the new image (e.g., 2.0.11)
2. Manually update the version number
3. Start the new service

### Manually update version number

Official installs maintain version automatically; this image requires manually syncing the version (sqlite3 example):

```bash
sudo apt-get update && apt-get install -y sqlite3
cp /opt/1panel/db/core.db  /opt/1panel/db/core.db.bak
cp /opt/1panel/db/agent.db /opt/1panel/db/agent.db.bak
sqlite3 /opt/1panel/db/core.db "UPDATE settings SET value='v2.0.11' WHERE key='SystemVersion';"
sqlite3 /opt/1panel/db/agent.db "UPDATE settings SET value='v2.0.11' WHERE key='SystemVersion';"
```

After updating image, restart the container (preserve /opt/ volume).

## FAQ

### Service & Feature Limitations

1. Panel -> bottom-right update -> “Upgrade Now” is unavailable. Official upgrade logic depends on systemctl.
2. ~~Panel -> container features unavailable. Service liveness check depends on systemctl status; will be optimized to remove dependency.~~
3. nginx_status listens on 127.0.0.1 by default; adjust accordingly. See: OpenResty status error.
4. Some app install mount paths may be incorrect; fix per actual paths.
5. 1panel-core & 1panel-agent run as root. Running under user nobody will make 1panel-agent crash.
6. Toolbox -> Process Guard, FTP, Fail2ban unavailable.
7. Version v2.0.11 improves the Docker service decision logic, and the Panel->Container function is basically available (the full functionality has not been fully tested).
8. Version v2.0.11 adds disk management, which is not recommended.

**Panel Unavailable Functions**

| Function                                                     | Available | Remarks             |
| ------------------------------------------------------------ | --------- | ------------------- |
| Panel -> Upgrade Now (bottom right corner)                   | ❌         |                     |
| Website -> Website -> OpenResty Settings -> Current Status<br/>Website -> Runtime Environment -> php-fpm container status check | ❌         |                     |
| Toolbox -> Process Supervisor, FTP, Fail2ban, Disk Management | ❌         | Function not tested |
| Advanced Features                                            | ❌         | Function not tested |

### Q&A

#### App install error “Are you trying to mount a directory onto a file”

- Cause: host path vs container path mismatch (file/dir)
- Fix: correct the host path and mappings according to the app

Example:

```yml
# docker-compose.yml inside container
- ${WEBSITE_DIR}:/www -> /1panel_app/data/1panel/www:/www
# Default 1panel project dir inside container: /opt/1panel
```

Common variables

```
# Variables used by 1panel in docker-compose.yml
${CONTAINER_NAME} # custom container name

${IMAGE_NAME} # custom image name

${PANEL_APP_PORT_HTTP} # custom port

${PANEL_WEBSITE_DIR} # defaults to /opt/1panel/www

${WEBSITE_DIR} # defaults to /opt/1panel/www
```

#### OpenResty status error

Error:

```
服务内部错误: Get "http://127.0.0.1/nginx_status": dial tcp 127.0.0.1:80: connect: connection refused
```

Cause: health check to 127.0.0.1 fails; inside the container 127.0.0.1:80 points to 1panel, while openresty is a separate container. 1panel -> openresty should use http://openresty.

Fix it with add host alias: `server_name 127.0.0.1 openresty;` . Correct visit URL: http://openresty/nginx_status.

A complete fix requires code changes:

```go
// agent/app/service/nginx.go
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

#### Reverse proxy config

WebSocket/upgrade headers:

```nginx
proxy_http_version 1.1;
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection "upgrade";
proxy_set_header Host $host;  # set explicitly if you need a fixed backend Host
```

#### Security entry and account info

- After enabling security entry, check inside container: 1pctl user-info
- On first deployment, change username/password/entry
- Recommend WAF + network firewall to control access

#### Cloudflare common ports

- HTTP: 80, 8080, 8880, 2052, 2082, 2086, 2095
- HTTPS: 443, 2053, 2083, 2087, 2096, 8443

#### Resources and timeouts

Low CPU limits may cause API timeouts (occasional 5xx/timeouts). Recommend 1.0~1.5 core.

## Security Notes

- DooD allows the container to control the host Docker; there are security risks. Use only in trusted, single-tenant environments.
- Configure network firewalls to allow only necessary IPs and ports.
- Restrict access to the panel: domain, IP/port, machine isolation.

## Maintainer

- GeekWho <geekwho_eth@outlook.com>
