#! /usr/bin/env bash

HELPTXT=$(cat <<"EOF"
Usage:
    ./update-dodns.sh [--help] --domain=<domain_name> --hostname=<hostname>
                        --accesstoken=<do_api_key>

Update a Digital Ocean DNS record with your external IP address.
OPTIONS
    --help
        Show this output
    --domain=<domain_name>
        The name of the domain where the A record lives that will be updated.
    --hostname=<hostname>
        The name of the hostname you wish to update.
    --accesstoken=<do_api_key>
        Provide your docker API key here.
EOF
)

SHOW_HELP=0
DOMAIN=""
HOSTNAME=""
ACCESSTOKEN=""

while [ $# -gt 0 ]; do
    case "$1" in
        --help)
            SHOW_HELP=1
            ;;
        --domain=*)
            DOMAIN="${1#*=}"
            ;;
        --hostname=*)
            HOSTNAME="${1#*=}"
            ;;
        --accesstoken=*)
            ACCESSTOKEN="${1#*=}"
            ;;
        *)
            SHOW_HELP=1
    esac
    shift
done

if [ $SHOW_HELP -eq 1 ]; then
    echo "$HELPTXT"
    exit 0
fi

doctl --access-token ${ACCESSTOKEN} compute domain records list ${DOMAIN} -o json > /tmp/digitalocean-dns.json

if [ $? -eq 1 ]; then
    printf "Error while loading records for \"${DOMAIN}\": %s" cat /tmp/digitalocean-dns.json | jq ".errors | .[] | .detail"
    exit 1
fi

DO_HOSTNAME_ID=$(cat /tmp/digitalocean-dns.json | jq ".[] | select(.name==\"${HOSTNAME}\") | .id")
DO_HOSTNAME_IP=$(cat /tmp/digitalocean-dns.json | jq ".[] | select(.name==\"${HOSTNAME}\") | .data" | sed -e 's/^"//' -e 's/"$//')

if [ -z "$DO_HOSTNAME_ID" ]; then
    echo "No record data found for ${HOSTNAME}.${DOMAIN}"
    exit 1
fi

CURRENT_IP=$(dig +short myip.opendns.com @resolver1.opendns.com)

if [ "$CURRENT_IP" == "$DO_HOSTNAME_IP" ]; then
    echo "Record data for ${HOSTNAME}.${DOMAIN} still contains ${CURRENT_IP}. No changes have been made."
else
    doctl --access-token ${ACCESSTOKEN} compute domain records update ${DOMAIN} --record-name ${HOSTNAME} --record-data ${CURRENT_IP} --record-id ${DO_HOSTNAME_ID} --output json > /tmp/digitalocean-dns.json

    if [ $? -eq 1 ]; then
        printf "Failed to update record for \"${HOSTNAME}.${DOMAIN}\": %s" cat /tmp/digitalocean-dns.json | jq ".errors | .[] | .detail"
        exit 1
    else
        echo "Record data for \"${HOSTNAME}.${DOMAIN}\" has been updated with ${CURRENT_IP}."
    fi
fi

exit 0
