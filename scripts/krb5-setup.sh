#!/bin/sh
# krb5-setup.sh — Generate /etc/krb5.conf from environment variables
#
# Usage:
#   export KRB5_REALMS="CORP.EXAMPLE.COM,DEV.EXAMPLE.COM"
#   export KRB5_DEFAULT_REALM="CORP.EXAMPLE.COM"
#   export KRB5_KDC_CORP_EXAMPLE_COM="dc01.corp.example.com,dc02.corp.example.com"
#   export KRB5_KDC_DEV_EXAMPLE_COM="dc01.dev.example.com"
#   ./krb5-setup.sh
#
# POSIX sh for Alpine compatibility (no bash required).

set -eu

KRB5_CONF="${KRB5_CONF_PATH:-/etc/krb5.conf}"
KRB5_REALMS="${KRB5_REALMS:-}"
KRB5_DEFAULT_REALM="${KRB5_DEFAULT_REALM:-}"

if [ -z "$KRB5_REALMS" ]; then
    echo "krb5-setup: KRB5_REALMS is not set, skipping krb5.conf generation" >&2
    exit 0
fi

# Use first realm as default if not explicitly set
if [ -z "$KRB5_DEFAULT_REALM" ]; then
    KRB5_DEFAULT_REALM="$(echo "$KRB5_REALMS" | cut -d',' -f1)"
fi

# Start building krb5.conf
cat > "$KRB5_CONF" <<EOF
[libdefaults]
    default_realm = ${KRB5_DEFAULT_REALM}
    dns_lookup_realm = false
    dns_lookup_kdc = false
    ticket_lifetime = 24h
    renew_lifetime = 7d
    forwardable = true
    rdns = false

[realms]
EOF

# Process each realm
OLD_IFS="$IFS"
IFS=','
for realm in $KRB5_REALMS; do
    # Trim whitespace
    realm="$(echo "$realm" | tr -d ' ')"

    # Convert realm to env var name: CORP.LAKEVIEW.COM -> CORP_LAKEVIEW_COM
    realm_var="KRB5_KDC_$(echo "$realm" | tr '.' '_')"

    # Read KDC list from the corresponding env var
    kdcs="$(eval echo "\${${realm_var}:-}")"

    if [ -z "$kdcs" ]; then
        echo "krb5-setup: WARNING: No KDCs defined for realm ${realm} (set ${realm_var})" >&2
        continue
    fi

    # Write realm block
    cat >> "$KRB5_CONF" <<EOF
    ${realm} = {
EOF

    IFS=','
    for kdc in $kdcs; do
        kdc="$(echo "$kdc" | tr -d ' ')"
        cat >> "$KRB5_CONF" <<EOF
        kdc = ${kdc}
EOF
    done

    # Use first KDC as admin server
    admin_server="$(echo "$kdcs" | cut -d',' -f1 | tr -d ' ')"
    cat >> "$KRB5_CONF" <<EOF
        admin_server = ${admin_server}
    }
EOF
done
IFS="$OLD_IFS"

# Build [domain_realm] section — map lowercase domain and .domain to realm
cat >> "$KRB5_CONF" <<EOF

[domain_realm]
EOF

IFS=','
for realm in $KRB5_REALMS; do
    realm="$(echo "$realm" | tr -d ' ')"
    domain="$(echo "$realm" | tr '[:upper:]' '[:lower:]')"
    cat >> "$KRB5_CONF" <<EOF
    .${domain} = ${realm}
    ${domain} = ${realm}
EOF
done
IFS="$OLD_IFS"

echo "krb5-setup: Generated ${KRB5_CONF} with realms: ${KRB5_REALMS}"

# Optionally run kinit if credentials are provided
KRB5_PRINCIPAL="${KRB5_PRINCIPAL:-}"
KRB5_KEYTAB="${KRB5_KEYTAB:-}"
KRB5_PASSWORD="${KRB5_PASSWORD:-}"

if [ -n "$KRB5_PRINCIPAL" ] && [ -n "$KRB5_KEYTAB" ]; then
    echo "krb5-setup: Authenticating ${KRB5_PRINCIPAL} via keytab"
    kinit -kt "$KRB5_KEYTAB" "$KRB5_PRINCIPAL"
    klist
elif [ -n "$KRB5_PRINCIPAL" ] && [ -n "$KRB5_PASSWORD" ]; then
    echo "krb5-setup: Authenticating ${KRB5_PRINCIPAL} via password"
    echo "$KRB5_PASSWORD" | kinit "$KRB5_PRINCIPAL"
    klist
fi
