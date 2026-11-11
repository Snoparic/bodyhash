# SPDX-FileCopyrightText: 2026 Эрик Гусейнов-Соболь <Snoparic.job@mail.ru> (@Snoparic)
# SPDX-License-Identifier: MIT
PREFIX ?= /usr/local
BINDIR  = $(PREFIX)/bin
MANDIR  = $(PREFIX)/share/man
VERSION = 1.0.0
# Ищем все скрипты в проекте (кроме скрытых папок)
SCRIPTS := $(shell find . -type f \( -name "*.sh" -o -name "bodyhash" \) -not -path "*/.*")

all: help

help:
	@echo "bodyhash $(VERSION) — hash file body excluding marked regions"
	@echo ""
	@echo "Usage:"
	@echo "  make ci           Run all checks (check + lint + test)"
	@echo "  make check        Check syntax of all scripts (bash -n)"
	@echo "  make lint         Run static analysis (shellcheck)"
	@echo "  make test         Run test suite (bats)"
	@echo "  make install      Install to $(DESTDIR)$(PREFIX)"
	@echo "  make uninstall    Remove from $(DESTDIR)$(PREFIX)"
	@echo "  make dist         Create release tarball (bodyhash-$(VERSION).tar.gz)"
	@echo "  make clean        Remove build artifacts"

install:
	install -d $(DESTDIR)$(BINDIR) $(DESTDIR)$(MANDIR)/man1 $(DESTDIR)$(MANDIR)/ru/man1
	install -m 755 bodyhash $(DESTDIR)$(BINDIR)/bodyhash
	install -m 644 man/bodyhash.1 $(DESTDIR)$(MANDIR)/man1/bodyhash.1
	install -m 644 man/bodyhash.1.ru $(DESTDIR)$(MANDIR)/ru/man1/bodyhash.1

uninstall:
	rm -f $(DESTDIR)$(BINDIR)/bodyhash
	rm -f $(DESTDIR)$(MANDIR)/man1/bodyhash.1
	rm -f $(DESTDIR)$(MANDIR)/ru/man1/bodyhash.1

check:
	@echo "Checking syntax for: $(SCRIPTS)"
	@for f in $(SCRIPTS); do \
		echo "  bash -n $$f"; \
		bash -n "$$f" || exit 1; \
	done
	@echo "Syntax OK."

lint:
	@if command -v shellcheck >/dev/null 2>&1; then \
		echo "Running shellcheck on: $(SCRIPTS)"; \
		shellcheck $(SCRIPTS); \
	else \
		echo "Warning: shellcheck not installed, skipping lint."; \
	fi

test:
	bats tests/

ci: check lint test
	@echo "========================================"
	@echo "All checks passed successfully!"
	@echo "========================================"

dist: clean
	tar -czf bodyhash-$(VERSION).tar.gz bodyhash man/ tests/ Makefile README.md LICENSE
	@echo "Created bodyhash-$(VERSION).tar.gz"

clean:
	rm -f bodyhash-*.tar.gz

.PHONY: all help install uninstall check lint test ci dist clean
