ARG REGISTRY
ARG GITHUB_REPOSITORY
ARG GITHUB_SHA
ARG TARGETARCH

FROM ${REGISTRY}/${GITHUB_REPOSITORY}/rover:pr-${GITHUB_SHA}-${TARGETARCH}

ARG TARGETARCH
ARG TARGETOS
ARG USERNAME=vscode
ARG versionTfc

ENV TFC_AGENT_TOKEN="" \
    TFC_AGENT_NAME="" \
    TFC_ADDRESS="https://app.terraform.io" \
    TFC_AGENT_AUTO_UPDATE="disabled" \
    TFC_AGENT_SINGLE="false" \
    TFC_AGENT_DATA_DIR="/home/vscode/agent/.tfc-agent" \
    TFC_AGENT_LOG_JSON="false" \
    TFC_AGENT_LOG_LEVEL="info" \
    ROVER_RUNNER=true

USER root

USER root

RUN set -ex && \
    # Install required dependencies first
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        curl \
        unzip \
        ca-certificates \
        sudo && \
    # Create agent directory with proper permissions
    mkdir -p /home/${USERNAME}/agent && \
    cd /home/${USERNAME}/agent && \
    # Download and install agent with retries
    for i in {1..3}; do \
        echo "Attempt $i: Installing TFC agent..." && \
        if [ "${TARGETARCH}" = "amd64" ]; then \
            curl -L --retry 3 --retry-delay 5 -o /tmp/tfc-agent.zip https://releases.hashicorp.com/tfc-agent/${versionTfc}/tfc-agent_${versionTfc}_linux_amd64.zip; \
        else \
            curl -L --retry 3 --retry-delay 5 -o /tmp/tfc-agent.zip https://releases.hashicorp.com/tfc-agent/${versionTfc}/tfc-agent_${versionTfc}_linux_arm64.zip; \
        fi && \
        mkdir -p /usr/local/bin && \
        unzip -o -d /usr/local/bin /tmp/tfc-agent.zip && \
        rm /tmp/tfc-agent.zip && \
        chmod +x /usr/local/bin/tfc-agent /usr/local/bin/tfc-agent-core && \
        mkdir -p ${TFC_AGENT_DATA_DIR:-/home/${USERNAME}/agent/data} && \
        chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}/agent && \
        chmod -R 755 /home/${USERNAME}/agent && \
        echo "TFC agent installed successfully" && \
        break; \
        echo "Attempt $i failed, retrying in 5 seconds..." && \
        if [ $i -eq 3 ]; then \
            echo "Failed to install TFC agent after 3 attempts" && \
            exit 1; \
        fi; \
        sleep 5; \
    done && \
    # Cleanup
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

USER ${USERNAME}

USER ${USERNAME}

COPY agents/tfc/login.sh ${TFC_AGENT_DATA_DIR}/hooks/terraform-pre-plan
COPY agents/tfc/login.sh ${TFC_AGENT_DATA_DIR}/hooks/terraform-pre-apply
COPY agents/tfc/logout.sh ${TFC_AGENT_DATA_DIR}/hooks/terraform-post-plan
COPY agents/tfc/logout.sh ${TFC_AGENT_DATA_DIR}/hooks/terraform-post-apply

USER root
RUN mkdir -p ${TFC_AGENT_DATA_DIR}/hooks && \
    chmod -R 755 ${TFC_AGENT_DATA_DIR} && \
    chown -R ${USERNAME}:${USERNAME} ${TFC_AGENT_DATA_DIR} && \
    chmod +x ${TFC_AGENT_DATA_DIR}/hooks/*

USER ${USERNAME}

ENTRYPOINT ["/usr/bin/tfc-agent"]
