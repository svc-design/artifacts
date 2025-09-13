#!/usr/bin/env bash
# scripts/resolve_nginx_ingress_versions.sh
# 输出：写入 $GITHUB_OUTPUT -> image_tag, chart_version
# 环境变量：
#   OVERRIDE_IMAGE_TAG      可选，手工覆盖镜像版本（如 5.1.1）
#   OVERRIDE_CHART_VERSION  可选，手工覆盖 Helm Chart 版本（如 1.2.3）
#   MAJOR_WHITELIST         可选，主版本白名单（默认 5），示例：'5' 或 '5|4'

set -euo pipefail

OVERRIDE_IMAGE_TAG="${OVERRIDE_IMAGE_TAG:-}"
OVERRIDE_CHART_VERSION="${OVERRIDE_CHART_VERSION:-}"
MAJOR_WHITELIST="${MAJOR_WHITELIST:-5}"

resolve_image_tag() {
  # 手工覆盖优先
  if [[ -n "${OVERRIDE_IMAGE_TAG}" ]]; then
    echo "${OVERRIDE_IMAGE_TAG}"
    return
  fi

  tmp="$(mktemp)"
  # 拉 3 页（足够覆盖最近更新）
  for page in 1 2 3; do
    curl -fsSL "https://hub.docker.com/v2/repositories/nginx/nginx-ingress/tags/?page_size=100&page=${page}&ordering=last_updated" \
      | jq -r '.results[].name' >> "${tmp}"
  done

  # 仅保留纯 semver，过滤预发布；再按主版本白名单过滤；语义排序取最大
  latest="$(grep -E "^[0-9]+\.[0-9]+\.[0-9]+$" "${tmp}" \
    | grep -E "^(${MAJOR_WHITELIST})\." \
    | sort -V \
    | tail -n1 || true)"
  rm -f "${tmp}"

  if [[ -z "${latest}" ]]; then
    echo "Failed to resolve nginx/nginx-ingress image tag (major_whitelist=${MAJOR_WHITELIST})" >&2
    exit 1
  fi
  echo "${latest}"
}

resolve_chart_version() {
  # 手工覆盖优先
  if [[ -n "${OVERRIDE_CHART_VERSION}" ]]; then
    echo "${OVERRIDE_CHART_VERSION}"
    return
  fi

  # helm repo 已由 workflow 预先 add & update
  chart_json="$(helm search repo nginx-stable/nginx-ingress --versions -o json)"
  latest="$(echo "${chart_json}" \
    | jq -r '.[].version' \
    | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' \
    | sort -V \
    | tail -n1 || true)"

  if [[ -z "${latest}" ]]; then
    echo "Failed to resolve helm chart version for nginx-stable/nginx-ingress" >&2
    exit 1
  fi
  echo "${latest}"
}

IMAGE_TAG="$(resolve_image_tag)"
CHART_VERSION="$(resolve_chart_version)"

{
  echo "image_tag=${IMAGE_TAG}"
  echo "chart_version=${CHART_VERSION}"
} >> "$GITHUB_OUTPUT"

echo "Resolved => nginx/nginx-ingress:${IMAGE_TAG} ; chart=${CHART_VERSION} ; major_whitelist=${MAJOR_WHITELIST}"

