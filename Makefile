# aidentity — https://github.com/PiniShv/aidentity
#
# aidentity is one shell script. Installing it is a copy; uninstalling is a
# delete. This Makefile is for people who already have the repository checked
# out — everyone else can use install.sh.
#
#   make               show this help
#   make build         rebuild bin/aidentity (and SHA256SUMS) after editing src/
#   make check         everything CI checks: lint, the test suite, the guards
#   make test AREA=ui  one area of the test suite (names: bash test/run_tests.sh --list)
#   make install       copy bin/aidentity to $(PREFIX)/bin
#   sudo make install  same, when /usr/local/bin needs root
#   make install PREFIX=$$HOME/.local
#
# PREFIX and BINDIR are overridable on the command line or from the environment.

PREFIX ?= /usr/local
BINDIR ?= $(PREFIX)/bin

SCRIPT   := bin/aidentity
TARGET   := $(BINDIR)/aidentity
TESTS    := test/run_tests.sh
TEST_SH  := $(TESTS) test/lib.sh $(sort $(wildcard test/t_*.sh))
SH_FILES := bin/aidentity install.sh uninstall.sh scripts/build.sh scripts/guards.sh scripts/release-notes.sh scripts/release-check.sh assets/record-demo.sh assets/film/build.sh assets/film/render.sh

# shellcheck findings we accept on purpose. Clear it to see everything:
#   make lint SHELLCHECK_EXCLUDE=
#   SC2034  colour variables kept as a complete set, even when one is unused
#   SC2012  ls over find in app discovery — .app names are known-safe here
#   SC2015  A && B || C, used deliberately where C is the error path
SHELLCHECK_EXCLUDE ?= SC2034,SC2012,SC2015

.DEFAULT_GOAL := help
.PHONY: help install uninstall build test lint check guards release formula

help: ## Show this help
	@printf 'aidentity — run several accounts of the same Mac app at the same time.\n\n'
	@printf 'Targets:\n'
	@awk 'BEGIN { FS = ":.*## " } /^[a-zA-Z_-]+:.*## / { printf "  %-12s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)
	@printf '\nVariables:\n'
	@printf '  %-12s %s\n' 'PREFIX' 'install root (currently: $(PREFIX))'
	@printf '  %-12s %s\n' 'BINDIR' 'install directory (currently: $(BINDIR))'
	@printf '\n'

install: ## Copy bin/aidentity into BINDIR
	@if [ ! -f "$(SCRIPT)" ]; then \
		printf 'Cannot find %s — run make from the repository root.\n' "$(SCRIPT)" >&2; \
		exit 1; \
	fi
	@bash scripts/build.sh --check
	@if [ ! -d "$(BINDIR)" ] && ! mkdir -p "$(BINDIR)" 2>/dev/null; then \
		printf 'Cannot create %s.\n  Try:  sudo make install PREFIX=%s\n' "$(BINDIR)" "$(PREFIX)" >&2; \
		exit 1; \
	fi
	@if [ ! -w "$(BINDIR)" ]; then \
		printf '%s is not writable by you.\n  Try:  sudo make install PREFIX=%s\n  Or:   make install PREFIX=$$HOME/.local\n' "$(BINDIR)" "$(PREFIX)" >&2; \
		exit 1; \
	fi
	install -m 0755 "$(SCRIPT)" "$(TARGET)"
	@printf 'Installed %s\n' "$(TARGET)"
	@"$(TARGET)" version 2>/dev/null || true
	@case ":$$PATH:" in \
		*":$(BINDIR):"*) ;; \
		*) printf '\nNote: %s is not on your PATH.\n      export PATH="%s:$$PATH"\n' "$(BINDIR)" "$(BINDIR)" ;; \
	esac

