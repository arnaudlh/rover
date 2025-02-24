FROM ubuntu:22.04@sha256:77906da86b60585ce12215807090eb327e7386c8fafb5402369e421f44eff17e AS base

ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=1000
ARG TF_PLUGIN_CACHE_DIR=/tf/cache
ARG TARGETARCH
ARG TARGETOS
ARG versionVault
ARG versionGolang
ARG versionKubectl
ARG versionKubelogin
ARG versionDockerCompose
ARG versionTerraformDocs
ARG versionPacker
ARG versionPowershell
ARG versionAnsible
ARG extensionsAzureCli
ARG versionTerrascan
ARG versionTfupdate

WORKDIR /tf/rover

COPY ./scripts/.kubectl_aliases .
COPY ./scripts/zsh-autosuggestions.zsh .

# Install base packages
RUN set -ex && \
    mkdir -p /var/lib/apt/lists/partial /etc/apt/trusted.gpg.d /etc/apt/keyrings && \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        apt-transport-https \
        apt-utils \
        bsdmainutils \
        ca-certificates \
        curl \
        fonts-powerline \
        gcc \
        gettext \
        git \
        gpg \
        gpg-agent \
        jq \
        less \
        locales \
        lsb-release \
        make \
        python3-dev \
        python3-pip \
        rsync \
        software-properties-common \
        sudo \
        unzip \
        vim \
        wget \
        zsh \
        zip && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Set up package repositories
# Set up package repositories
ARG TARGETARCH
RUN set -ex && \
    # Create required directories
    mkdir -p /etc/apt/trusted.gpg.d /etc/apt/keyrings && \
    # Update package lists
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        gnupg \
        lsb-release && \
    # Microsoft repository
    curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /etc/apt/trusted.gpg.d/microsoft.gpg && \
    echo "deb [arch=$(dpkg --print-architecture)] https://packages.microsoft.com/ubuntu/22.04/prod jammy main" > /etc/apt/sources.list.d/microsoft.list && \
    # Docker repository
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg && \
    chmod a+r /etc/apt/keyrings/docker.gpg && \
    echo "deb [arch=$(dpkg --print-architecture)] https://download.docker.com/linux/ubuntu jammy stable" > /etc/apt/sources.list.d/docker.list && \
    # Kubernetes repository
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture)] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /" > /etc/apt/sources.list.d/kubernetes.list && \
    # GitHub CLI repository
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/etc/apt/trusted.gpg.d/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture)] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list && \
    # Verify architecture
    echo "Building for architecture: $(dpkg --print-architecture)"

# Install additional packages
RUN set -ex && \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        docker-ce-cli \
        kubectl \
        gh \
        lsb-release \
        apt-transport-https \
        ca-certificates \
        gnupg2 && \
    # Verify installations
    docker --version || true && \
    kubectl version --client || true && \
    gh --version || true && \
    # Cleanup
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    # Verify architecture
    echo "Target Architecture: ${TARGETARCH}"

# Install tools
RUN set -ex && \
    # Install docker compose
    mkdir -p /usr/libexec/docker/cli-plugins/ && \
    if [ "${TARGETARCH}" = "amd64" ]; then \
        curl -L -o /usr/libexec/docker/cli-plugins/docker-compose https://github.com/docker/compose/releases/download/v${versionDockerCompose}/docker-compose-${TARGETOS}-x86_64; \
    else \
        curl -L -o /usr/libexec/docker/cli-plugins/docker-compose https://github.com/docker/compose/releases/download/v${versionDockerCompose}/docker-compose-${TARGETOS}-aarch64; \
    fi && \
    chmod +x /usr/libexec/docker/cli-plugins/docker-compose && \
    docker-compose version || true && \
    # Install Helm
    curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash && \
    helm version || true && \
    # Install Python packages with retries and verification
    for i in {1..3}; do \
        if pip3 install --no-cache-dir \
            pre-commit \
            yq \
            azure-cli \
            checkov \
            pywinrm \
            ansible-core==${versionAnsible}; then \
            python3 -m pip list | grep -E "pre-commit|yq|azure-cli|checkov|pywinrm|ansible-core" && \
            break; \
        fi; \
        if [ $i -eq 3 ]; then \
            exit 1; \
        fi; \
        sleep 5; \
    done && \
    # Install Azure CLI extensions with error handling
    az extension add --name ${extensionsAzureCli} --system || true && \
    az extension add --name containerapp --system || true && \
    az config set extension.use_dynamic_install=yes_without_prompt || true && \
    az version || true && \
    # Install shellspec
    curl -fsSL https://git.io/shellspec | sh -s -- --yes && \
    shellspec --version || true && \
    # Install Golang with verification
    curl -sSL -o /tmp/golang.tar.gz https://go.dev/dl/go${versionGolang}.${TARGETOS}-${TARGETARCH}.tar.gz && \
    tar -C /usr/local -xzf /tmp/golang.tar.gz && \
    rm /tmp/golang.tar.gz && \
    export PATH=$PATH:/usr/local/go/bin && \
    go version || true

# Set up user and permissions
RUN set -ex && \
    groupadd docker && \
    useradd --uid ${USER_UID} -m -G docker ${USERNAME} && \
    locale-gen en_US.UTF-8 && \
    mkdir -p /tf/cache && \
    chown -R ${USERNAME}:${USERNAME} ${TF_PLUGIN_CACHE_DIR} && \
    mkdir -p \
        /tf/caf \
        /tf/rover \
        /tf/logs \
        /home/${USERNAME}/.ansible \
        /home/${USERNAME}/.azure \
        /home/${USERNAME}/.gnupg \
        /home/${USERNAME}/.packer.d \
        /home/${USERNAME}/.ssh \
        /home/${USERNAME}/.ssh-localhost \
        /home/${USERNAME}/.terraform.logs \
        /home/${USERNAME}/.terraform.cache \
        /home/${USERNAME}/.terraform.cache/tfstates \
        /home/${USERNAME}/.vscode-server \
        /home/${USERNAME}/.vscode-server-insiders && \
    chown -R ${USER_UID}:${USER_GID} /home/${USERNAME} /tf/rover /tf/caf /tf/logs && \
    chmod 777 -R /home/${USERNAME} /tf/caf /tf/rover && \
    chmod 700 /home/${USERNAME}/.ssh && \
    echo "${USERNAME} ALL=(root) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME} && \
    chmod 0440 /etc/sudoers.d/${USERNAME}

# Configure shell
RUN set -ex && \
    mkdir /commandhistory && \
    touch /commandhistory/.bash_history && \
    chown -R ${USERNAME} /commandhistory && \
    echo "set -o history" >> "/home/${USERNAME}/.bashrc" && \
    echo "export HISTCONTROL=ignoredups:erasedups" >> "/home/${USERNAME}/.bashrc" && \
    echo 'PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND$'\n'}history -a; history -c; history -r"' >> "/home/${USERNAME}/.bashrc" && \
    echo "[ -f /tf/rover/.kubectl_aliases ] && source /tf/rover/.kubectl_aliases" >> "/home/${USERNAME}/.bashrc" && \
    echo 'alias watch="watch "' >> "/home/${USERNAME}/.bashrc"

# Clean up
RUN set -ex && \
    apt-get remove -y \
        gcc \
        python3-dev \
        apt-utils && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /tmp/* && \
    rm -rf /var/lib/apt/lists/* && \
    find . | grep -E "(__pycache__|\.pyc|\.pyo$)" | xargs rm -rf
