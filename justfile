# Variables
droplet_name := "test-nix-server"
max_retries := "30"
retry_delay := "10"

# Default recipe
default:
    @just --list

# Get droplet IP
get-droplet-ip:
    #!/usr/bin/env bash
    for i in $(seq 1 {{max_retries}}); do
        IP=$(doctl compute droplet get {{droplet_name}} --format PublicIPv4 --no-header | tr -d '\n')
        if [ ! -z "$IP" ]; then
            echo "$IP"
            exit 0
        fi
        if [ $i -lt {{max_retries}} ]; then
            sleep {{retry_delay}}
        fi
    done
    echo "Timeout: Unable to get droplet IP after {{max_retries}} attempts"
    exit 1

# Check if droplet exists
droplet-exists:
    #!/usr/bin/env bash
    if doctl compute droplet get {{droplet_name}} &>/dev/null; then
        echo "true"
    else
        echo "false"
    fi

# SSH into the droplet
ssh:
    #!/usr/bin/env bash
    echo "Attempting to SSH into the droplet..."
    IP=$(just get-droplet-ip)
    if [ "$IP" != "Timeout: Unable to get droplet IP after {{max_retries}} attempts" ]; then
        ssh root@$IP
    else
        echo "$IP"
        exit 1
    fi

# Recreate droplet
recreate-droplet:
    #!/usr/bin/env bash
    if [ "$(just droplet-exists)" = "true" ]; then
        echo "Deleting existing droplet..."
        doctl compute droplet delete {{droplet_name}} --force
    else
        echo "No existing droplet found. Proceeding with creation."
    fi
    echo "Creating new droplet..."
    echo "Please select an SSH key:"
    SSH_KEY=$(doctl compute ssh-key list --format Name,ID --no-header | awk '{for(i=1;i<NF-1;i++) printf "%s ", $i; print $(NF-1) "\t" $NF}' | fzf --with-nth=1 --delimiter='\t' --header=$"Select SSH Key" | cut -f2)
    if [ -z "$SSH_KEY" ]; then
        echo "No SSH key selected. Aborting droplet creation."
        exit 1
    fi
    doctl compute droplet create \
        --image ubuntu-22-04-x64 \
        --size s-1vcpu-2gb-70gb-intel \
        --region lon1 \
        --vpc-uuid enter-vpc-id-here \
        --ssh-keys "$SSH_KEY" \
        {{droplet_name}}

# Install Nix using nix-anywhere
install-nix:
    #!/usr/bin/env bash
    IP=$(just get-droplet-ip)
    if [ "$IP" = "Timeout: Unable to get droplet IP after {{max_retries}} attempts" ]; then
        echo "Failed to get droplet IP. Aborting Nix installation."
        exit 1
    fi
    echo "Installing Nix on droplet with IP: $IP"
    nix run github:nix-community/nixos-anywhere -- --flake .#digitalocean --debug root@$IP

update-config:
    #!/usr/bin/env bash
    IP=$(just get-droplet-ip)
    if [ "$IP" = "Timeout: Unable to get droplet IP after {{max_retries}} attempts" ]; then
        echo "Failed to get droplet IP. Aborting configuration update."
        exit 1
    fi
    echo "Updating configuration on droplet with IP: $IP"
    nixos-rebuild switch --flake .#digitalocean --target-host "root@$IP"
    

