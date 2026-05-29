# Base image: Ubuntu with Terraform + Kerberos/NTLM support
# Purpose: Container runners with WinRM and Kerberos support for Windows infrastructure automation
# Registry: ghcr.io/lakeviewloanservicing/base-images/spacelift-runner
#
# Ubuntu provides reliable access to build tools and Kerberos dependencies.
# Includes Terraform, Ansible, and pywinrm[kerberos] for complete Windows management.

FROM ubuntu:24.04

LABEL org.opencontainers.image.source="https://github.com/lakeviewloanservicing/container-base-images"
LABEL org.opencontainers.image.description="Terraform runner with WinRM, Kerberos, and Lakeview enterprise DPI certificates"
LABEL org.opencontainers.image.vendor="Lakeview Loan Servicing"

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
        ssh \
        libssl-dev \
        libkrb5-dev \
        krb5-user \
        ca-certificates \
        curl \
        git && \
    pip3 install --no-cache-dir --break-system-packages \
        ansible \
        ansible ansible-runner \
        pywinrm[kerberos] && \
    apt-get purge -y \
        build-essential \
        python3-dev && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Add enterprise certificates and update CA trust
COPY certs/*.crt /usr/local/share/ca-certificates/
RUN update-ca-certificates

# Set certificate trust environment variables
ENV SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt \
    REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt \
    CURL_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt \
    PIP_CERT=/etc/ssl/certs/ca-certificates.crt

# Kerberos setup script for runtime multi-domain krb5.conf generation
# Call via before_init hook or manually: krb5-setup.sh
COPY scripts/krb5-setup.sh /usr/local/bin/krb5-setup.sh
RUN chmod +x /usr/local/bin/krb5-setup.sh

# WinRM auth validation script for NTLM/Kerberos smoke tests
COPY scripts/winrm-auth-test.sh /usr/local/bin/winrm-auth-test.sh
RUN chmod +x /usr/local/bin/winrm-auth-test.sh

# Switch to spacelift user
USER spacelift
