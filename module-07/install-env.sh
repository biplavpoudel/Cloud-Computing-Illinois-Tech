#!/bin/bash

# Sample code to install Nginx webserver

sudo apt update
sudo apt install -y nginx

# Enable Nginx to start on system boot
sudo systemctl enable nginx

# Start the Nginx service
sudo systemctl start nginx

# Check if Nginx is active, and if not, attempt to restart it
if ! systemctl is-active --quiet nginx; then
    echo "Nginx is not running. Attempting to restart..."
    sudo systemctl restart nginx
fi
