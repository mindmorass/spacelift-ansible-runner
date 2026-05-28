FROM ubuntu:24.04

# Switch to root for system changes
USER root

# Create spacelift user
RUN groupadd -r spacelift && useradd -r -g spacelift spacelift

# Install system dependencies and Python packages for WinRM testing
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        sshpass \
        python3 \
        python3-pip \
        python3-dev \
        build-essential \
        libffi-dev \
        libssl-dev \
        libkrb5-dev \
        krb5-user \
        ca-certificates \
        curl \
        git && \
    pip3 install --no-cache-dir --break-system-packages \
        ansible \
        pywinrm[kerberos] && \
    apt-get purge -y \
        build-essential \
        python3-dev && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
