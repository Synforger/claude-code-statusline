# Security Policy

## Reporting a vulnerability

Use **GitHub Security Advisories private vulnerability reporting** to
disclose security issues responsibly:

1. Open https://github.com/Synforger/claude-code-statusline/security/advisories/new
2. Fill in the affected version + reproduction + impact estimate
3. Maintainer will acknowledge within 7 days

Do not file public Issues or PRs for security-relevant findings. Public
discussion only after a fix has shipped and end users have had time to
update.

If GitHub access is unavailable, reach `@Synforger` via the
contact channel listed in the repo's README.

## Supported versions

| version | supported |
|---|---|
| main (= rolling release) | ✅ active |
| tagged releases (= v0.x) | ⚠️ best effort (= no formal LTS) |
| forks / mirrors | ❌ out of scope |

This is a personal project; there is no enterprise LTS. Security fixes
land on `main` and the next tagged release. Pin to a specific tag if
your environment requires reproducibility.

## Threat model

Local shell script run by Claude Code as a statusline hook on the
user's own machine. It reads status JSON from stdin, parses it with
`jq`, and prints one formatted line — no network access, no file
writes, no secrets handled. Main threats: shell injection through
crafted JSON field values, and supply-chain tampering of the script
itself (mitigated by installing from a pinned commit or tag).

## In scope

- Authentication / authorization flaws (= when applicable)
- Sensitive data leakage (= secrets in logs / errors / responses)
- Path traversal / SSRF / SQLi / XSS / RCE in code paths the
  template's own scripts execute
- Dependency vulnerabilities surfaced by `task audit`

## Out of scope

- Issues in upstream dependencies that are already disclosed
  (= report those upstream; this repo will pick up the fix on next bump)
- Best-practice nudges with no concrete exploit path
- Vulnerabilities only reproducible with privileged local access
  (= `sudo` / root) — those imply the threat model has already failed
- Cosmetic / DoS-via-resource-exhaustion in dev-mode tools

## Audit log

The maintainer runs `task audit` (= `pip-audit` + `npm audit` +
`cargo audit` + `gitleaks` + `anon-scan` aggregated) at least every
6 months. Findings + resolutions are tracked here:

| date | findings | resolution |
|---|---|---|
| 2026-07-04 | (initial) | machinery installed, no findings |

## Upstream redirect

When a vulnerability originates in a transitive dependency, the
disclosure goes to the upstream maintainer first. This repo only
contains the integration layer; the offending logic lives elsewhere
and should be patched there.
