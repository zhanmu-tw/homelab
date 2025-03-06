#!/bin/bash

# Exit on any error
set -e

# Step 1: Update the system
echo "Updating the system..."
apt-get update && apt-get upgrade -y
apt-get install -y curl ca-certificates gnupg lsb-release nfs-common

# Step 2: Add Docker's official GPG key
echo "Adding Docker's official GPG key..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

# Step 3: Add Docker repository to Apt sources
echo "Adding Docker repository..."
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update

# Step 4: Install Docker packages
echo "Installing Docker..."
apt-get install -y docker-ce docker-ce-cli containerd.io

# Step 5: Enable and start Docker service
echo "Enabling and starting Docker service..."
systemctl enable --now docker

# Step 6: Set up NFS share (example for your Synology NAS)
echo "Setting up NFS mount from Synology NAS..."
NFS_SERVER="192.168.0.233"   # Replace with your NAS IP address
NFS_SHARE="/volume1/docker_data"  # Replace with the NFS share directory on your NAS
MOUNT_POINT="/mnt/nfs/docker_data"

# Create the mount point
mkdir -p $MOUNT_POINT

# Mount the NFS share
mount -t nfs $NFS_SERVER:$NFS_SHARE $MOUNT_POINT

# Make the mount permanent by adding it to /etc/fstab
echo "$NFS_SERVER:$NFS_SHARE $MOUNT_POINT nfs defaults 0 0" | tee -a /etc/fstab

# Step 7: Initialize Docker Swarm
echo "Initializing Docker Swarm..."
SWARM_INIT=$(docker swarm init --advertise-addr $(hostname -I | awk '{print $1}') 2>&1)
echo "$SWARM_INIT"

# Extract the join token for worker nodes (save for later use)
JOIN_TOKEN=$(echo "$SWARM_INIT" | grep -o 'docker swarm join.*' | tail -n 1)
echo "Swarm initialized. Join token: $JOIN_TOKEN"
echo "Save this join command for adding worker nodes later: $JOIN_TOKEN"

# Step 8: Deploy Portainer using the stack YML manifest
echo "Deploying Portainer with the stack YML manifest..."
curl -L https://downloads.portainer.io/ce-lts/portainer-agent-stack.yml -o portainer-agent-stack.yml

# Deploy the stack in Docker Swarm
docker stack deploy -c portainer-agent-stack.yml portainer

# Step 9: Display status of Docker services
echo "Docker Swarm and Portainer are set up. Checking services..."
docker service ls

echo "Setup completed successfully!"
echo "Portainer is now deployed on your Docker Swarm cluster."
echo "You can access Portainer at http://$(hostname -I | awk '{print $1}'):9000"
echo "Save the Swarm join token for adding worker nodes later: $JOIN_TOKEN"
