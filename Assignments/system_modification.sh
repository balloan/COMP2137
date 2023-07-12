#!/bin/bash

new_host_name='autosrv'

static_ip="192.168.16.21/24"
gateway_ip="192.168.16.1"
dns_ip="192.168.16.1"

# Ensure script has appropriate permissions
if [ $USER != "root" ]; then
        echo "Please re-run script with sudo or root - exiting"
        exit 1
fi

