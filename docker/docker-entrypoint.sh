#!/bin/sh
set -eu

if [ -n "${ODOOD_OPT_ADMIN_PASSWD_FILE:-}" ]; then
    if [ -n "${ODOOD_OPT_ADMIN_PASSWD:-}" ]; then
        echo "Set either ODOOD_OPT_ADMIN_PASSWD or ODOOD_OPT_ADMIN_PASSWD_FILE, not both." >&2
        exit 1
    fi
    if [ ! -r "$ODOOD_OPT_ADMIN_PASSWD_FILE" ]; then
        echo "Odoo master-password file is missing or unreadable." >&2
        exit 1
    fi

    ODOOD_OPT_ADMIN_PASSWD=$(cat "$ODOOD_OPT_ADMIN_PASSWD_FILE")
    export ODOOD_OPT_ADMIN_PASSWD
    unset ODOOD_OPT_ADMIN_PASSWD_FILE
fi

if [ -z "${ODOOD_OPT_ADMIN_PASSWD:-}" ]; then
    echo "Set ODOOD_OPT_ADMIN_PASSWD or mount a secret and set ODOOD_OPT_ADMIN_PASSWD_FILE." >&2
    exit 1
fi

exec "$@"
