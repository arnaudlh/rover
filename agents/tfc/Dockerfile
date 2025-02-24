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
    curl -L -o /tmp/tfc-agent.zip https://releases.hashicorp.com/tfc-agent/${versionTfc}/tfc-agent_${versionTfc}_linux_${TARGETARCH}.zip && \
    unzip -d /usr/bin /tmp/tfc-agent.zip && \
    rm /tmp/tfc-agent.zip && \
    chmod +x /usr/bin/tfc-agent /usr/bin/tfc-agent-core && \
    mkdir -p ${TFC_AGENT_DATA_DIR}

COPY agents/tfc/login.sh ${TFC_AGENT_DATA_DIR}/hooks/terraform-pre-plan
COPY agents/tfc/login.sh ${TFC_AGENT_DATA_DIR}/hooks/terraform-pre-apply
COPY agents/tfc/logout.sh ${TFC_AGENT_DATA_DIR}/hooks/terraform-post-plan
COPY agents/tfc/logout.sh ${TFC_AGENT_DATA_DIR}/hooks/terraform-post-apply

RUN chmod +x ${TFC_AGENT_DATA_DIR}/hooks/* && \
    chown -R ${USERNAME}:${USERNAME} ${TFC_AGENT_DATA_DIR}

ENTRYPOINT ["/usr/bin/tfc-agent"]
