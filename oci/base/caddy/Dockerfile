# Caddy + Cloudflare DNS provider.
#
# 官方 caddy:2-alpine 不含任何 DNS provider 模块, 因此只能做 HTTP-01 挑战 ——
# 那要求域名的 A 记录已经指向本机。web-saas 的交付顺序是"先部署新主机、最后
# 才切 DNS", 在切换之前 HTTP-01 必然签不出证书。DNS-01 不需要 A 记录指过来,
# 而且是签发泛域名证书(*.onwalk.net)的唯一途径。
#
# 自建而不是直接引用社区镜像(caddybuilds/caddy-cloudflare 等): Caddy 是直接
# 终结 TLS、持有全站私钥的组件, 它的供应链必须自己控制。这里只从上游官方
# caddy 镜像取 builder 与 runtime, 中间的编译过程在我们自己的流水线里发生。
#
# 版本钉死到具体小版本而不是 :2 —— 浮动 tag 会让"同一个 Dockerfile 构建出
# 行为不同的镜像", 排查 TLS 问题时这是最难受的一类不确定性。
ARG CADDY_VERSION=2.10.0

FROM caddy:${CADDY_VERSION}-builder-alpine AS builder

# xcaddy 会拉取模块源码重新编译 caddy 二进制。模块版本同样钉死。
ARG CLOUDFLARE_MODULE_VERSION=v0.2.4
RUN xcaddy build \
      --with github.com/caddy-dns/cloudflare@${CLOUDFLARE_MODULE_VERSION}

FROM caddy:${CADDY_VERSION}-alpine

LABEL org.opencontainers.image.title="caddy with cloudflare dns" \
      org.opencontainers.image.description="Caddy built with the caddy-dns/cloudflare provider for ACME DNS-01 and wildcard certificates" \
      org.opencontainers.image.source="https://github.com/ai-workspace-infra/artifacts"

COPY --from=builder /usr/bin/caddy /usr/bin/caddy

# 构建期自检: 模块没被编译进去时, 镜像照样能跑, 只有在真正签证书的时候才
# 报 "unknown module dns.providers.cloudflare" —— 那已经是生产环境半夜的事了。
# 这一行让缺模块在构建期就失败。
RUN caddy list-modules | grep -q '^dns\.providers\.cloudflare$' \
    || (echo "cloudflare dns provider missing from build" >&2; exit 1)
