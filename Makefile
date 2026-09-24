# Development entry points; CI runs `make check`. QT_BIN points at the Qt 6
# tools because the qmllint on Arch's PATH belongs to qt5-declarative and
# silently accepts broken files.
QT_BIN ?= /usr/lib/qt6/bin
export QT_BIN

QML_FILES := $(shell find package tests -name '*.qml' | sort)
SHELL_FILES := install.sh $(wildcard scripts/*.sh) $(wildcard tests/*.sh)

.PHONY: check lint format format-check test

check: lint format-check test

lint:
	scripts/lint-qml.sh
	shellcheck $(SHELL_FILES)
	for f in $(SHELL_FILES); do bash -n "$$f"; done
	python3 -m py_compile tests/fake_ntfy.py
	actionlint .github/workflows/*.yml

format:
	$(QT_BIN)/qmlformat -i $(QML_FILES)

format-check:
	@status=0; for f in $(QML_FILES); do \
		$(QT_BIN)/qmlformat "$$f" | diff -u --label "$$f" --label "$$f (qmlformat)" "$$f" - || status=1; \
	done; \
	if [ $$status -ne 0 ]; then echo "run 'make format' to fix" >&2; fi; \
	exit $$status

test:
	tests/run.sh
