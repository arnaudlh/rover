ARG REGISTRY
ARG GITHUB_REPOSITORY
ARG GITHUB_SHA
ARG TARGETARCH

FROM ${REGISTRY}/${GITHUB_REPOSITORY}/rover:pr-${GITHUB_SHA}-${TARGETARCH}

ARG TARGETARCH
ARG TARGETOS
ARG USERNAME=vscode
ARG versionAzdo

ENV AGENT_NAME="" \
    AGENT_TOKEN="" \
    LABELS="" \
    MSI_ID="" \
    ROVER_RUNNER=true \
    VSTS_AGENT_INPUT_URL="" \
    VSTS_AGENT_INPUT_AUTH="pat" \
    VSTS_AGENT_INPUT_TOKEN="" \
    VSTS_AGENT_INPUT_POOL=""

RUN mkdir -p /home/${USERNAME}/agent && \
    cd /home/${USERNAME}/agent && \
    if [ "${TARGETARCH}" = "amd64" ]; then \
        curl -L -o /tmp/agent_package.tar.gz https://vstsagentpackage.azureedge.net/agent/${versionAzdo}/vsts-agent-linux-x64-${versionAzdo}.tar.gz; \
    else \
        curl -L -o /tmp/agent_package.tar.gz https://vstsagentpackage.azureedge.net/agent/${versionAzdo}/vsts-agent-linux-arm64-${versionAzdo}.tar.gz; \
    fi && \
    tar xzf /tmp/agent_package.tar.gz && \
    rm /tmp/agent_package.tar.gz && \
    sudo DEBIAN_FRONTEND=noninteractive ./bin/installdependencies.sh && \
    sudo chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}/agent

COPY ./agents/azure_devops/azdo.sh /home/${USERNAME}/agent/
RUN chmod +x /home/${USERNAME}/agent/azdo.sh

ENTRYPOINT ["/home/vscode/agent/azdo.sh"]
