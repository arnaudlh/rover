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

RUN mkdir -p /home/${USERNAME}/agent && \
    cd /home/${USERNAME}/agent && \
    DEBIAN_FRONTEND=noninteractive sudo apt-get update && \
    DEBIAN_FRONTEND=noninteractive sudo apt-get install -y unzip && \
    if [ "${TARGETARCH}" = "amd64" ]; then \
        curl -L -o /tmp/tfc-agent.zip https://releases.hashicorp.com/tfc-agent/${versionTfc}/tfc-agent_${versionTfc}_linux_amd64.zip; \
    else \
        curl -L -o /tmp/tfc-agent.zip https://releases.hashicorp.com/tfc-agent/${versionTfc}/tfc-agent_${versionTfc}_linux_arm64.zip; \
    fi && \
    sudo mkdir -p /usr/local/bin && \
    sudo unzip -o -d /usr/local/bin /tmp/tfc-agent.zip && \
    rm /tmp/tfc-agent.zip && \
    sudo chmod +x /usr/local/bin/tfc-agent /usr/local/bin/tfc-agent-core && \
    mkdir -p ${TFC_AGENT_DATA_DIR:-/home/${USERNAME}/agent/data} && \
    sudo chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}/agent

COPY agents/tfc/login.sh ${TFC_AGENT_DATA_DIR}/hooks/terraform-pre-plan
COPY agents/tfc/login.sh ${TFC_AGENT_DATA_DIR}/hooks/terraform-pre-apply
COPY agents/tfc/logout.sh ${TFC_AGENT_DATA_DIR}/hooks/terraform-post-plan
COPY agents/tfc/logout.sh ${TFC_AGENT_DATA_DIR}/hooks/terraform-post-apply

RUN chmod +x ${TFC_AGENT_DATA_DIR}/hooks/* && \
    chown -R ${USERNAME}:${USERNAME} ${TFC_AGENT_DATA_DIR}

ENTRYPOINT ["/usr/bin/tfc-agent"]
