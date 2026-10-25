variable "project_name" {
  type    = string
  default = "airflow-data-pipeline"
}

locals {
    envs = {
        for m in regexall("(?m)^([A-Z_][A-Z0-9_]*)=(.*)$", file("${path.module}/../.env")) :
        m[0] => trim(trimspace(m[1]), "\"'")
    }

  db_user_name = local.envs["DB_USER"]
  db_password  = sensitive(local.envs["DB_PASSWORD"])
  my_public_ip = local.envs["LOCAL_PUBLIC_IP"]
  s3_bucket_name = local.envs["S3_BUCKET"]
  aws_region = local.envs["AWS_REGION"]
}