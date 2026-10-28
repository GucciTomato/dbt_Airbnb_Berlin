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
  db_subnet_group_name   = aws_db_subnet_group.main.name
  skip_final_snapshot    = true
  publicly_accessible    = false
}