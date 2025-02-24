FROM rover:local

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

RUN mkdir /home/${USERNAME}/agent && \
    cd /home/${USERNAME}/agent && \
    if [ "${TARGETARCH}" = "amd64" ]; then \
        curl -L -o /tmp/agent_package.tar.gz https://vstsagentpackage.azureedge.net/agent/${versionAzdo}/vsts-agent-linux-x64-${versionAzdo}.tar.gz; \
    else \
        curl -L -o /tmp/agent_package.tar.gz https://vstsagentpackage.azureedge.net/agent/${versionAzdo}/vsts-agent-linux-arm64-${versionAzdo}.tar.gz; \
    fi && \
    tar zxf /tmp/agent_package.tar.gz && \
    rm /tmp/agent_package.tar.gz

COPY ./agents/azure_devops/azdo.sh /home/${USERNAME}/agent/
RUN chmod +x /home/${USERNAME}/agent/azdo.sh

ENTRYPOINT ["/home/vscode/agent/azdo.sh"]
