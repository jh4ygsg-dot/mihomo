#!/usr/bin/env bash
set -Eeuo pipefail

readonly CONFIG_PATH="/etc/mihomo/config.yaml"
readonly RAW_BASE_URL="https://raw.githubusercontent.com/jh4ygsg-dot/mihomo/main"

if [[ ${EUID} -ne 0 ]]; then
  echo "错误：请使用 root 用户运行此脚本。" >&2
  exit 1
fi

for command_name in curl mihomo; do
  if ! command -v "${command_name}" >/dev/null 2>&1; then
    echo "错误：未找到命令 ${command_name}。" >&2
    exit 1
  fi
done

echo "请选择服务端配置："
select config_name in "纯净（全部直连）" "送中（Google 走本机 SOCKS5）" "退出"; do
  case ${REPLY} in
    1)
      config_url="${RAW_BASE_URL}/%E7%BA%AF%E5%87%80/server.yaml"
      break
      ;;
    2)
      config_url="${RAW_BASE_URL}/%E9%80%81%E4%B8%AD/server.yaml"
      break
      ;;
    3)
      exit 0
      ;;
    *)
      echo "请输入 1、2 或 3。"
      ;;
  esac
done

while true; do
  read -r -s -p "请输入共用于 VLESS 和 Hysteria2 的密码：" proxy_password
  echo
  read -r -s -p "请再次输入密码：" proxy_password_confirm
  echo

  if [[ ${proxy_password} != "${proxy_password_confirm}" ]]; then
    echo "两次输入不一致，请重试。" >&2
    continue
  fi

  if [[ -z ${proxy_password} ]]; then
    echo "密码不能为空，请重试。" >&2
    continue
  fi

  if [[ ${proxy_password} =~ [[:cntrl:]] ]]; then
    echo "密码不能包含控制字符，请重试。" >&2
    continue
  fi
  break
done

downloaded_config=$(mktemp)
temp_config=$(mktemp)
trap 'rm -f "${downloaded_config}" "${temp_config}"' EXIT
chmod 600 "${downloaded_config}" "${temp_config}"

echo "正在从 GitHub 下载最新配置……"
curl --fail --show-error --silent --location \
  --connect-timeout 10 --max-time 60 \
  "${config_url}" -o "${downloaded_config}"

if ! grep -q 'YOUR_PASSWORD' "${downloaded_config}"; then
  echo "错误：下载的配置中没有 YOUR_PASSWORD，占位符可能已改变。" >&2
  exit 1
fi

# 将密码编码为 YAML 双引号字符串，支持空格、引号、反斜杠等字符。
yaml_password=${proxy_password//\\/\\\\}
yaml_password=${yaml_password//\"/\\\"}
while IFS= read -r config_line || [[ -n ${config_line} ]]; do
  if [[ ${config_line} == *YOUR_PASSWORD* ]]; then
    config_line="${config_line%%YOUR_PASSWORD*}\"${yaml_password}\"${config_line#*YOUR_PASSWORD}"
  fi
  printf '%s\n' "${config_line}"
done < "${downloaded_config}" > "${temp_config}"

echo "正在校验 Mihomo 配置……"
mihomo -t -f "${temp_config}"

install -d -m 750 "$(dirname "${CONFIG_PATH}")"
if [[ -f ${CONFIG_PATH} ]]; then
  backup_path="${CONFIG_PATH}.bak.$(date +%Y%m%d-%H%M%S)"
  cp -a "${CONFIG_PATH}" "${backup_path}"
  echo "旧配置已备份到 ${backup_path}"
fi

install -m 600 "${temp_config}" "${CONFIG_PATH}"
echo "新配置已安装到 ${CONFIG_PATH}"

read -r -p "是否立即重启 mihomo 服务？[Y/n] " restart_answer
if [[ ! ${restart_answer} =~ ^[Nn]$ ]]; then
  systemctl restart mihomo
  systemctl --no-pager --full status mihomo
fi

echo "完成。"
