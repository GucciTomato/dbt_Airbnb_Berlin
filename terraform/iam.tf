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

resource "aws_iam_user_policy" "pipeline_ssm_policy" {
  name = "allow-ssm-tunnel"
  user = aws_iam_user.pipeline_local_user.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ssm:StartSession",
        "ssm:TerminateSession",
        "ssm:ResumeSession",
        "ssm:DescribeSessions",
        "ssm:DescribeInstanceInformation",
        "ec2:DescribeInstances",
        "ec2:StartInstances",
        "ec2:StopInstances"
      ]
      Resource = "*"
    }]
  })
}

resource "aws_iam_role" "bastion" {
  name = "bastion-ssm"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "bastion_ssm" {
  role       = aws_iam_role.bastion.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "bastion" {
  name = "bastion-ssm"
  role = aws_iam_role.bastion.name
}

resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = "t4g.nano"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.bastion_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.bastion.name

  tags = { Name = "airbnb-berlin-bastion" }
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