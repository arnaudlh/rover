#!/usr/bin/env bash

error() {
    local parent_lineno="$1"
    local message="$2"
    local code="${3:-1}"
    local line_message=""
    if [ "$parent_lineno" != "" ]; then
        line_message="on or near line ${parent_lineno}"
    fi

    if [[ -n "$message" ]]; then
        echo >&2 -e "\e[41mError $line_message: ${message}; exiting with status ${code}\e[0m"
    else
        echo >&2 -e "\e[41mError $line_message; exiting with status ${code}\e[0m"
    fi
    echo ""

    cleanup

    exit ${code}
}

cleanup() {
    docker buildx rm rover 2>/dev/null || true
    docker rm --force registry_rover_tmp 2>/dev/null || true
}

get_arch() {
    if [ "${1}" != "" ]; then
        os=$(echo "${1}" | cut -d'/' -f1)
        architecture=$(echo "${1}" | cut -d'/' -f2)
    else
        os=linux
        architecture=$(echo $(uname -m))
    fi
}

set -ETe
trap 'error ${LINENO}' ERR 1 2 3 6

./scripts/pre_requisites.sh

params=$@
build_date=date
tag_date_preview=$(${build_date} +"%g%m.%d%H%M")
tag_date_release=$(${build_date} +"%g%m.%d%H")
export strategy=${1}

get_arch ${arch}
echo "OS: $os"
echo "Architecture: $architecture"

export DOCKER_CLIENT_TIMEOUT=600
export COMPOSE_HTTP_TIMEOUT=600

echo "params ${params}"
echo "date ${build_date}"

