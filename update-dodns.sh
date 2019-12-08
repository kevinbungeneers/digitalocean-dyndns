#!/usr/bin/env bash
#
# NAME
#    update-dodns - Update your DigitalOcean DNS records.
#
# USAGE
#    update-dodns --domain="example.com" --hostnames="subdomain1;subdomain2"
#                 --accesstoken="exampleAccessTokenc9090edc900663d750fee6030bd4"
#
# BUGS
#    https://github.com/kevinbungeneers/digitalocean-dyndns/issues
#
################################################################################

function usage() {
    while IFS= read -r line || [[ -n "$line" ]]
    do
        case "$line" in
            '#!'*)
                ;;
            ''|'##'*|[!#]*)
                exit "${1:-0}"
                ;;
            *)
                printf '%s\n' "${line:2}" >&2
                ;;
        esac
    done < "$0"
}

# Process parameters
domain=""
accesstoken=""
declare -a hostnames
while [[ -n "${1:-}" ]]
do
    case $1 in
        -h|--help)
            usage
            exit 0
            ;;
        --domain=*)
            domain="${1#*=}"
            ;;
        --hostnames=*)
            IFS=';' read -a hostnames <<< "${1#*=}"
            ;;
        --accesstoken=*)
            accesstoken="${1#*=}"
            ;;
    esac
    shift
done

# Load all records from a given domain
records=$(doctl --access-token "${accesstoken}" compute domain records list "${domain}" -o json)

if [ "$?" -eq 1 ]; then
    echo "Error while loading records for \"${domain}\": $(jq ".errors | .[] | .detail" <<< $records)"
    exit $?
fi

# Get our current external IP
current_ip=$(dig +short myip.opendns.com @resolver1.opendns.com)

# Update given records with external IP
for hostname in "${hostnames[@]}"
do
    hostname_id=$(echo $records | jq ".[] | select(.name==\"${hostname}\") | .id")
    hostname_ip=$(echo $records | jq -r ".[] | select(.name==\"${hostname}\") | .data")

    if [ -z "$hostname_id" ]; then
        echo "No record data found for \"${hostname}\", skipping"
        continue
    fi

    if [ "${current_ip}" == "${hostname_ip}" ]; then
        echo "Record data for \"${hostname}\" already contains \"${current_ip}\". Nothing to do."
    else
        result=$(doctl --access-token ${accesstoken} \
            compute domain records update ${domain} \
            --record-name ${hostname} \
            --record-data ${current_ip} \
            --record-id ${hostname_id} \
            --output json
        )

        if [ "$?" -gt 0 ]; then
            echo "Failed to update record data for \"${hostname}\" with \"${current_ip}\": $(jq ".errors | .[] | .detail" <<< $records)"
            exit_code=$?
        else
            echo "Record for \"${hostname}\" has been updated with \"${current_ip}\""
        fi
    fi
done

exit "${exit_code-0}"