# mihomo

## 配置目录

- `客户端/config.yaml`：通用 Windows TUN 客户端配置。复制 `proxies` 中的节点模板并分别填写 VPS 域名和节点名称；“节点选择”策略组会自动收纳所有节点并记住手动选择。
- `送中/server.yaml`：Google 流量通过 VPS 本机 `127.0.0.1:40000` SOCKS5 代理，其余流量直连。
- `纯净/server.yaml`：服务端全部流量直接使用 VPS 本地网络。

客户端与服务端配置中的 AnyTLS 密码必须保持一致，并应替换为独立生成的随机强密码。

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
