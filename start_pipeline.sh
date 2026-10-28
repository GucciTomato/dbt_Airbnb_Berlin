#!/usr/bin/env bash
export AWS_PROFILE="${AWS_PROFILE:-terraform}"
export AWS_REGION="${AWS_REGION:-eu-central-1}"
set -e
cd "$(dirname "$0")"

BASTION_ID=$(terraform -chdir=terraform output -raw bastion_id)
RDS_HOST=$(terraform -chdir=terraform output -raw rds_address)

if [ "$(aws ec2 describe-instances --instance-ids "$BASTION_ID" \
        --query 'Reservations[].Instances[].State.Name' --output text)" = "stopping" ]; then
    echo "bastion still shutting down, waiting"
    aws ec2 wait instance-stopped --instance-ids "$BASTION_ID"
fi

aws ec2 start-instances --instance-ids "$BASTION_ID"
aws ec2 wait instance-running --instance-ids "$BASTION_ID"
sleep 30 # give SSM agent time to register

while true; do
    aws ssm start-session --target "$BASTION_ID" \
        --document-name AWS-StartPortForwardingSessionToRemoteHost \
        --parameters "host=$RDS_HOST,portNumber=5432,localPortNumber=15432"
    sleep 10
done &
echo $! > tunnel.pid

docker compose -f docker/compose.yaml up -d
sleep 30
docker compose -f docker/compose.yaml exec -T pipeline \
    airflow dags trigger airbnb_berlin_data_ingestion_pipeline

sleep 60
while true; do
    runs=$(docker compose -f docker/compose.yaml exec -T pipeline \
           airflow dags list-runs airbnb_berlin_data_ingestion_pipeline -o plain) \
        || { echo "could not read dag runs, aborting the wait" >&2; break; }
    grep -qiE 'running|queued' <<<"$runs" || break
    sleep 300
done

./stop_pipeline.sh