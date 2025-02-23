default: github

github:
	@bash "$(CURDIR)/scripts/build_image.sh" "ghcr"

#
# To build local images in a different platform architecture (from a macos m1 processor). (used to generate the azdo agent on macos)
# make local arch=Linux/amd64
#
# To build local images
# make local
local:
	echo ${arch}
	DOCKER_BUILDX_BAKE_FLAGS="--allow=network.host" @bash "$(CURDIR)/scripts/build_image.sh" "local" ${arch} ${agent}

dev:
	@bash "$(CURDIR)/scripts/build_image.sh" "dev" ${arch} ${agent}

ci:
	@bash "$(CURDIR)/scripts/build_image.sh" "ci"

alpha:
	@bash "$(CURDIR)/scripts/build_image.sh" "alpha"
