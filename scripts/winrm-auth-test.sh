#!/bin/sh
# winrm-auth-test.sh — Validate NTLM/Kerberos WinRM connectivity from this container.

set -eu

WINRM_HOST="${WINRM_HOST:-}"
WINRM_PORT="${WINRM_PORT:-5986}"
WINRM_SCHEME="${WINRM_SCHEME:-https}"
WINRM_PATH="${WINRM_PATH:-wsman}"
WINRM_TRANSPORT="${WINRM_TRANSPORT:-ntlm}"
WINRM_USERNAME="${WINRM_USERNAME:-}"
WINRM_PASSWORD="${WINRM_PASSWORD:-}"
WINRM_VALIDATE_CERTS="${WINRM_VALIDATE_CERTS:-false}"
WINRM_OPERATION_TIMEOUT_SEC="${WINRM_OPERATION_TIMEOUT_SEC:-30}"
WINRM_READ_TIMEOUT_SEC="${WINRM_READ_TIMEOUT_SEC:-60}"
WINRM_TEST_COMMAND="${WINRM_TEST_COMMAND:-whoami}"

if [ -z "$WINRM_HOST" ]; then
    echo "winrm-auth-test: WINRM_HOST is required" >&2
    exit 2
fi

case "$WINRM_TRANSPORT" in
    ntlm|kerberos)
        ;;
    *)
        echo "winrm-auth-test: WINRM_TRANSPORT must be ntlm or kerberos" >&2
        exit 2
        ;;
esac

if [ "$WINRM_TRANSPORT" = "ntlm" ] && [ -z "$WINRM_USERNAME" -o -z "$WINRM_PASSWORD" ]; then
    echo "winrm-auth-test: NTLM requires WINRM_USERNAME and WINRM_PASSWORD" >&2
    exit 2
fi

WINRM_ENDPOINT="${WINRM_SCHEME}://${WINRM_HOST}:${WINRM_PORT}/${WINRM_PATH}"

export WINRM_ENDPOINT
export WINRM_TRANSPORT
export WINRM_USERNAME
export WINRM_PASSWORD
export WINRM_VALIDATE_CERTS
export WINRM_OPERATION_TIMEOUT_SEC
export WINRM_READ_TIMEOUT_SEC
export WINRM_TEST_COMMAND

python3 - <<'PY'
import os
import shlex
import sys

import winrm


def as_bool(value: str) -> bool:
    return value.strip().lower() in {"1", "true", "yes", "y", "on"}


endpoint = os.environ["WINRM_ENDPOINT"]
transport = os.environ["WINRM_TRANSPORT"].strip().lower()
username = os.environ.get("WINRM_USERNAME", "")
password = os.environ.get("WINRM_PASSWORD", "")
validate_certs = as_bool(os.environ.get("WINRM_VALIDATE_CERTS", "false"))
operation_timeout_sec = int(os.environ.get("WINRM_OPERATION_TIMEOUT_SEC", "30"))
read_timeout_sec = int(os.environ.get("WINRM_READ_TIMEOUT_SEC", "60"))
test_command = os.environ.get("WINRM_TEST_COMMAND", "whoami")

server_cert_validation = "validate" if validate_certs else "ignore"

print(f"winrm-auth-test: endpoint={endpoint}")
print(f"winrm-auth-test: transport={transport}")
print(f"winrm-auth-test: server_cert_validation={server_cert_validation}")

try:
    if username or password:
        session = winrm.Session(
            endpoint,
            auth=(username, password),
            transport=transport,
            server_cert_validation=server_cert_validation,
            operation_timeout_sec=operation_timeout_sec,
            read_timeout_sec=read_timeout_sec,
        )
    else:
        # Kerberos can use the local credential cache when no explicit username/password are provided.
        session = winrm.Session(
            endpoint,
            transport=transport,
            server_cert_validation=server_cert_validation,
            operation_timeout_sec=operation_timeout_sec,
            read_timeout_sec=read_timeout_sec,
        )
except TypeError:
    # Compatibility path for pywinrm versions that require the auth tuple argument.
    session = winrm.Session(
        endpoint,
        auth=(username, password),
        transport=transport,
        server_cert_validation=server_cert_validation,
        operation_timeout_sec=operation_timeout_sec,
        read_timeout_sec=read_timeout_sec,
    )

try:
    command_parts = shlex.split(test_command)
    if not command_parts:
        raise ValueError("WINRM_TEST_COMMAND is empty")

    command = command_parts[0]
    args = command_parts[1:]
    result = session.run_cmd(command, args)

    stdout = (result.std_out or b"").decode(errors="replace").strip()
    stderr = (result.std_err or b"").decode(errors="replace").strip()

    print(f"winrm-auth-test: status_code={result.status_code}")
    if stdout:
        print("winrm-auth-test: stdout")
        print(stdout)
    if stderr:
        print("winrm-auth-test: stderr", file=sys.stderr)
        print(stderr, file=sys.stderr)

    if result.status_code != 0:
        raise RuntimeError(f"remote command failed with exit code {result.status_code}")

    print("winrm-auth-test: authentication and command execution succeeded")
except Exception as exc:
    print(f"winrm-auth-test: FAILED: {exc}", file=sys.stderr)
    sys.exit(1)
PY
