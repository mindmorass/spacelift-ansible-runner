FROM public.ecr.aws/spacelift/runner-terraform:latest

USER root

RUN apk add --no-cache \
        docker-cli \
        python3 \
        py3-pip \
        krb5 \
        libffi && \
    apk add --no-cache --virtual .build-deps \
        krb5-dev \
        gcc \
        musl-dev \
        python3-dev \
        libffi-dev && \
    pip3 install --no-cache-dir --break-system-packages \
        ansible \
        pywinrm[kerberos] && \
    apk del .build-deps

ENV SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
ENV REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
ENV CURL_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
ENV PIP_CERT=/etc/ssl/certs/ca-certificates.crt

USER spacelift
