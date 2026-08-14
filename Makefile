# aidentity — https://github.com/PiniShv/aidentity
#
# aidentity is one shell script. Installing it is a copy; uninstalling is a
# delete. This Makefile is for people who already have the repository checked
# out — everyone else can use install.sh.
#
#   make               show this help
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
SH_FILES := bin/aidentity install.sh uninstall.sh

# shellcheck findings we accept on purpose. Clear it to see everything:
#   make lint SHELLCHECK_EXCLUDE=
#   SC2034  colour variables kept as a complete set, even when one is unused
#   SC2012  ls over find in app discovery — .app names are known-safe here
#   SC2015  A && B || C, used deliberately where C is the error path
SHELLCHECK_EXCLUDE ?= SC2034,SC2012,SC2015

.DEFAULT_GOAL := help
.PHONY: help install uninstall test lint

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

test: ## Run the test suite (test/run_tests.sh)
	@if [ ! -f "$(TESTS)" ]; then \
		printf 'No test suite at %s\n' "$(TESTS)" >&2; \
		exit 1; \
	fi
	@bash "$(TESTS)"

lint: ## shellcheck every shell file, or syntax-check them if shellcheck is absent
	@if command -v shellcheck >/dev/null 2>&1; then \
		printf 'shellcheck\n'; \
		for f in $(SH_FILES) $(TESTS); do \
			[ -f "$$f" ] || continue; \
			printf '  %s\n' "$$f"; \
			shellcheck -s bash $(if $(SHELLCHECK_EXCLUDE),-e $(SHELLCHECK_EXCLUDE),) "$$f" || exit 1; \
		done; \
	else \
		printf 'shellcheck not installed — falling back to bash -n\n'; \
		printf '  (brew install shellcheck for the real thing)\n'; \
		for f in $(SH_FILES) $(TESTS); do \
			[ -f "$$f" ] || continue; \
			printf '  %s\n' "$$f"; \
			bash -n "$$f" || exit 1; \
		done; \
	fi
	@printf 'Lint passed.\n'
