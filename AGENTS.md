# Repository Guidelines

## Project Structure & Module Organization
- `generate.sh`: main pipeline; produces `CN.rsc`, `CN_mem.rsc`, `gfwlist_v7.rsc`, `03-gfwlist.conf`, `gfwlist.txt`.
- `gfwlist2dnsmasq.sh`: converts gfwlist to dnsmasq rules or a plain domain list.
- `generate_cn.sh`: optional/legacy helper.
- Custom lists: `include_list.txt` (add), `exclude_list.txt` (remove).
- CI: `.github/workflows/main.yaml` runs `make` daily and commits updates.
- Docs: `README.md`, `README.en.md` for usage and RouterOS examples.

## Build, Test, and Development Commands
- Build/update all: `make` or `bash generate.sh` — downloads sources and regenerates artifacts.
- Convert only (example): `bash gfwlist2dnsmasq.sh -l -o gfwlist.txt --extra-domain-file include_list.txt --exclude-domain-file exclude_list.txt`.
- Lint: `shellcheck generate.sh gfwlist2dnsmasq.sh`.
- Sanity checks: `wc -l gfwlist.txt` and `head -n 5 gfwlist.txt`.
- Note: Generators require network; set proxies via environment if needed.

## Coding Style & Naming Conventions
- Shell scripts use bash with `set -euo pipefail`; 4-space indentation.
- Functions: `lower_snake_case`; constants: `UPPER_SNAKE`.
- Always quote variables; keep `LC_ALL=POSIX`.
- Use `mktemp` and `trap` for safe temp/cleanup; prefer awk/sed/grep pipelines; avoid new external deps.
- Do not hand-edit generated `.rsc/.conf/.txt`; modify scripts or `include_list.txt`/`exclude_list.txt` instead.

## Testing Guidelines
- No unit test harness. Validate by running `make` and confirming expected files exist and are non-empty.
- When changing domain handling, add sample entries to include/exclude lists and re-run generation.
- RouterOS import/behavior tests are manual; do not commit device-specific outputs.

## Commit & Pull Request Guidelines
- Commits: concise conventional style, e.g., `feat(generate): …`, `fix(gfwlist2dnsmasq): …`.
- CI uses messages like: `Automated update: YYYY-MM-DD HH:MM:SS`.
- PRs should explain what/why, include sample command output (e.g., `wc -l gfwlist.txt`), and state whether artifacts were regenerated. Prefer not committing generated files; CI refreshes them after merge.

## Security & Configuration Tips
- Do not hardcode secrets; scripts fetch public sources only.
- Preserve portability (Ubuntu-latest on CI); avoid adding runtime dependencies.
- Generators require network access; configure proxies via environment when necessary.

