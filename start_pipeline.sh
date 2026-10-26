#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"

BASTION_ID=$(terraform -chdir=terraform output -raw bastion_id)
RDS_HOST=$(terraform -chdir=terraform output -raw rds_address)

aws ec2 start-instances --instance-ids "$BASTION_ID"
aws ec2 wait instance-running --instance-ids "$BASTION_ID"
sleep 30

while true; do
    aws ssm start-session --target "$BASTION_ID" \
        --document-name AWS-StartPortForwardingSessionToRemoteHost \
        --parameters "host=$RDS_HOST,portNumber=5432,localPortNumber=15432"
    sleep 10
done &
echo $! > tunnel.pid

socat TCP-LISTEN:15433,fork,reuseaddr TCP:127.0.0.1:15432 &

docker compose -f docker/compose.yaml up -d
sleep 30
docker compose -f docker/compose.yaml exec -T pipeline \
    airflow dags trigger airbnb_berlin_data_ingestion_pipeline