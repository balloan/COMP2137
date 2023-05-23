#!/bin/bash

echo "Hostname: $(hostnamectl hostname)"
echo "IP Address(es): $(hostname -I)"
echo "Gateway: $(ip -4 route show default)"
