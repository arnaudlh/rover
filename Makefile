default: rust-build github

# Rust development targets
rust-build:
	cargo build --release

rust-test:
	cargo test --verbose

rust-lint:
	cargo clippy --all-targets --all-features -- -D warnings

rust-format:
	cargo fmt --all

rust-format-check:
	cargo fmt --all -- --check

rust-clean:
	cargo clean

github:
	@bash "$(CURDIR)/scripts/build_image.sh" "github"

#
# To build local images in a different platform architecture (from a macos m1 processor). (used to generate the azdo agent on macos)
# make local arch=Linux/amd64
#
# To build local images
# make local
local:
	echo ${arch}
	@bash "$(CURDIR)/scripts/build_image.sh" "local" ${arch} ${agent}

dev:
	@bash "$(CURDIR)/scripts/build_image.sh" "dev" ${arch} ${agent}

ci:
	@bash "$(CURDIR)/scripts/build_image.sh" "ci"

alpha:

# Development workflow
dev-setup: rust-build
	@echo "Development environment ready"

dev-test: rust-format-check rust-lint rust-test
	@echo "All development checks passed"

.PHONY: default rust-build rust-test rust-lint rust-format rust-format-check rust-clean github local dev ci alpha dev-setup dev-test

	@bash "$(CURDIR)/scripts/build_image.sh" "alpha"
