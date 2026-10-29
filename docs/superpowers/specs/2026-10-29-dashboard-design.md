# Local dashboard

The requested outcome is `aidentity dashboard`: a browser opens on localhost and
every CLI account-management operation has a usable visual equivalent. The
dashboard must feel finished, animate smoothly, and be tested end to end.

## Implementation decisions

- Keep the existing shell CLI as the authority for profile operations and safety
  checks. The dashboard passes validated arguments to that exact executable.
- Use a Python 3.9+ standard-library HTTP server for the optional dashboard.
  Ordinary CLI commands keep their existing requirements. No pip or npm packages
  are needed to run the dashboard.
- Embed the server and all frontend assets into the existing single-file
  distribution. Source remains editable separately under `dashboard/`.
- Listen only on `127.0.0.1`, choose an available port by default, support an
  explicit `--port`, and provide `--no-open` for headless use. Ctrl+C stops it.
- Use 21st.dev component adaptations for the core UI, with the requested
  Perspective Tunnel Hero and Works Wheel in Explore. Apply the Apple design
  skill's web-app principles to placement and motion, without a runtime skill
  dependency.
- Use a neutral dark account workspace, warm white text and a restrained coral
  accent. Profile badge colors retain their meaning. Transitions respect reduced
  motion. Search, filters, dialogs and navigation work with a keyboard.

## Scope

Profiles: list/status, create (including Main and Claude seed), open, quit, rename,
badge/color and launch settings, remove with optional purge. Maintenance: restore,
rebuild, prune, doctor and fix. Transfer: export download and import. Utilities:
version, update/check, help and completion. Setup and the terminal menu's account
operations are available through the graphical create/edit flows.

Real state supplies counts and content. Loading, empty, disconnected, busy,
success and error states must be visible. Destructive choices use a review dialog.
Existing environment values remain hidden; editing appends values or clears them
only when explicitly selected. Export retains the CLI's warning about settings.

## Verification

Use synthetic macOS app bundles and isolated home, launchers and profile folders
for mutations. Check actual launch, status, quit, create, settings, rename,
remove/restore, rebuild, prune and transfer through the real CLI/server. Test
request validation, origin/host checks, CSRF, timeout and concurrent operations.
Inspect desktop, small laptop and mobile layouts in a browser, including
dialogs, keyboard operation and reduced motion. Run the existing full suite.

Inventory reads and actions must verify that the TCP client belongs to the same
macOS user as the server, in addition to the Host, Origin and CSRF checks.
