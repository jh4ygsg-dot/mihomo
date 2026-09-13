# mihomo

## 配置目录

- `客户端/config.yaml`：通用 Windows TUN 客户端配置。复制 `proxies` 中的节点模板并分别填写 VPS 域名和节点名称；“节点选择”策略组会自动收纳所有节点并记住手动选择。
- `送中/server.yaml`：Google 流量通过 VPS 本机 `127.0.0.1:40000` SOCKS5 代理，其余流量直连。
- `纯净/server.yaml`：服务端全部流量直接使用 VPS 本地网络。

客户端与服务端配置中的 `YOUR_PASSWORD` 必须替换为同一个非空密码。该值同时用作 VLESS 的 `uuid` 字段和 Hysteria2 密码；Mihomo 允许这里使用普通字符串，不要求标准 UUID 格式。

## 在 VPS 上交互式更新配置

`update-config.sh` 会让用户选择“纯净”或“送中”配置，从 GitHub `main` 分支下载对应的最新文件，并用输入的密码替换 `YOUR_PASSWORD`。随后脚本会询问 VPS 域名，生成已经填充密码和域名的客户端配置；节点名会采用 `vless-域名` 和 `hy2-域名` 的格式。脚本会在覆盖前运行 Mihomo 服务端配置校验，并把现有 `/etc/mihomo/config.yaml` 备份为带时间戳的文件。

在 VPS 上执行：

```bash
curl -fsSLo /tmp/update-mihomo-config.sh \
  https://raw.githubusercontent.com/jh4ygsg-dot/mihomo/main/update-config.sh
chmod +x /tmp/update-mihomo-config.sh
sudo /tmp/update-mihomo-config.sh
```

脚本需要 VPS 已安装 `curl`、`mihomo` 和 systemd。密码输入不会回显。生成的客户端配置会以仅 root 可读的权限保存到 `/root/mihomo-client.yaml`，并在脚本最后输出到终端。选择“送中”前，还应确保本机 `127.0.0.1:40000` 已有可用的 SOCKS5 服务。

每次使用前请重新执行上面的 `curl` 命令获取最新版脚本，不要长期复用 `/tmp` 中的旧副本。

## 使用 acme.sh 申请证书

以下命令以 root 用户、ECDSA P-256 证书和 Let's Encrypt 为例。执行前需要：

- 将 `YOUR_EMAIL` 替换为接收证书通知的邮箱；
- 将 `YOUR_VPS_DOMAIN` 替换为已经解析到 VPS 公网 IPv4 的域名；
- 确保公网 TCP/80 已在云防火墙和系统防火墙中放行；
- 确保签发时没有其他程序占用 TCP/80。

### 1. 安装 acme.sh

```bash
curl https://get.acme.sh | sh -s email=YOUR_EMAIL
```

### 2. 使用 standalone 模式签发证书

```bash
/root/.acme.sh/acme.sh --issue --standalone --server letsencrypt --keylength ec-256 -d YOUR_VPS_DOMAIN
```

standalone 模式会临时启动一个 HTTP 服务完成验证，因此签发和续期时 TCP/80 必须可用。

### 3. 安装证书到 `/etc/mihomo`

```bash
install -d -m 750 /etc/mihomo
/root/.acme.sh/acme.sh --install-cert -d YOUR_VPS_DOMAIN --ecc \
  --key-file /etc/mihomo/private-key.pem \
  --fullchain-file /etc/mihomo/fullchain.pem \
  --reloadcmd "systemctl restart mihomo"
```

不要直接在 mihomo 配置中引用 `/root/.acme.sh` 内部的证书文件。`--install-cert` 会在以后自动续期时更新 `/etc/mihomo` 中的文件，并执行 `systemctl restart mihomo`。

服务端配置使用以下路径：

```yaml
certificate: /etc/mihomo/fullchain.pem
private-key: /etc/mihomo/private-key.pem
```
