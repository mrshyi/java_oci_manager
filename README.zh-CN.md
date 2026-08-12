# java_oci_manager

[English](README.md) | [简体中文](README.zh-CN.md)

[![CI](https://github.com/mrshyi/java_oci_manager/actions/workflows/ci.yml/badge.svg)](https://github.com/mrshyi/java_oci_manager/actions/workflows/ci.yml)
[![Publish image](https://github.com/mrshyi/java_oci_manager/actions/workflows/publish.yml/badge.svg)](https://github.com/mrshyi/java_oci_manager/actions/workflows/publish.yml)

本仓库为 `semicons/java_oci_manage` 发布的原生 R-Bot 客户端构建自主维护的多架构容器镜像。

构建时会固定应用版本并校验官方 SHA-256 摘要。应用程序二进制作为容器的前台受管进程运行，不使用上游的后台服务脚本。

## 快速部署

需要提前安装 Docker Engine 和 Compose v2。执行一键部署命令：

```bash
curl -fsSL https://raw.githubusercontent.com/mrshyi/java_oci_manager/main/scripts/install.sh | sh
```

部署完成后打开管理页面：

```text
http://服务器IP:9527
```

默认监听所有网卡（`0.0.0.0`），便于直接测试。如无法访问，请在服务器防火墙或云安全组中放行 TCP 端口 `9527`。默认使用明文 HTTP，仅适合快速测试；超出受控网络使用前请配置可信 HTTPS。

## 安全模型

- 使用非特权 UID/GID `10001:10001` 运行。
- 丢弃所有 Linux capabilities，并启用 `no-new-privileges`。
- 根文件系统只读。
- 可变应用状态保存在具名卷中。
- API 私钥单独以只读方式挂载。
- 为便于快速测试，默认监听所有网卡；测试完成后应限制防火墙，并按需改为仅监听本机。
- 使用官方 SHA-256 摘要验证下载的发行包。

## 发布镜像

`Publish image` 工作流每天 `01:17 UTC` 运行，也支持手动触发以及 `upstream-release` repository dispatch 事件。该工作流会：

1. 解析选定的 `semicons/java_oci_manage` GitHub Release。
2. 读取官方 AMD64 兼容版及 ARM64 版 SHA-256 摘要。
3. 构建 `linux/amd64` 和 `linux/arm64` 镜像。
4. 将 `<version>` 和 `latest` 标签发布到 GitHub Container Registry。
5. 附带构建 provenance 和 SBOM。

公开镜像可直接拉取：

```bash
docker pull ghcr.io/mrshyi/java_oci_manager:latest
```

如需同时发布到 Docker Hub，请配置 GitHub 变量 `DOCKERHUB_USERNAME`，以及对目标仓库具有读写权限的 GitHub Secret `DOCKERHUB_TOKEN`。不要使用账户密码。未配置时，工作流会跳过 Docker Hub，GHCR 发布不受影响。

## 本地构建并启动

如需自行构建镜像，而不是使用 GHCR 预构建镜像：

```bash
cd /path/to/java_oci_manager
cp .env.example .env
mkdir -p config secrets
docker compose build --pull
docker compose up -d
docker compose ps
docker compose logs -f rbot
```

首次启动时，上游 `client_config` 模板会复制到 `java-oci-manage-data` 卷。之后应用可以初始化凭据，并通过 Web 界面管理配置。

如需预置已有配置，请在**首次启动前**将其放在 `config/client_config`。该文件必须允许 UID 10001 读取。在 Linux 上执行：

```bash
chown 10001:10001 config/client_config
chmod 600 config/client_config
```

只有当持久卷中不存在 `client_config` 时才会导入该文件，因此重新创建或升级容器不会覆盖正在使用的配置。

## OCI 及其他私钥

私钥必须存放在 `secrets/` 中，切勿放入镜像或配置目录：

```bash
chown -R 10001:10001 secrets
chmod 700 secrets
chmod 600 secrets/*.pem
```

在 `client_config` 中使用私钥的**容器内路径**：

```ini
key_file=/run/rbot-secrets/oci_api.pem
```

不要提交 `.env`、`client_config`、私钥、导出的凭据或持久卷内容。

## 网络暴露

Compose 默认在主机所有网卡上发布 `9527` 端口：

```text
0.0.0.0:9527 -> container:9527
```

服务器防火墙或云安全组放行 TCP 端口 `9527` 后，可通过 `http://服务器IP:9527` 直接访问。此默认值用于快速测试。该应用能够控制云资源，请限制允许访问的来源地址，不要长期对整个互联网开放。

需要改为仅允许 Docker 主机本地访问时，在 `.env` 中设置并重新创建容器：

```dotenv
RBOT_BIND_ADDRESS=127.0.0.1
```

```bash
docker compose up -d --no-build --force-recreate
```

### HTTPS 配置

生产环境建议让应用保持 HTTP，由可信反向代理或隧道（例如 Nginx、Caddy
或 Cloudflare Tunnel）负责 HTTPS。后端最好只监听本机：

```dotenv
RBOT_BIND_ADDRESS=127.0.0.1
RBOT_SSL_ENABLED=false
```

将代理的上游地址设置为 `http://127.0.0.1:9527`，然后重新创建容器：

```bash
docker compose up -d --no-build --force-recreate
```

如果暂时无法配置反向代理，也可以启用应用内置的自签名 HTTPS：

```dotenv
RBOT_SSL_ENABLED=true
```

重新创建容器后通过 `https://服务器IP:9527` 访问。浏览器会提示自签名证书
不受信任，除非手动将证书加入信任列表。

## 升级与回滚

不要使用上游的容器内脚本升级命令，应将镜像视为不可变制品。

使用 GHCR 镜像时，在 `.env` 中选择目标版本标签，然后执行：

```bash
docker compose pull
docker compose up -d --no-build
```

具名数据卷不会改变。需要回滚时，将 `RBOT_IMAGE` 恢复为上一个版本标签，再次运行上述命令。

自行构建时，请将 `.env` 中的 `RBOT_VERSION`、`RBOT_SHA256_AMD64`、`RBOT_SHA256_ARM64` 与 `RBOT_IMAGE` 版本标签一起更新，然后执行：

```bash
docker compose build --pull --no-cache
docker compose up -d
```

升级前备份数据卷：

```bash
docker run --rm \
  -v java-oci-manage-data:/source:ro \
  -v "$PWD/backups:/backup" \
  alpine:3.22 \
  tar -czf /backup/rbot-data.tgz -C /source .
```

## 运维

```bash
# 状态与健康检查
docker compose ps

# 日志
docker compose logs --tail=200 -f rbot

# 停止但不删除持久数据
docker compose down

# 查看持久化配置
docker compose exec rbot sh -c 'ls -la /var/lib/rbot'
```

删除具名卷会永久移除应用状态。除非明确需要且已有备份，否则不要运行 `docker compose down -v`。
