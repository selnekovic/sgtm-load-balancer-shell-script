#!/bin/bash

# Created by Julius Selnekovic | Artisma
# The script is for custom domain mapping via Load Balancer in Cloud Run when deploying server-side GTM.
# v.1.0

# Constants
_URL_MAP="custom-domains-sgtm"
_IP_ADDRESS_NAME="cd-sgtm-global-ip"

# Prompt for domain input and ensure it's not empty
set_domain() {
    while true; do
        echo ""
        read -p "Enter subdomain you want to map (e.g., data.yourdomain.com): " domain
        if [[ -n "$domain" ]]; then
            _DOMAIN=${domain//./-}
            break
        else
            echo "⚠️  Subdomain cannot be empty. Please try again."
        fi
    done
}

# Prompt for backend service name and ensure it's not empty
set_service_name() {
    while true; do
        read -p "Enter Cloud Run backend service name (e.g., sgtm-server-eu-prod): " backend_service
        if [[ -n "$backend_service" ]]; then
            _BACKEND_SERVICE="${backend_service}"
            break
        else
            echo "⚠️  Service name cannot be empty. Please try again."
        fi
    done
}

# Prompt for region input and ensure it's not empty
set_region() {
    while true; do
        read -p "Enter region for your resources (e.g., europe-west4): " region
        if [[ -n "$region" ]]; then
            _REGION="$region"
            break
        else
            echo "⚠️  Region cannot be empty. Please try again."
        fi
    done
}


# Create global IP address
create_global_ip() {
    gcloud compute addresses create "${_IP_ADDRESS_NAME}" \
        --network-tier=PREMIUM \
        --ip-version=IPV4 \
        --global 
}

# Get created global IP address 
get_global_ip() {
    local ip=$(gcloud compute addresses describe "${_IP_ADDRESS_NAME}" \
            --format="value(address)" \
            --global)

    echo "$ip"
}

# Create SSL certificate
create_ssl_certificate() {
    echo ""
    echo "Creating SSL certificate..."
    gcloud compute ssl-certificates create cd-${_DOMAIN}-cert \
        --domains="${domain}" \
        --global
}

# Create NEG
create_network_endpoint_group() {
    echo ""
    echo "Creating NEG..."
    gcloud compute network-endpoint-groups create cd-${_DOMAIN}-neg \
        --region=${_REGION} \
        --network-endpoint-type=serverless \
        --cloud-run-service=${_BACKEND_SERVICE}
}

# Create backend service
create_backend_service() {
    echo ""
    echo "Creating backend service..."
    gcloud compute backend-services create cd-${_DOMAIN} \
        --load-balancing-scheme=EXTERNAL_MANAGED \
        --protocol=HTTPS \
        --port-name=http \
        --global
}

# Add NEG to backend service
add_backend_to_service() {
    echo ""
    gcloud compute backend-services add-backend cd-${_DOMAIN} \
        --global \
        --network-endpoint-group=cd-${_DOMAIN}-neg \
        --network-endpoint-group-region=${_REGION}
}

# Create URL map
create_url_map() {
    echo ""
    echo "Creating URL map..."
    gcloud compute url-maps create ${_URL_MAP} \
        --default-service=cd-${_DOMAIN}
}

# Add path matcher to URL map
add_path_matcher_to_url_map() {
    echo ""
    echo "Adding path matcher to URL map..."
    gcloud compute url-maps add-path-matcher ${_URL_MAP} \
        --path-matcher-name=${_DOMAIN} \
        --default-service=cd-${_DOMAIN} \
        --path-rules=/*=cd-${_DOMAIN} \
        --new-hosts=${domain}
}

# Create HTTPS proxy
create_https_proxy() {
    echo ""
    echo "Creating HTTPS proxy..."
    gcloud compute target-https-proxies create ${_URL_MAP}-proxy \
        --ssl-certificates=cd-${_DOMAIN}-cert \
        --url-map=custom-domains-sgtm
}

# Create forwarding rule with IP address
create_forwarding_rule() {
    echo ""
    echo "Creating forwarding rule..."
    local global_ip=$1
    gcloud compute forwarding-rules create ${_URL_MAP}-fwr \
        --load-balancing-scheme=EXTERNAL_MANAGED \
        --network-tier=PREMIUM \
        --address=${global_ip} \
        --target-https-proxy=${_URL_MAP}-proxy \
        --global \
        --ports=443
}

# Update HTTPS proxy with new certificate
update_https_proxy() {
    local proxy_name="custom-domains-sgtm-proxy"
    local new_cert="cd-${_DOMAIN}-cert"

    echo "Retrieving existing certificates from HTTPS proxy: $proxy_name..."

    existing_certs=$(gcloud compute target-https-proxies describe "$proxy_name" \
        --format="flattened(sslCertificates)")

    if [[ -z "$existing_certs" ]]; then
        echo "⚠️  No existing certificates found on the proxy."
        kill -INT $$
    else
        cleaned_certs=$(echo "$existing_certs" | sed 's|.*/||g' | paste -sd, -)
        all_certs="${cleaned_certs},${new_cert}"
    fi

    echo "Updating HTTPS proxy with certificates: $all_certs"

    gcloud compute target-https-proxies update "$proxy_name" \
        --ssl-certificates="$all_certs"
}

# Function: Create a full load balancer setup
create_load_balancer() {
    echo ""
    echo "Creating load balancer..."

    create_global_ip
    global_ip=$(get_global_ip)
    create_ssl_certificate
    create_network_endpoint_group
    create_backend_service
    add_backend_to_service
    create_url_map
    add_path_matcher_to_url_map
    create_https_proxy
    create_forwarding_rule "$global_ip"

    echo ""
    echo "✅  Creating finished"
    echo "Global IP address: $global_ip"
    echo "Add this IP address in your DNS records for domain: $domain"
}

# Function: Add a domain to an existing load balancer
add_domain_to_load_balancer() {
    echo ""
    echo "Adding domain to load balancer..."

    global_ip=$(get_global_ip)
    create_ssl_certificate
    create_network_endpoint_group
    create_backend_service
    add_backend_to_service
    add_path_matcher_to_url_map
    update_https_proxy

    echo ""
    echo "✅  Adding finished"
    echo "Global IP address: $global_ip"
    echo "Add this IP address in your DNS records for domain: $domain"
}

# Ask for action in a loop until valid input is provided or user quits
choose_action() {
    while true; do
        echo ""
        echo "What do you want to do?"
        echo "1) Create a new load balancer"
        echo "2) Add domain to existing load balancer"
        echo "q) Quit"
        read -p "Choose option (1, 2 or q): " action

        case "$action" in
            1)
                create_load_balancer
                break
                ;;
            2)
                add_domain_to_load_balancer
                break
                ;;
            q|Q)
                echo "👋  Exiting..."
                kill -INT $$
                ;;
            *)
                echo "❌  Invalid choice. Please enter 1, 2, or q."
                ;;
        esac
    done
}


# Confirm user input
confirm_input() {
    echo ""
    echo "🔍 Please confirm your settings:"
    echo "• Subdomain        : $domain"
    echo "• Cloud Run Service: $_BACKEND_SERVICE"
    echo "• Region           : $_REGION"
    echo ""

    while true; do
        read -p "Is this information correct? (yes/no): " confirm
        if [[ "$confirm" == "yes" ]]; then
            choose_action 
            break 
        elif [[ "$confirm" == "no" ]]; then
            echo "❌  Aborted by user."
            kill -INT $$
        else
            echo "⚠️  Please answer 'yes' or 'no'."
        fi
    done
}

# -----------------------------
# Main Execution Flow
# -----------------------------

# Set user input
set_domain
set_service_name
set_region
confirm_input






