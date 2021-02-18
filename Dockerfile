FROM ubuntu:18.04

RUN apt update \
    && apt dist-upgrade -y \
    && apt install -y ca-certificates openssh-client qemu-user-static binfmt-support jq \
    wget curl iptables supervisor sudo \
    && rm -rf /var/lib/apt/list/*

ENV DOCKER_CHANNEL=stable \
    DOCKER_VERSION=19.03.15 \
    DOCKER_COMPOSE_VERSION=1.28.4 \
    DOCKER_BUILDX_VERSION=0.5.1 \
    DEBUG=false

RUN useradd -ms /bin/bash ubuntu && \
    usermod -aG sudo ubuntu && \
    echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# Docker installation
RUN set -eux; \
    \
    arch="$(uname --m)"; \
    case "$arch" in \
        # amd64
        x86_64) dockerArch='x86_64' ;; \
        # arm32v6
        armhf) dockerArch='armel' ;; \
        # arm32v7
        armv7) dockerArch='armhf' ;; \
        # arm64v8
        aarch64) dockerArch='aarch64' ;; \
        *) echo >&2 "error: unsupported architecture ($arch)"; exit 1 ;;\
    esac; \
    \
    if ! wget -O docker.tgz "https://download.docker.com/linux/static/${DOCKER_CHANNEL}/${dockerArch}/docker-${DOCKER_VERSION}.tgz"; then \
        echo >&2 "error: failed to download 'docker-${DOCKER_VERSION}' from '${DOCKER_CHANNEL}' for '${dockerArch}'"; \
        exit 1; \
    fi; \
    \
    tar --extract \
        --file docker.tgz \
        --strip-components 1 \
        --directory /usr/local/bin/ \
    ; \
    rm docker.tgz; \
    \
    dockerd --version; \
    docker --version

COPY modprobe startup.sh /usr/local/bin/
COPY supervisor/ /etc/supervisor/conf.d/
COPY logger.sh /opt/bash-utils/logger.sh

RUN chmod +x /usr/local/bin/startup.sh /usr/local/bin/modprobe
VOLUME /var/lib/docker

# Docker compose installation
RUN curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose \
    && chmod +x /usr/local/bin/docker-compose

USER ubuntu
WORKDIR /home/ubuntu

RUN mkdir -p /home/ubuntu/.docker/cli-plugins && curl -L "https://github.com/docker/buildx/releases/download/v${DOCKER_BUILDX_VERSION}/buildx-v${DOCKER_BUILDX_VERSION}.linux-amd64" -o /home/ubuntu/.docker/cli-plugins/docker-buildx \
    && chmod +x /home/ubuntu/.docker/cli-plugins/docker-buildx

ENTRYPOINT ["/usr/local/bin/startup.sh"]

CMD ["sh"]
