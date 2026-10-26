#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"

docker compose -f docker/compose.yaml down

kill "$(cat tunnel.pid 2>/dev/null)" 2>/dev/null || true
pkill -f session-manager-plugin || true
rm -f tunnel.pid

aws ec2 stop-instances --instance-ids "$(terraform -chdir=terraform output -raw bastion_id)"

pkill -f "TCP-LISTEN:15433" || true