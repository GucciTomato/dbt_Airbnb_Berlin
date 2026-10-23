data "aws_vpc" "default" {
  default = true
}

resource "aws_s3_bucket" "airbnb_berlin_data" {
  bucket        = local.s3_bucket_name
  force_destroy = true
}

resource "aws_db_instance" "postgres" {
  identifier             = "airbnb-berlin-db"
  allocated_storage      = 20
  engine                 = "postgres"
  engine_version         = "18"
  instance_class         = "db.t4g.micro"
  db_name                = "airbnb_berlin_db"
  username               = local.db_user_name
  password               = local.db_password
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  skip_final_snapshot    = true
  publicly_accessible    = true
}

resource "aws_security_group" "rds_sg" {
  name        = "allow-local-to-rds"
  description = "Allows local access to the database"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["${local.my_public_ip}/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# for role: RDS to s3
locals {
  rds_assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "rds.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role" "rds_s3_import" {
  name               = "rds-s3-import"
  assume_role_policy = local.rds_assume_role_policy
}

resource "aws_iam_role_policy" "rds_s3_import" {
  name = "rds-s3-import-access"
  role = aws_iam_role.rds_s3_import.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["s3:GetObject", "s3:ListBucket"]
      Resource = [
        aws_s3_bucket.airbnb_berlin_data.arn,
        "${aws_s3_bucket.airbnb_berlin_data.arn}/*"
      ]
    }]
  })
}

resource "aws_iam_role" "rds_s3_export" {
  name               = "rds-s3-export"
  assume_role_policy = local.rds_assume_role_policy
}

resource "aws_iam_role_policy" "rds_s3_export" {
  name = "rds-s3-export-access"
  role = aws_iam_role.rds_s3_export.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["s3:PutObject", "s3:AbortMultipartUpload", "s3:ListBucket"]
      Resource = [
        aws_s3_bucket.airbnb_berlin_data.arn,
        "${aws_s3_bucket.airbnb_berlin_data.arn}/*"
      ]
    }]
  })
}

resource "aws_db_instance_role_association" "s3_import" {
  db_instance_identifier = aws_db_instance.postgres.identifier
  feature_name           = "s3Import"
  role_arn               = aws_iam_role.rds_s3_import.arn
}

resource "aws_db_instance_role_association" "s3_export" {
  db_instance_identifier = aws_db_instance.postgres.identifier
  feature_name           = "s3Export"
  role_arn               = aws_iam_role.rds_s3_export.arn
}

# for user: local scripts to s3 
resource "aws_iam_user" "pipeline_local_user" {
  name = "pipeline_local_user"
}

resource "aws_iam_user_policy" "pipeline_s3_policy" {
  name = "allow-s3-access"
  user = aws_iam_user.pipeline_local_user.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:PutObject",
        "s3:GetObject",
        "s3:ListBucket",
        "s3:DeleteObject"
      ]
      Resource = [
        aws_s3_bucket.airbnb_berlin_data.arn,
        "${aws_s3_bucket.airbnb_berlin_data.arn}/*"
      ]
    }]
  })
}