function build_base_rover_image {
    echo "params ${params}"
    versionTerraform=${1}
    strategy=${2}

    echo "@build_base_rover_image"
    echo "Building base image with:"
    echo " - versionTerraform - ${versionTerraform}"
    echo " - strategy                 - ${strategy}"

    echo "Terraform version - ${versionTerraform}"

    case "${strategy}" in
        "ghcr")
            registry="ghcr.io/${GITHUB_REPOSITORY:-arnaudlh/rover}/"
            tag=${versionTerraform}-${tag_date_release}
            rover_base="${registry}rover"
            rover="${rover_base}:${tag}"
            export tag_strategy=""
            ;;
        "github")
            registry="ghcr.io/${GITHUB_REPOSITORY:-arnaudlh/rover}/"
            tag=${versionTerraform}-${tag_date_release}
            rover_base="${registry}rover"
            rover="${rover_base}:${tag}"
            export tag_strategy=""
            ;;
        "alpha")
            registry="ghcr.io/${GITHUB_REPOSITORY:-arnaudlh/rover}/"
            tag=${versionTerraform}-${tag_date_preview}
            rover_base="${registry}rover-alpha"
            rover="${rover_base}:${tag}"
            export tag_strategy="alpha-"
            ;;
        "dev")
            registry="ghcr.io/${GITHUB_REPOSITORY:-arnaudlh/rover}/"
            tag=${versionTerraform}-${tag_date_preview}
            rover_base="${registry}rover-preview"
            export rover="${rover_base}:${tag}"
            tag_strategy="preview-"
            ;;
        "ci")
            registry="symphonydev.azurecr.io/"
            tag=${versionTerraform}-${tag_date_preview}
            rover_base="${registry}rover-ci"
            export rover="${rover_base}:${tag}"
            tag_strategy="ci-"
            ;;
        "local")
            registry="localhost:5000/"
            tag=${versionTerraform}-${tag_date_preview}
            rover_base="${registry}rover-local"
            export rover="${rover_base}:${tag}"
            tag_strategy="local-"
            ;;
    esac

    echo "Creating version ${rover}"

    case "${strategy}" in
        "local")
            echo "Building rover locally"

            registry="${registry}" \
            versionRover="${rover_base}:${tag}" \
            versionTerraform=${versionTerraform} \
            tag="${rover}" \
            TARGETARCH=${architecture} \
            TARGETOS=${os} \
            USER_UID=1000 \
            USER_GID=1000 \
            USERNAME=vscode \
            versionVault=1.15.0 \
            versionGolang=1.21.6 \
            versionKubectl=1.28.4 \
            versionKubelogin=0.1.0 \
            versionDockerCompose=2.24.1 \
            versionTerraformDocs=0.17.0 \
            versionPacker=1.10.0 \
            versionPowershell=7.4.1 \
            versionAnsible=2.16.2 \
            extensionsAzureCli=aks-preview \
            versionTerrascan=1.18.3 \
            versionTfupdate=0.7.2 \
            mkdir -p /home/ubuntu/docker-tmp && \
            export DOCKER_TMPDIR=/home/ubuntu/docker-tmp && \
            export TMPDIR=/home/ubuntu/docker-tmp && \
            docker buildx rm rover || true && \
            docker buildx create --name rover --driver docker-container --use && \
            docker buildx inspect --bootstrap && \
            docker buildx bake \
                --allow=fs.read=/var/lib/buildkit/cache \
                --allow=fs.write=/var/lib/buildkit/cache-new \
                -f docker-bake.hcl \
                $([ -f docker-bake.override.hcl ] && echo "-f docker-bake.override.hcl") \
                --set "*.args.TARGETARCH=${architecture}" \
                --set "*.args.TARGETOS=${os}" \
                --set "*.args.versionRover=localhost:5000/rover:local" \
                --set "*.args.versionTerraform=${versionTerraform}" \
                --set "*.tags=rover:local" \
                --load \
                rover_local && \
            # Ensure the local image is available
            # Build agents using local image
            DOCKER_BUILDKIT=1 docker buildx bake \
                --allow=network.host \
                --allow=fs.read=/var/lib/buildkit/cache \
                --allow=fs.write=/var/lib/buildkit/cache-new \
                -f docker-bake-agents.hcl \
                $([ -f docker-bake.override.hcl ] && echo "-f docker-bake.override.hcl") \
                --set "*.platform=linux/amd64" \
                --set "*.args.versionRover=localhost:5000/rover:local" \
                --load \
                rover_agents
            # Local build complete
            echo "Local build completed successfully"
            ;;
        "dev")
            echo "Building rover developer image and pushing to GHCR"
            registry="ghcr.io/${GITHUB_REPOSITORY:-arnaudlh/rover}/" \
            versionRover="${rover_base}:${tag}" \
            versionTerraform=${versionTerraform} \
            tag="${rover}" \
            docker buildx bake \
                --allow=network.host \
                --allow=fs.read=/var/lib/buildkit/cache \
                --allow=fs.write=/var/lib/buildkit/cache-new \
                -f docker-bake.hcl \
                $([ -f docker-bake.override.hcl ] && echo "-f docker-bake.override.hcl") \
                --set *.platform=${os}/${architecture} \
                --push rover_registry
            ;;
        *)
            echo "Building rover image and pushing to GHCR"
            registry="ghcr.io/${GITHUB_REPOSITORY:-arnaudlh/rover}/" \
            versionRover="${rover_base}:${tag}" \
            versionTerraform=${versionTerraform} \
            tag="${tag}" \
            docker buildx bake \
                --allow=network.host \
                --allow=fs.read=/var/lib/buildkit/cache \
                --allow=fs.write=/var/lib/buildkit/cache-new \
                -f docker-bake.hcl \
                $([ -f docker-bake.override.hcl ] && echo "-f docker-bake.override.hcl") \
                --push rover_registry
            ;;
    esac

    echo "Image ${rover} created."


}

