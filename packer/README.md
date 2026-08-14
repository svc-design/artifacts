# Golden Image 发布

本目录的四个 Web SaaS / Agent Proxy 模板同时保留 QEMU 本地构建和 Vultr 构建入口。Vultr 构建使用官方 `github.com/vultr/vultr` Packer plugin：临时创建 Vultr VPS，执行 runtime provisioner，生成 Snapshot，然后销毁临时 VPS。AWS、GCP、Azure、AliCloud 的现有模板和 workflow 不会被替换。

## Vultr workflow

`.github/workflows/` 下有四个按模板拆分的发布入口：

- `packer-vultr-debian13-docker-compose-websaas.yml`
- `packer-vultr-ubuntu2604-docker-compose-websaas.yml`
- `packer-vultr-debian13-systemd-agent-proxy.yml`
- `packer-vultr-ubuntu2604-systemd-agent-proxy.yml`

手动运行时可选择 Vultr region、临时构建 VPS plan，并可用 `os_id` 覆盖动态 OS ID 解析。合并到 `main` 后，模板变更会自动走 UAT 发布。

四套镜像都会预装观测运行时二进制：Vector、Node Exporter 和 Process Exporter；Web SaaS
镜像额外预装 PostgreSQL Exporter。镜像只提供不可变二进制与 systemd unit，不写入任何
运行时凭据，也不会在构建阶段启动依赖业务配置的 exporter。Agent Proxy 镜像明确不安装
Docker，Docker 仅属于 Web SaaS 镜像。

## Vault prerequisites

工作流使用 GitHub OIDC 登录 Vault，不从 GitHub Actions Secrets 读取 Vultr API key。UAT 需要在下面的 Vault 路径提供 `VULTR_API_KEY`：

```text
kv/data/CICD/uat
```

对应的 JWT role 约定为 `github-actions-artifacts-uat`。Vault policy 只授予当前仓库读取该 UAT 路径的权限。

## Local validation

```bash
VULTR_API_KEY=... \
VULTR_REGION_ID=ewr \
VULTR_PLAN_ID=vc2-2c-4gb \
VULTR_OS_REGEX='^Debian 13' \
TEMPLATE=packer/debian13-docker-compose-websaas.pkr.hcl \
SOURCE_NAME=debian13_docker_compose_websaas \
bash .github/scripts/packer-vultr-build.sh
```

本地执行会真实创建 Vultr 临时 VPS 和 Snapshot；只做语法校验时请使用 `packer init` / `packer validate`，不要执行 `packer build`。
