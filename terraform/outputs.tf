output "rds_address" {
  description = "hostname for psql -h"
  value       = aws_db_instance.postgres.address
}

output "rds_port" {
  value = aws_db_instance.postgres.port
}

output "rds_db_name" {
  value = aws_db_instance.postgres.db_name
}

output "s3_bucket_name" {
  description = "airbnb-berlin-data-2026-j"
  value       = aws_s3_bucket.airbnb_berlin_data.id
}

output "bastion_id" {
  value = aws_instance.bastion.id
}