function build_rover_agents {
    # Build the rover agents and runners
    rover=${1}
    tag=${2}
    registry=${3}


    echo "@build_rover_agents"
    echo "Building agents with:"
    echo " - registry      - ${registry}"
    echo " - version Rover - ${rover_base}:${tag}"
    echo " - strategy      - ${strategy}"
    echo " - tag_strategy  - ${tag_strategy}"
    echo " - agent          - ${agent}"

    tag=${versionTerraform}-${tag_date_preview}

    case "${strategy}" in
        "local"|"dev")

            if [[ ! -z $agent ]]; then
                rover_agents=$agent
            else
                rover_agents="rover_agents"
            fi

            echo " - tag           - ${tag}"
            platform="${architecture}"
            rover_agents="${rover_agents}"

            registry="" \
            tag_strategy=${tag_strategy} \
            versionRover="${rover_base}:${tag}" \
            versionTerraform=${versionTerraform} \
            tag="${tag}" \
            docker buildx bake \
                --allow=network.host \
                --allow=fs.read=/var/lib/buildkit/cache \
                --allow=fs.write=/var/lib/buildkit/cache-new \
                -f docker-bake-agents.hcl \
                -f docker-bake.override.hcl \
                --set *.platform=${os}/${platform} \
                --load ${rover_agents}

            echo "Agents created under tag ${registry}rover-agent:${tag}-${tag_strategy}${rover_agents} for registry '${registry}'"
            ;;
        "github"|"ghcr")
            tag=${versionTerraform}-${tag_date_release}
            echo " - tag           - ${tag}"

            registry="${registry}" \
            tag_strategy=${tag_strategy} \
            versionRover="${rover_base}:${tag}" \
            versionTerraform=${versionTerraform} \
            tag="${tag}" \
            docker buildx bake \
                --allow=network.host \
                --allow=fs.read=/var/lib/buildkit/cache \
                --allow=fs.write=/var/lib/buildkit/cache-new \
                -f docker-bake-agents.hcl \
                $([ -f docker-bake.override.hcl ] && echo "-f docker-bake.override.hcl") \
                --push rover_agents

            echo "Agents created under tag ${registry}rover-agent:${tag}-${tag_strategy}* for registry '${registry}'"
            ;;
        "ci")
            echo " - tag           - ${tag}"
            registry="${registry}" \
            tag_strategy=${tag_strategy} \
            versionRover="${rover_base}:${tag}" \
            versionTerraform=${versionTerraform} \
            tag="${tag}" \
            docker buildx bake \
                -f docker-bake-agents.hcl \
                -f docker-bake.override.hcl \
                --push gitlab

            echo "Agents created under tag ${registry}rover-agent:${tag}-${tag_strategy}* for registry '${registry}'"
            ;;
        *)
            echo " - tag           - ${tag}"
            registry="${registry}" \
            tag_strategy=${tag_strategy} \
            versionRover="${rover_base}:${tag}" \
            versionTerraform=${versionTerraform} \
            tag="${tag}" \
            docker buildx bake \
                -f docker-bake-agents.hcl \
                -f docker-bake.override.hcl \
                --push rover_agents

            echo "Agents created under tag ${registry}rover-agent:${tag}-${tag_strategy}* for registry '${registry}'"
            ;;
    esac

}

cleanup
docker buildx create --use --name rover --bootstrap --driver-opt network=host

case "${strategy}" in
    "local")
        # In memory docker registry required to store base image in local registry. This is due to buildkit docker-container not having access to docker host cache.
        docker run -d --name registry_rover_tmp --network=host registry:2 2>/dev/null || true
        ;;
esac

echo "Building rover images."
if [ "$strategy" == "ci" ]; then
    build_base_rover_image "1.0.0" ${strategy}
else
    while read versionTerraform; do
        build_base_rover_image ${versionTerraform} ${strategy}
    done <./.env.terraform

    if [ "${agent}" != "0" ]; then
        while read versionTerraform; do
            build_rover_agents "${rover}" "${tag}" "${registry}"
        done <./.env.terraform
    fi
fi


case "${strategy}" in
    "local")
        docker rm --force registry_rover_tmp || true
        ;;
esac

docker buildx rm rover
