# Dashboard implementation plan

**Goal:** Launch a complete visual account manager with `aidentity dashboard`.

**Architecture:** A loopback Python standard-library server delegates typed
operations to the existing CLI. Its static frontend and Python source are bundled
into the single executable at build time.

**Tech stack:** Bash 3.2, Python 3.9+, HTML, CSS, vanilla JavaScript.

**Spec:** ../specs/2026-10-29-dashboard-design.md

## Constraints

- Keep the one-file installer and updater contract, checksums and final dispatch.
- No third-party runtime packages or external assets.
- Bind loopback; validate request origin, host, session token and operation shape.
- Keep CLI validation and safe filesystem/process behavior as the authority.
- Never exercise mutations against real accounts during QA.

## Parallel tasks

- [x] Backend: `dashboard/server.py`, `test/test_dashboard_server.py`. Validate
  typed requests; fetch state from `list --json` and completion; invoke CLI using
  argv arrays. Test request boundaries, CLI failures, serialization and limits.
- [x] Frontend: `dashboard/index.html`, `dashboard/app.js`,
  `dashboard/styles.css`. Account workspace, applications, maintenance, transfer
  and help. Implement every operation with form validation and visible outcomes.
- [x] Packaging: `src/82-dashboard.sh`, generated `src/83-dashboard-bundle.sh`,
  `scripts/bundle-dashboard.py`, command table/help, Makefile and documentation.
  Add a shell test area for help, validation and isolated launch.
- [x] QA: real sandbox profiles, browser interactions and screenshots at multiple
  sizes, read-only live account display, independent code review, `make check`.
- [x] Install the verified single executable on the user's existing PATH and
  open the real dashboard.

## Interfaces

`GET /api/state` returns `ok`, `csrf_token`, `version`, `profiles`, `apps`,
`restorable`, `paths`, and `errors`. Profiles use `list --json` names. POST
`/api/action` accepts JSON `{action, ...typedFields}` with `X-AIdentity-CSRF`.
Results include `ok`, `action`, `exit_code`, `stdout`, `stderr`, and optional
`error`. The frontend refreshes state after an operation.

The generated Bash `dashboard_runtime PYTHON ARGS...` sends a script over stdin
to Python. Its `ASSETS` dictionary maps `/`, `/app.js`, and `/styles.css` to
text. Python receives the exact CLI path as its first positional argument.

## Review focus

- Missing Python must affect only dashboard startup and explain remediation.
- Copied executable must serve every asset without a repository present.
- Failed or timed-out commands must not show success or leave duplicate actions.
- Hidden launch environment values must survive unrelated appearance edits.
- Hostile names, paths, origins and option-like values must not become commands.
