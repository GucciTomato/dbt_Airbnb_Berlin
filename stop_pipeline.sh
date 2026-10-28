#!/usr/bin/env bash
export AWS_PROFILE="${AWS_PROFILE:-terraform}"
export AWS_REGION="${AWS_REGION:-eu-central-1}"
set -e
cd "$(dirname "$0")"

docker compose -f docker/compose.yaml down

kill "$(cat tunnel.pid 2>/dev/null)" 2>/dev/null || true
pkill -f session-manager-plugin || true
rm -f tunnel.pid

aws ec2 stop-instances --instance-ids "$(terraform -chdir=terraform output -raw bastion_id)"

pkill -f "TCP-LISTEN:15433" || true