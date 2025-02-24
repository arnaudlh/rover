FROM rover:local

ARG TARGETARCH
ARG TARGETOS
ARG USERNAME=vscode

ENV AGENT_NAME="" \
    AGENT_TOKEN="" \
    AGENT_URL="" \
    LABELS="" \
    MSI_ID="" \
    REGISTER_PAUSED="false" \
    ROVER_RUNNER=true \
    WORK_FOLDER=""

RUN mkdir /home/${USERNAME}/agent && \
    cd /home/${USERNAME}/agent && \
    curl -L --output /usr/local/bin/gitlab-runner "https://gitlab-runner-downloads.s3.amazonaws.com/latest/binaries/gitlab-runner-${TARGETOS}-${TARGETARCH}" && \
    chmod +x /usr/local/bin/gitlab-runner && \
    gitlab-runner install --user=${USERNAME} --working-directory=/home/${USERNAME}/agent

COPY ./agents/gitlab/gitlab.sh /home/${USERNAME}/agent/
RUN chmod +x /home/${USERNAME}/agent/gitlab.sh

ENTRYPOINT ["/home/vscode/agent/gitlab.sh"]
