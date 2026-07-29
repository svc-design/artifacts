# Public GHCR organization packages

## Finding

The `stunnel-server`, `stunnel-client`, and `charts/postgresql` packages under
`ai-workspace-infra` were private even though the source repositories are public.
`caddy-cloudflare` was already public.

## Fix

The OCI chart release workflow previously pushed to the unrelated `x-evor`
namespace. It now derives the namespace from `github.repository_owner`, so runs
from this repository publish to `ghcr.io/ai-workspace-infra`.

Package visibility remains a package-level GitHub setting and must be changed in
each package's Settings page. This is intentionally separate from repository
visibility.
