.PHONY: test lint format format-check check

test:
	./tests/run.sh

lint:
	./scripts/check-lua.sh

format:
	./scripts/run-stylua.sh lua tests dev

format-check:
	./scripts/run-stylua.sh --check lua tests dev

check: test lint format-check
