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

USER root

RUN set -ex && \
    for i in {1..3}; do \
        echo "Attempt $i: Installing Azure DevOps agent..." && \
        if mkdir -p /home/${USERNAME}/agent && \
           cd /home/${USERNAME}/agent && \
           if [ "${TARGETARCH}" = "amd64" ]; then \
               curl -L --retry 3 --retry-delay 5 -o /tmp/agent_package.tar.gz https://vstsagentpackage.azureedge.net/agent/${versionAzdo}/vsts-agent-linux-x64-${versionAzdo}.tar.gz; \
           else \
               curl -L --retry 3 --retry-delay 5 -o /tmp/agent_package.tar.gz https://vstsagentpackage.azureedge.net/agent/${versionAzdo}/vsts-agent-linux-arm64-${versionAzdo}.tar.gz; \
           fi && \
           tar xzf /tmp/agent_package.tar.gz && \
           rm /tmp/agent_package.tar.gz && \
           DEBIAN_FRONTEND=noninteractive ./bin/installdependencies.sh && \
           chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}/agent && \
           chmod -R 755 /home/${USERNAME}/agent; then \
            echo "Azure DevOps agent installed successfully" && \
            break; \
        fi; \
        echo "Attempt $i failed, retrying in 5 seconds..." && \
        if [ $i -eq 3 ]; then \
            echo "Failed to install Azure DevOps agent after 3 attempts" && \
            exit 1; \
        fi; \
        sleep 5; \
    done

USER ${USERNAME}

COPY ./agents/azure_devops/azdo.sh /home/${USERNAME}/agent/
USER root
RUN chmod +x /home/${USERNAME}/agent/azdo.sh && \
    chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}/agent

USER ${USERNAME}

ENTRYPOINT ["/home/vscode/agent/azdo.sh"]
