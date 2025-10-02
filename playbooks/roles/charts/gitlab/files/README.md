# GitLab Single-Node Offline Installer Assets

This directory contains helper files used to assemble the GitLab offline package:

- `setup.sh` – main installer script invoked by `install-gitlab.sh`
- `install-gitlab.sh` – wrapper that forwards to `setup.sh`
- `gitlab-values.single-node.yaml` – values template optimised for single-node installations
- `gitlab-offline.env.example` – sample configuration file consumed by the installer

The offline package builder (`scripts/create-gitlab-offline-package.sh`) copies these
artifacts into the final archive so that users can extract and run:

```bash
tar -xvpf offline-package-gitlab-amd64.tar.gz
cd gitlab-offline-package/
cp gitlab-offline.env.example gitlab-offline.env
# Edit gitlab-offline.env and then execute:
bash install-gitlab.sh --version <VERSION> --domain <DOMAIN> [--namespace <NAMESPACE>]
```
