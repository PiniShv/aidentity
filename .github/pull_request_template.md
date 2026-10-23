<!-- Read CONTRIBUTING.md first. Its safety rules are not style preferences:
     a change that weakens one is sent back, whatever else it does.
     One change per PR. -->

## What changes

<!-- What this does and why, in a few direct sentences or bullets.
     If it fixes an issue, write "Closes" and the issue number. -->

## Test plan

<!-- Tick what you ran, and say which macOS version you ran it on. -->

- [ ] `make lint` and `make test`
- [ ] The test suite under macOS's own `/bin/bash` (3.2)
- [ ] On a real app: <!-- which app and version, and did two accounts stay signed in at once? -->

## Before you submit

- [ ] `SHA256SUMS` regenerated with `make checksums`, if `bin/aidentity` changed
- [ ] `--help` and `docs/` updated, if behaviour changed
- [ ] A line under `## [Unreleased]` in `CHANGELOG.md`, if a user would notice the change
