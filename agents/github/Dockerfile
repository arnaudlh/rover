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

RUN set -ex && \
    for i in {1..3}; do \
        echo "Attempt $i: Installing GitHub runner..." && \
        if mkdir -p /home/${USERNAME}/agent && \
           cd /home/${USERNAME}/agent && \
           if [ "${TARGETARCH}" = "amd64" ]; then \
               curl -sSL --retry 3 --retry-delay 5 -o /tmp/github-runner.tar.gz https://github.com/actions/runner/releases/download/v${versionGithubRunner}/actions-runner-linux-x64-${versionGithubRunner}.tar.gz; \
           else \
               curl -sSL --retry 3 --retry-delay 5 -o /tmp/github-runner.tar.gz https://github.com/actions/runner/releases/download/v${versionGithubRunner}/actions-runner-linux-arm64-${versionGithubRunner}.tar.gz; \
           fi && \
           tar xzf /tmp/github-runner.tar.gz && \
           rm /tmp/github-runner.tar.gz && \
           DEBIAN_FRONTEND=noninteractive ./bin/installdependencies.sh && \
           chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}/agent && \
           chmod -R 755 /home/${USERNAME}/agent; then \
            echo "GitHub runner installed successfully" && \
            break; \
        fi; \
        echo "Attempt $i failed, retrying in 5 seconds..." && \
        if [ $i -eq 3 ]; then \
            echo "Failed to install GitHub runner after 3 attempts" && \
            exit 1; \
        fi; \
        sleep 5; \
    done

COPY ./agents/github/github.sh /home/${USERNAME}/agent/
RUN chmod +x /home/${USERNAME}/agent/github.sh

ENTRYPOINT ["/home/vscode/agent/github.sh"]