uninstall: ## Remove aidentity from BINDIR (leaves launchers and profile data alone)
	@if [ -e "$(TARGET)" ]; then \
		rm -f "$(TARGET)" && printf 'Removed %s\n' "$(TARGET)"; \
	else \
		printf 'Nothing to remove at %s\n' "$(TARGET)"; \
	fi
	@printf 'Launchers and profile data are untouched. To remove those too: ./uninstall.sh\n'

# The code is written in src/ and shipped as the one file bin/aidentity, which
# is committed: install.sh, `aidentity update` and Homebrew fetch it alone.
build: ## Rebuild bin/aidentity from src/, and SHA256SUMS with it
	@bash scripts/build.sh
	@$(MAKE) --no-print-directory checksums

# The suite, the lint, install and release read bin/aidentity, so a src/
# change that was not built yet would be used as the old code. They stop
# first and say so.
test: ## Run the test suite (test/run_tests.sh); AREA=ui runs one area
	@bash scripts/build.sh --check
	@if [ ! -f "$(TESTS)" ]; then \
		printf 'No test suite at %s\n' "$(TESTS)" >&2; \
		exit 1; \
	fi
	@/bin/bash "$(TESTS)" $$AREA

guards: ## Run the source guards CI runs (scripts/guards.sh)
	@bash scripts/guards.sh

check: lint test guards ## Everything CI checks, in one go

lint: ## shellcheck every shell file, or syntax-check them if shellcheck is absent
	@bash scripts/build.sh --check
	@if command -v shellcheck >/dev/null 2>&1; then \
		printf 'shellcheck\n'; \
		for f in $(SH_FILES) $(TEST_SH); do \
			[ -f "$$f" ] || { printf 'Missing: %s\n' "$$f" >&2; exit 1; }; \
			printf '  %s\n' "$$f"; \
			shellcheck -s bash $(if $(SHELLCHECK_EXCLUDE),-e $(SHELLCHECK_EXCLUDE),) "$$f" || exit 1; \
		done; \
		printf 'Lint passed.\n'; \
	else \
		printf 'shellcheck not installed — falling back to bash -n\n'; \
		printf '  (brew install shellcheck for the real thing)\n'; \
		for f in $(SH_FILES) $(TEST_SH); do \
			[ -f "$$f" ] || { printf 'Missing: %s\n' "$$f" >&2; exit 1; }; \
			printf '  %s\n' "$$f"; \
			bash -n "$$f" || exit 1; \
		done; \
		printf 'Syntax check passed — shellcheck was not run, so this is NOT a full lint.\n'; exit 0; \
	fi

# Keep this exact line format, "<64 hex>  bin/aidentity", and the file at the
# top of the repository: install.sh and every installed copy's
# `aidentity update` read it from there. scripts/guards.sh checks both.
# `make build` runs this too.
.PHONY: checksums
checksums: ## Regenerate SHA256SUMS for the current bin/aidentity
	@shasum -a 256 bin/aidentity | awk '{print $$1"  bin/aidentity"}' > SHA256SUMS
	@echo "SHA256SUMS updated"

# Releasing — see docs/homebrew-tap.md for the whole order. `release` makes the
# release commit's changes; `formula` runs after the tag is pushed, because the
# tarball's checksum does not exist before that.
#
# VERSION is checked first, from the environment (make passes command-line
# variables there), before any recipe line pastes $(VERSION) into the shell.
# The check covers the whole value: grep tested each line on its own, so a
# second line after a valid first one got through.
CHECK_VERSION = case "$$VERSION" in ''|*[!0-9.]*|.*|*.|*..*|*.*.*.*) false ;; *.*.*) true ;; *) false ;; esac

