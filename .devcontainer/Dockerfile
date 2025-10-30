# syntax=docker/dockerfile:1
ARG VARIANT=3.12
FROM mcr.microsoft.com/devcontainers/python:${VARIANT}

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update -y \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        gpg \
        unzip \
        git \
        golang-go \
        make \
        dpkg \
    && rm -rf /var/lib/apt/lists/*

# Install 1Password CLI
RUN curl -sS https://downloads.1password.com/linux/keys/1password.asc | \
    gpg --dearmor --output /usr/share/keyrings/1password-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/$(dpkg --print-architecture) stable main" | \
    tee /etc/apt/sources.list.d/1password.list && \
    mkdir -p /etc/debsig/policies/AC2D62742012EA22/ && \
    curl -sS https://downloads.1password.com/linux/debian/debsig/1password.pol | \
    tee /etc/debsig/policies/AC2D62742012EA22/1password.pol && \
    mkdir -p /usr/share/debsig/keyrings/AC2D62742012EA22 && \
    curl -sS https://downloads.1password.com/linux/keys/1password.asc | \
    gpg --dearmor --output /usr/share/debsig/keyrings/AC2D62742012EA22/debsig.gpg && \
    apt-get update && \
    apt-get install -y --no-install-recommends 1password-cli && \
    rm -rf /var/lib/apt/lists/*

USER vscode

ENV PATH="/home/vscode/.local/bin:/home/vscode/go/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

RUN curl -LsSf https://astral.sh/uv/install.sh | sh \
    && go install github.com/google/yamlfmt/cmd/yamlfmt@latest \
    && go install mvdan.cc/sh/v3/cmd/shfmt@latest

USER root

ENV PATH="/home/vscode/.local/bin:/home/vscode/go/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
