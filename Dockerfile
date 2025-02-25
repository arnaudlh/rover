FROM ubuntu:24.04 AS base

ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=1000
ARG TF_PLUGIN_CACHE_DIR=/tf/cache
ARG TARGETARCH
ARG TARGETOS

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8 \
    PATH="${PATH}:/opt/mssql-tools/bin:/home/vscode/.local/lib/shellspec/bin:/home/vscode/go/bin:/usr/local/go/bin" \
    TF_DATA_DIR="/home/${USERNAME}/.terraform.cache" \
    TF_PLUGIN_CACHE_DIR="${TF_PLUGIN_CACHE_DIR}" \
    TF_REGISTRY_DISCOVERY_RETRY=5 \
    TF_REGISTRY_CLIENT_TIMEOUT=15 \
    ARM_USE_MSGRAPH=true \
    BUILDKIT_STEP_LOG_MAX_SIZE=10485760 \
    BUILDKIT_STEP_LOG_MAX_SPEED=10485760

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

# Install base packages with retries
RUN set -ex && \
    mkdir -p /var/lib/apt/lists/partial /etc/apt/trusted.gpg.d /etc/apt/keyrings && \
    # Update package lists with retries and better error handling
    for i in {1..3}; do \
        if apt-get update; then \
            echo "Package lists updated successfully" && \
            break; \
        fi; \
        echo "Attempt $i to update package lists failed, retrying in 5 seconds..." && \
        if [ $i -eq 3 ]; then echo "Failed to update package lists" && exit 1; fi; \
        sleep 5; \
    done && \
    # Install core packages with retries
    for i in {1..5}; do \
        echo "Attempt $i: Installing core packages..." && \
        if DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
            apt-transport-https \
            apt-utils \
            bsdmainutils \
            ca-certificates \
            curl \
            dnsutils \
            fonts-powerline \
            gcc \
            gettext \
            git \
            gnupg \
            gpg \
            gpg-agent \
            jq \
            less \
            libstrongswan-extra-plugins \
            libtss2-tcti-tabrmd0 \
            locales \
            make \
            net-tools \
            network-manager-openvpn \
            openssh-client \
            openvpn \
            python3-dev \
            python3-pip \
            rsync \
            software-properties-common \
            strongswan \
            strongswan-pki \
            sudo \
            traceroute \
            unzip \
            vim \
            wget \
            zip \
            zsh && \
            echo "Verifying core package installations..." && \
            command -v curl >/dev/null 2>&1 && \
            command -v git >/dev/null 2>&1 && \
            command -v gpg >/dev/null 2>&1 && \
            command -v python3 >/dev/null 2>&1; then \
            echo "Successfully installed and verified core packages" && \
            break; \
        fi; \
        echo "Attempt $i to install packages failed, retrying in 5 seconds..." && \
        if [ $i -eq 3 ]; then \
            echo "Failed to install core packages after 3 attempts" && \
            exit 1; \
        fi; \
        sleep 5; \
    done && \
    # Clean up
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Set up package repositories with retries and improved error handling
ARG TARGETARCH
RUN set -ex && \
    # Create required directories and verify architecture
    mkdir -p /etc/apt/trusted.gpg.d /etc/apt/keyrings && \
    echo "Building for architecture: ${TARGETARCH}" && \
    # Configure package repositories with retries
    for i in {1..3}; do \
        echo "Attempt $i: Configuring package repositories..." && \
        if mkdir -p /etc/apt/trusted.gpg.d /etc/apt/keyrings && \
           # Microsoft repository
           { curl -fsSL --retry 3 --retry-delay 5 https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /etc/apt/trusted.gpg.d/microsoft.gpg && \
           echo "deb [arch=${TARGETARCH} signed-by=/etc/apt/trusted.gpg.d/microsoft.gpg] https://packages.microsoft.com/ubuntu/24.04/prod noble main" > /etc/apt/sources.list.d/microsoft.list && \
           echo "Microsoft repository configured successfully"; } && \
           # Docker repository
           { curl -fsSL --retry 3 --retry-delay 5 https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg && \
           chmod a+r /etc/apt/keyrings/docker.gpg && \
           echo "deb [arch=${TARGETARCH} signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu noble stable" > /etc/apt/sources.list.d/docker.list && \
           echo "Docker repository configured successfully"; } && \
           # Kubernetes repository
           { curl -fsSL --retry 3 --retry-delay 5 https://pkgs.k8s.io/core:/stable:/v${versionKubectl}/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-archive-keyring.gpg && \
           chmod a+r /etc/apt/keyrings/kubernetes-archive-keyring.gpg && \
           echo "deb [arch=${TARGETARCH} signed-by=/etc/apt/keyrings/kubernetes-archive-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${versionKubectl}/deb/ /" > /etc/apt/sources.list.d/kubernetes.list && \
           echo "Kubernetes repository configured successfully"; } && \
           # GitHub CLI repository
           { curl -fsSL --retry 3 --retry-delay 5 https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/etc/apt/trusted.gpg.d/githubcli-archive-keyring.gpg && \
           chmod a+r /etc/apt/trusted.gpg.d/githubcli-archive-keyring.gpg && \
           echo "deb [arch=${TARGETARCH} signed-by=/etc/apt/trusted.gpg.d/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list && \
           echo "GitHub CLI repository configured successfully"; } && \
           # Update package lists after adding repositories
           { apt-get update && echo "Package lists updated successfully"; }; then \
            echo "Successfully configured all package repositories" && \
            break; \
        fi; \
        echo "Attempt $i failed, retrying in 5 seconds..." && \
        if [ $i -eq 3 ]; then \
            echo "Failed to configure package repositories after 3 attempts" && \
            exit 1; \
        fi; \
        sleep 5; \
    done&& \
    # Install repository-specific packages with retries
    for i in {1..5}; do \
        if DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
            docker-ce-cli \
            gh \
            kubectl && \
            docker --version && \
            gh --version && \
            kubectl version --client; then \
            echo "Successfully installed repository packages" && \
            break; \
        fi; \
        echo "Attempt $i failed, retrying in 10 seconds..." && \
        if [ $i -eq 5 ]; then exit 1; fi; \
        sleep 10; \
    done && \
    # Install Docker Compose with retries
    for i in {1..3}; do \
        if mkdir -p /usr/libexec/docker/cli-plugins/ && \
           if [ "${TARGETARCH}" = "amd64" ]; then \
               curl -L -o /usr/libexec/docker/cli-plugins/docker-compose https://github.com/docker/compose/releases/download/v${versionDockerCompose}/docker-compose-${TARGETOS}-x86_64; \
           else \
               curl -L -o /usr/libexec/docker/cli-plugins/docker-compose https://github.com/docker/compose/releases/download/v${versionDockerCompose}/docker-compose-${TARGETOS}-aarch64; \
           fi && \
           chmod +x /usr/libexec/docker/cli-plugins/docker-compose && \
           docker-compose version || true; then \
            break; \
        fi; \
        if [ $i -eq 3 ]; then exit 1; fi; \
        sleep 5; \
    done && \
    # Install Helm with retries
    for i in {1..3}; do \
        if curl -fsSL https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash && \
           helm version || true; then \
            break; \
        fi; \
        if [ $i -eq 3 ]; then exit 1; fi; \
        sleep 5; \
    done

# Install additional packages with retries and verification
RUN set -ex && \
    # Install system packages with retries
    for i in {1..3}; do \
        echo "Attempt $i: Installing system packages..." && \
        if apt-get update && \
           DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
            python3-pip \
            python3-dev \
            python3-venv \
            python3-setuptools \
            python3-wheel && \
            echo "Successfully installed Python packages" && \
            python3 --version; then \
            break; \
        fi; \
        echo "Attempt $i failed, retrying in 5 seconds..." && \
        if [ $i -eq 3 ]; then \
            echo "Failed to install Python packages after 3 attempts" && \
            exit 1; \
        fi; \
        sleep 5; \
    done && \
    # Install pip packages with retries and better error handling
    for i in {1..5}; do \
        echo "Attempt $i: Installing Python packages..." && \
        if python3 -m pip install --upgrade pip setuptools wheel && \
           python3 -m pip install --no-cache-dir --timeout 60 --retries 3 \
            'pre-commit' \
            'yq' \
            'azure-cli' \
            'checkov' \
            'pywinrm' \
            'ansible-core==${versionAnsible}' && \
            echo "Successfully installed Python packages" && \
            python3 -m pip check; then \
            break; \
        fi; \
        echo "Attempt $i failed with exit code $?, retrying in 10 seconds..." && \
        if [ $i -eq 5 ]; then \
            echo "Failed to install Python packages after 5 attempts" && \
            exit 1; \
        fi; \
        sleep 10; \
    done && \
    # Verify Python package installations
    python3 -m pip list | grep -E "pre-commit|yq|azure-cli|checkov|pywinrm|ansible-core" && \
    # Cleanup
    apt-get remove -y python3-dev && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    # Verify architecture
    echo "Target Architecture: ${TARGETARCH}"

# Install tools with retries and improved verification
RUN set -ex && \
    # Install docker compose with retries and verification
    mkdir -p /usr/libexec/docker/cli-plugins/ && \
    for i in {1..3}; do \
        echo "Attempt $i: Installing Docker Compose..." && \
        if [ "${TARGETARCH}" = "amd64" ]; then \
            if curl -L --retry 3 --retry-delay 5 -o /usr/libexec/docker/cli-plugins/docker-compose \
                https://github.com/docker/compose/releases/download/v${versionDockerCompose}/docker-compose-${TARGETOS}-x86_64 && \
               chmod +x /usr/libexec/docker/cli-plugins/docker-compose && \
               docker-compose version; then \
                echo "Docker Compose installed successfully" && \
                break; \
            fi; \
        else \
            if curl -L --retry 3 --retry-delay 5 -o /usr/libexec/docker/cli-plugins/docker-compose \
                https://github.com/docker/compose/releases/download/v${versionDockerCompose}/docker-compose-${TARGETOS}-aarch64 && \
               chmod +x /usr/libexec/docker/cli-plugins/docker-compose && \
               docker-compose version; then \
                echo "Docker Compose installed successfully" && \
                break; \
            fi; \
        fi; \
        echo "Attempt $i failed, retrying in 5 seconds..." && \
        if [ $i -eq 3 ]; then \
            echo "Failed to install Docker Compose after 3 attempts" && \
            exit 1; \
        fi; \
        sleep 5; \
    done&& \
    # Install Helm with retries
    for i in {1..3}; do \
        if curl -fsSL https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash; then \
            helm version || true && break; \
        fi; \
        if [ $i -eq 3 ]; then exit 1; fi; \
        sleep 5; \
    done && \
    # Install Azure CLI extensions with retries
    for i in {1..3}; do \
        if az extension add --name ${extensionsAzureCli} --system && \
           az extension add --name containerapp --system && \
           az config set extension.use_dynamic_install=yes_without_prompt; then \
            az version || true && break; \
        fi; \
        if [ $i -eq 3 ]; then exit 1; fi; \
        sleep 5; \
    done && \
    # Install shellspec with retries
    for i in {1..3}; do \
        if curl -fsSL https://git.io/shellspec | sh -s -- --yes; then \
            shellspec --version || true && break; \
        fi; \
        if [ $i -eq 3 ]; then exit 1; fi; \
        sleep 5; \
    done && \
    # Install Golang with retries
    for i in {1..3}; do \
        if curl -sSL -o /tmp/golang.tar.gz https://go.dev/dl/go${versionGolang}.${TARGETOS}-${TARGETARCH}.tar.gz && \
           tar -C /usr/local -xzf /tmp/golang.tar.gz; then \
            rm /tmp/golang.tar.gz && \
            export PATH=$PATH:/usr/local/go/bin && \
            go version || true && break; \
        fi; \
        if [ $i -eq 3 ]; then exit 1; fi; \
        sleep 5; \
    done

# Install shell tools with retries and improved verification
RUN set -ex && \
    # Install kubectl-node_shell with retries and verification
    for i in {1..3}; do \
        echo "Attempt $i: Installing kubectl-node_shell..." && \
        if curl -L0 --retry 3 --retry-delay 5 -o /usr/local/bin/kubectl-node_shell \
            https://github.com/kvaps/kubectl-node-shell/raw/master/kubectl-node_shell && \
           chmod +x /usr/local/bin/kubectl-node_shell && \
           kubectl-node_shell --help; then \
            echo "kubectl-node_shell installed successfully" && \
            break; \
        fi; \
        echo "Attempt $i failed, retrying in 5 seconds..." && \
        if [ $i -eq 3 ]; then \
            echo "Failed to install kubectl-node_shell after 3 attempts" && \
            exit 1; \
        fi; \
        sleep 5; \
    done&& \
    # Install git bash completion with retries
    for i in {1..3}; do \
        if mkdir -p /etc/bash_completion.d/ && \
           curl -fsSL https://raw.githubusercontent.com/git/git/master/contrib/completion/git-completion.bash -o /etc/bash_completion.d/git-completion.bash; then \
            break; \
        fi; \
        if [ $i -eq 3 ]; then exit 1; fi; \
        sleep 5; \
    done && \
    # Install Oh My Zsh with retries
    for i in {1..3}; do \
        if curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh | bash -s -- --unattended && \
           chmod 700 -R /home/${USERNAME}/.oh-my-zsh; then \
            break; \
        fi; \
        if [ $i -eq 3 ]; then exit 1; fi; \
        sleep 5; \
    done

# Install Terraform and HashiCorp tools with retries and improved verification
RUN set -ex && \
    # Install Terraform with retries and verification
    for i in {1..3}; do \
        echo "Attempt $i: Installing Terraform..." && \
        if curl -sSL --retry 3 --retry-delay 5 -o /tmp/terraform.zip \
            "https://releases.hashicorp.com/terraform/${versionTerraform}/terraform_${versionTerraform}_${TARGETOS}_${TARGETARCH}.zip" && \
           unzip -o -d /usr/bin /tmp/terraform.zip && \
           chmod +x /usr/bin/terraform && \
           rm /tmp/terraform.zip && \
           terraform version; then \
            echo "Terraform installed successfully" && \
            break; \
        fi; \
        echo "Attempt $i failed, retrying in 5 seconds..." && \
        if [ $i -eq 3 ]; then \
            echo "Failed to install Terraform after 3 attempts" && \
            exit 1; \
        fi; \
        sleep 5; \
    done&& \
    # Install tfupdate with retries
    for i in {1..3}; do \
        if [ "${TARGETARCH}" = "amd64" ]; then \
            curl -sSL -o tfupdate.tar.gz https://github.com/minamijoyo/tfupdate/releases/download/v${versionTfupdate}/tfupdate_${versionTfupdate}_linux_amd64.tar.gz && \
            tar -xf tfupdate.tar.gz tfupdate && \
            install tfupdate /usr/local/bin && \
            rm tfupdate.tar.gz tfupdate; \
        else \
            curl -sSL -o tfupdate.tar.gz https://github.com/minamijoyo/tfupdate/releases/download/v${versionTfupdate}/tfupdate_${versionTfupdate}_linux_${TARGETARCH}.tar.gz && \
            tar -xf tfupdate.tar.gz tfupdate && \
            install tfupdate /usr/local/bin && \
            rm tfupdate.tar.gz tfupdate; \
        fi && \
        tfupdate --version || true && break; \
        if [ $i -eq 3 ]; then exit 1; fi; \
        sleep 5; \
    done && \
    # Install terraform-docs with retries
    for i in {1..3}; do \
        if curl -sSL -o /tmp/terraform-docs.tar.gz https://github.com/terraform-docs/terraform-docs/releases/download/v${versionTerraformDocs}/terraform-docs-v${versionTerraformDocs}-${TARGETOS}-${TARGETARCH}.tar.gz && \
           tar -zxf /tmp/terraform-docs.tar.gz --directory=/usr/bin && \
           chmod +x /usr/bin/terraform-docs; then \
            terraform-docs --version || true && break; \
        fi; \
        if [ $i -eq 3 ]; then exit 1; fi; \
        sleep 5; \
    done && \
    # Install PowerShell with retries
    for i in {1..3}; do \
        if [ "${TARGETARCH}" = "amd64" ]; then \
            if curl -L -o /tmp/powershell.tar.gz https://github.com/PowerShell/PowerShell/releases/download/v${versionPowershell}/powershell-${versionPowershell}-${TARGETOS}-x64.tar.gz && \
               mkdir -p /opt/microsoft/powershell/7 && \
               tar zxf /tmp/powershell.tar.gz -C /opt/microsoft/powershell/7 && \
               chmod +x /opt/microsoft/powershell/7/pwsh && \
               ln -s /opt/microsoft/powershell/7/pwsh /usr/bin/pwsh; then \
                pwsh --version || true && break; \
            fi; \
        else \
            if curl -L -o /tmp/powershell.tar.gz https://github.com/PowerShell/PowerShell/releases/download/v${versionPowershell}/powershell-${versionPowershell}-${TARGETOS}-${TARGETARCH}.tar.gz && \
               mkdir -p /opt/microsoft/powershell/7 && \
               tar zxf /tmp/powershell.tar.gz -C /opt/microsoft/powershell/7 && \
               chmod +x /opt/microsoft/powershell/7/pwsh && \
               ln -s /opt/microsoft/powershell/7/pwsh /usr/bin/pwsh; then \
                pwsh --version || true && break; \
            fi; \
        fi; \
        if [ $i -eq 3 ]; then exit 1; fi; \
        sleep 5; \
    done && \
    # Install Packer with retries
    for i in {1..3}; do \
        if curl -sSL -o /tmp/packer.zip https://releases.hashicorp.com/packer/${versionPacker}/packer_${versionPacker}_${TARGETOS}_${TARGETARCH}.zip && \
           unzip -d /usr/bin /tmp/packer.zip && \
           chmod +x /usr/bin/packer; then \
            packer version || true && break; \
        fi; \
        if [ $i -eq 3 ]; then exit 1; fi; \
        sleep 5; \
    done && \
    # Install Kubelogin with retries
    for i in {1..3}; do \
        if curl -sSL -o /tmp/kubelogin.zip https://github.com/Azure/kubelogin/releases/download/v${versionKubelogin}/kubelogin-${TARGETOS}-${TARGETARCH}.zip && \
           unzip -d /usr/ /tmp/kubelogin.zip && \
           chmod +x /usr/bin/linux_${TARGETARCH}/kubelogin; then \
            /usr/bin/linux_${TARGETARCH}/kubelogin version || true && break; \
        fi; \
        if [ $i -eq 3 ]; then exit 1; fi; \
        sleep 5; \
    done && \
    # Install Vault with retries
    for i in {1..3}; do \
        if curl -sSL -o /tmp/vault.zip https://releases.hashicorp.com/vault/${versionVault}/vault_${versionVault}_${TARGETOS}_${TARGETARCH}.zip && \
           unzip -o -d /usr/bin /tmp/vault.zip && \
           chmod +x /usr/bin/vault && \
           setcap cap_ipc_lock=-ep /usr/bin/vault; then \
            vault version || true && break; \
        fi; \
        if [ $i -eq 3 ]; then exit 1; fi; \
        sleep 5; \
    done && \
    # Install tflint with retries
    for i in {1..3}; do \
        if curl -sSL -o /tmp/tflint.zip https://github.com/terraform-linters/tflint/releases/latest/download/tflint_${TARGETOS}_${TARGETARCH}.zip && \
           unzip -d /usr/bin /tmp/tflint.zip && \
           chmod +x /usr/bin/tflint; then \
            tflint --version || true && break; \
        fi; \
        if [ $i -eq 3 ]; then exit 1; fi; \
        sleep 5; \
    done && \
    # Install terrascan with retries
    for i in {1..3}; do \
        if [ "${TARGETARCH}" = "amd64" ]; then \
            curl -sSL -o terrascan.tar.gz https://github.com/tenable/terrascan/releases/download/v${versionTerrascan}/terrascan_${versionTerrascan}_Linux_x86_64.tar.gz; \
        else \
            curl -sSL -o terrascan.tar.gz https://github.com/tenable/terrascan/releases/download/v${versionTerrascan}/terrascan_${versionTerrascan}_Linux_${TARGETARCH}.tar.gz; \
        fi && \
        tar -xf terrascan.tar.gz terrascan && \
        install terrascan /usr/local/bin && \
        rm terrascan.tar.gz terrascan && \
        terrascan version || true && break; \
        if [ $i -eq 3 ]; then exit 1; fi; \
        sleep 5; \
    done && \
    # Install tfsec with retries
    for i in {1..3}; do \
        if curl -sSL -o /bin/tfsec https://github.com/tfsec/tfsec/releases/latest/download/tfsec-${TARGETOS}-${TARGETARCH} && \
           chmod +x /bin/tfsec; then \
            tfsec --version || true && break; \
        fi; \
        if [ $i -eq 3 ]; then exit 1; fi; \
        sleep 5; \
    done && \
    # Install tflint-ruleset-azurerm with retries
    for i in {1..3}; do \
        if curl -sSL -o /tmp/tflint-ruleset-azurerm.zip https://github.com/terraform-linters/tflint-ruleset-azurerm/releases/latest/download/tflint-ruleset-azurerm_${TARGETOS}_${TARGETARCH}.zip && \
           mkdir -p /home/${USERNAME}/.tflint.d/plugins /home/${USERNAME}/.tflint.d/config && \
           echo "plugin \"azurerm\" {\n    enabled = true\n}" > /home/${USERNAME}/.tflint.d/config/.tflint.hcl && \
           unzip -d /home/${USERNAME}/.tflint.d/plugins /tmp/tflint-ruleset-azurerm.zip; then \
            break; \
        fi; \
        if [ $i -eq 3 ]; then exit 1; fi; \
        sleep 5; \
    done

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

# Configure shell with retries and improved verification
RUN set -ex && \
    for i in {1..3}; do \
        echo "Attempt $i: Configuring shell..." && \
        if mkdir -p /commandhistory && \
           touch /commandhistory/.bash_history && \
           chown -R ${USERNAME} /commandhistory && \
           echo "set -o history" >> "/home/${USERNAME}/.bashrc" && \
           echo "export HISTCONTROL=ignoredups:erasedups" >> "/home/${USERNAME}/.bashrc" && \
           echo 'PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND$'\n'}history -a; history -c; history -r"' >> "/home/${USERNAME}/.bashrc" && \
           echo "[ -f /tf/rover/.kubectl_aliases ] && source /tf/rover/.kubectl_aliases" >> "/home/${USERNAME}/.bashrc" && \
           echo 'alias watch="watch "' >> "/home/${USERNAME}/.bashrc" && \
           test -f "/home/${USERNAME}/.bashrc"; then \
            echo "Shell configuration completed successfully" && \
            break; \
        fi; \
        echo "Attempt $i failed, retrying in 5 seconds..." && \
        if [ $i -eq 3 ]; then \
            echo "Failed to configure shell after 3 attempts" && \
            exit 1; \
        fi; \
        sleep 5; \
    done

# Copy rover scripts with retries and verification
COPY ./scripts/rover.sh ./scripts/tfstate.sh ./scripts/functions.sh \
     ./scripts/remote.sh ./scripts/parse_command.sh ./scripts/banner.sh \
     ./scripts/clone.sh ./scripts/walkthrough.sh ./scripts/sshd.sh \
     ./scripts/backend.hcl.tf ./scripts/backend.azurerm.tf ./scripts/ci.sh \
     ./scripts/cd.sh ./scripts/task.sh ./scripts/symphony_yaml.sh \
     ./scripts/test_runner.sh ./scripts/
COPY ./scripts/ci_tasks/* ./scripts/ci_tasks/
COPY ./scripts/lib/* ./scripts/lib/
COPY ./scripts/tfcloud/* ./scripts/tfcloud/

RUN set -ex && \
    for i in {1..3}; do \
        echo "Attempt $i: Setting up rover scripts..." && \
        if chmod +x /tf/rover/scripts/*.sh && \
           chown -R ${USERNAME}:${USERNAME} /tf/rover/scripts && \
           test -x /tf/rover/scripts/rover.sh; then \
            echo "Rover scripts setup completed successfully" && \
            break; \
        fi; \
        echo "Attempt $i failed, retrying in 5 seconds..." && \
        if [ $i -eq 3 ]; then \
            echo "Failed to set up rover scripts after 3 attempts" && \
            exit 1; \
        fi; \
        sleep 5; \
    done

# Clean up with retries and improved verification
RUN set -ex && \
    for i in {1..3}; do \
        echo "Attempt $i: Cleaning up..." && \
        if apt-get remove -y \
            gcc \
            python3-dev \
            apt-utils && \
           apt-get autoremove -y && \
           apt-get clean && \
           rm -rf /tmp/* && \
           rm -rf /var/lib/apt/lists/* && \
           find . | grep -E "(__pycache__|\.pyc|\.pyo$)" | xargs rm -rf; then \
            echo "Cleanup completed successfully" && \
            break; \
        fi; \
        echo "Attempt $i failed, retrying in 5 seconds..." && \
        if [ $i -eq 3 ]; then \
            echo "Failed to clean up after 3 attempts" && \
            exit 1; \
        fi; \
        sleep 5; \
    done
