ARG REGISTRY
ARG GITHUB_REPOSITORY
ARG GITHUB_SHA
ARG TARGETARCH

FROM ${REGISTRY}/${GITHUB_REPOSITORY}/rover:pr-${GITHUB_SHA}-${TARGETARCH}

ARG TARGETARCH
ARG TARGETOS
ARG USERNAME=vscode
ARG versionGithubRunner

ENV AGENT_NAME="" \
    AGENT_TOKEN="" \
    LABELS="" \
    MSI_ID="" \
    PATH="${PATH}:/home/${USERNAME}/.dotnet" \
    ROVER_RUNNER=true \
    URL="" \
    WORK="_work"

RUN mkdir -p /home/${USERNAME}/agent && \
    cd /home/${USERNAME}/agent && \
    if [ "${TARGETARCH}" = "amd64" ]; then \
        curl -sSL -o /tmp/github-runner.tar.gz https://github.com/actions/runner/releases/download/v${versionGithubRunner}/actions-runner-linux-x64-${versionGithubRunner}.tar.gz; \
    else \
        curl -sSL -o /tmp/github-runner.tar.gz https://github.com/actions/runner/releases/download/v${versionGithubRunner}/actions-runner-linux-arm64-${versionGithubRunner}.tar.gz; \
    fi && \
    tar xzf /tmp/github-runner.tar.gz && \
    rm /tmp/github-runner.tar.gz && \
    sudo DEBIAN_FRONTEND=noninteractive ./bin/installdependencies.sh && \
    sudo chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}/agent

COPY ./agents/github/github.sh /home/${USERNAME}/agent/
RUN chmod +x /home/${USERNAME}/agent/github.sh

ENTRYPOINT ["/home/vscode/agent/github.sh"]