release: ## Prepare a release: make release VERSION=1.2.0
	@$(CHECK_VERSION) \
		|| { printf 'Usage: make release VERSION=x.y.z\n' >&2; exit 1; }
	@bash scripts/build.sh --check
	@cur=$$(sed -n 's/^AIDENTITY_VERSION="\(.*\)"$$/\1/p' src/00-header.sh); \
	 if grep -q "^## \[$$VERSION\]" CHANGELOG.md; then \
	   printf 'CHANGELOG.md already has a %s section. Nothing was changed.\n' "$$VERSION" >&2; exit 1; fi; \
	 newest=$$(printf '%s\n%s\n' "$$cur" "$$VERSION" | sort -t. -k1,1n -k2,2n -k3,3n | tail -n 1); \
	 if [ "$$cur" = "$$VERSION" ] || [ "$$newest" != "$$VERSION" ]; then \
	   printf '%s is not newer than the current %s. Nothing was changed.\n' "$$VERSION" "$$cur" >&2; exit 1; fi
	@grep -q '^## \[Unreleased\]' CHANGELOG.md \
		|| { printf 'CHANGELOG.md has no [Unreleased] section to release.\n' >&2; exit 1; }
	@perl -pi -e 's/^AIDENTITY_VERSION=".*"$$/AIDENTITY_VERSION="$(VERSION)"/' src/00-header.sh
	@perl -pi -e 's/^REF="\$$\{AIDENTITY_REF:-[^}]*\}"$$/REF="\$${AIDENTITY_REF:-v$(VERSION)}"/' install.sh
	@perl -0pi -e 's/^## \[Unreleased\]\n/## [Unreleased]\n\n## [$(VERSION)] - '"$$(date +%Y-%m-%d)"'\n/m' CHANGELOG.md
	@perl -0pi -e 's{^\[Unreleased\]: (\S+)/compare/(v[0-9.]+)\.\.\.HEAD$$}{[Unreleased]: $$1/compare/v$(VERSION)...HEAD\n[$(VERSION)]: $$1/compare/$$2...v$(VERSION)}m' CHANGELOG.md
	@$(MAKE) --no-print-directory build
	@bash scripts/guards.sh >/dev/null
	@printf '\nPrepared $(VERSION). Next:\n'
	@printf '  1. Commit, open a PR, merge it.\n'
	@printf '  2. git tag v$(VERSION) <merge commit> && git push origin v$(VERSION)\n'
	@printf '     The Release workflow then creates the GitHub release. Do not create it by hand.\n'
	@printf '  3. make formula VERSION=$(VERSION), then copy Formula/aidentity.rb to the tap.\n'

#
# The tarball is downloaded to a file and curl's own status is checked: piped
# straight into shasum, a failed download hashed to the empty-file checksum,
# which passed a length check, and the formula was "updated" to it.
formula: ## After the tag is pushed: point Formula/aidentity.rb at it
	@$(CHECK_VERSION) \
		|| { printf 'Usage: make formula VERSION=x.y.z\n' >&2; exit 1; }
	@url="https://github.com/PiniShv/aidentity/archive/refs/tags/v$(VERSION).tar.gz"; \
	 tmp=$$(mktemp) || exit 1; \
	 if ! curl -fsSL --proto '=https' --tlsv1.2 -o "$$tmp" "$$url"; then \
	   rm -f "$$tmp"; printf 'Could not download %s — is the tag pushed? Nothing was changed.\n' "$$url" >&2; exit 1; fi; \
	 sum=$$(shasum -a 256 "$$tmp" | awk '{print $$1}'); size=$$(wc -c < "$$tmp" | tr -d ' '); rm -f "$$tmp"; \
	 if [ "$${#sum}" -ne 64 ] || [ "$${size:-0}" -lt 1000 ] \
	    || [ "$$sum" = e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855 ]; then \
	   printf 'The download of %s looks wrong (%s bytes). Nothing was changed.\n' "$$url" "$${size:-0}" >&2; exit 1; fi; \
	 perl -pi -e "s|archive/refs/tags/v[0-9.]+\.tar\.gz|archive/refs/tags/v$(VERSION).tar.gz|g; s|^(\s*sha256 \")[0-9a-f]{64}(\")|\$${1}$$sum\$${2}|" Formula/aidentity.rb; \
	 printf 'Formula/aidentity.rb now points at v$(VERSION) (sha256 %s).\n' "$$sum"
