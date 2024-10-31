data "aws_availability_zones" "available" {}

// Public Subnets
resource "aws_subnet" "public_subnets" {
  count             = length(var.public_subnet_blocks)
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = var.public_subnet_blocks[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "Public Subnet ${count.index + 1}"
  }
}

// Private Subnets
resource "aws_subnet" "private_subnets" {
  count             = length(var.private_subnet_blocks)
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = var.private_subnet_blocks[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "Private Subnet ${count.index + 1}"
  }
}

// Internet Gateway
resource "aws_internet_gateway" "my_gateway" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = var.igw_name
  }
}

// Public Routing Table
resource "aws_route_table" "public_routing_table" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = var.public_cidr_routing_table
    gateway_id = aws_internet_gateway.my_gateway.id
  }

  tags = {
    Name = var.public_subnet_route_table
  }
}

// Public Route Table Association
resource "aws_route_table_association" "public_association" {
  count          = length(aws_subnet.public_subnets)
  subnet_id      = aws_subnet.public_subnets[count.index].id
  route_table_id = aws_route_table.public_routing_table.id
}

// Private Routing Table
resource "aws_route_table" "private_routing_table" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = var.private_subnet_route_table
  }
}

// Private Route Table Association
resource "aws_route_table_association" "private_association" {
  count          = length(aws_subnet.private_subnets)
  subnet_id      = aws_subnet.private_subnets[count.index].id
  route_table_id = aws_route_table.private_routing_table.id
}

resource "aws_security_group" "instance_sg" {
  vpc_id = aws_vpc.my_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "application security group"
  }
}

# AWS Instance Block
resource "aws_instance" "my_instance" {
  ami = var.ami_id

  root_block_device {
    volume_size           = var.volume_size
    volume_type           = var.volume_type
    delete_on_termination = true
  }

  disable_api_termination     = false
  instance_type               = var.ec2_instance_type
  subnet_id                   = aws_subnet.public_subnets[0].id
  vpc_security_group_ids      = [aws_security_group.instance_sg.id]
  associate_public_ip_address = true
  key_name                    = var.ssh_key_name
  depends_on                  = [aws_db_instance.my_postgres_db, aws_s3_bucket.csye6225-bucket]
  iam_instance_profile        = aws_iam_instance_profile.cloudwatch_instance_profile.name

  user_data = <<EOF
#!/bin/bash
echo "# App Environment Variables"
echo "DB_URL=jdbc:postgresql://${aws_db_instance.my_postgres_db.address}:5432/${var.db_name}?useSSL=false&useUnicode=true&useJDBCCompliantTimezoneShift=true&useLegacyDatetimeCode=false&serverTimezone=UTC" >> /etc/environment
echo "DB_USERNAME=${var.db_username}" >> /etc/environment
echo "DB_PASSWORD=${var.db_password}" >> /etc/environment
echo "AWS_S3_BUCKET_NAME=${aws_s3_bucket.csye6225-bucket.bucket}" >> /etc/environment
echo "AWS_REGION=${var.aws_current_region}" >> /etc/environment

sudo truncate -s 0 /opt/webapp/logs/webapp.log

sudo systemctl daemon-reload
sudo systemctl restart app.service
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
             -a fetch-config \
             -m ec2 \
             -c file:/opt/aws/amazon-cloudwatch-agent/bin/cloudwatch-config.json \
             -s
EOF

  tags = {
    Name = "Java Application Instance"
  }
}

// Database Security Group for PostgreSQL
resource "aws_security_group" "db_sg" {
  vpc_id = aws_vpc.my_vpc.id

  // Ingress rule to allow PostgreSQL traffic (port 5432) from the application security group
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.instance_sg.id]
    description     = "Allow PostgreSQL traffic from application security group"
  }

  // Egress rule to allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "PostgreSQL Database Security Group"
  }
}

// RDS Parameter Group for PostgreSQL
resource "aws_db_parameter_group" "postgresql_parameter_group" {
  name        = "custom-postgres-parameter-group"
  family      = var.rds_parameter_group_family
  description = "Custom PostgreSQL parameter group"

  parameter {
    name         = "max_connections"
    value        = "200"
    apply_method = "pending-reboot"
  }

  tags = {
    Name = "Custom PostgreSQL Parameter Group"
  }
}

// RDS Instance for PostgreSQL
resource "aws_db_instance" "my_postgres_db" {
  db_name                = var.db_name
  allocated_storage      = var.rds_allocated_storage
  engine                 = var.db_engine
  engine_version         = var.db_engine_version
  instance_class         = var.rds_instance_class
  identifier             = var.db_name
  username               = var.db_username
  password               = var.db_password
  parameter_group_name   = aws_db_parameter_group.postgresql_parameter_group.name
  db_subnet_group_name   = aws_db_subnet_group.my_db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]

  publicly_accessible = false
  multi_az            = false
  skip_final_snapshot = true

  tags = {
    Name = "csye6225"
  }
}

// DB Subnet Group for RDS instance
resource "aws_db_subnet_group" "my_db_subnet_group" {
  name       = "my-db-subnet-group"
  subnet_ids = aws_subnet.private_subnets[*].id

  tags = {
    Name = "MyDBSubnetGroup"
  }
}

# Generate a unique UUID for the S3 bucket name
resource "random_uuid" "bucket_name" {}

# Create the S3 bucket with UUID as its name
resource "aws_s3_bucket" "csye6225-bucket" {
  bucket = random_uuid.bucket_name.result

  # Enable force destroy to delete non-empty buckets
  force_destroy = true
}

# Configure server-side encryption using a separate resource
resource "aws_s3_bucket_server_side_encryption_configuration" "csye6225-bucket_encryption" {
  bucket = aws_s3_bucket.csye6225-bucket.bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Add a bucket policy to make it private and enforce HTTPS
resource "aws_iam_policy" "csye6225-bucket_policy" {
  name = "bucket_policy"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListAllMyBuckets"
        ],
        "Resource" : "${aws_s3_bucket.csye6225-bucket.arn}/*",
      }
    ]
  })
}

# Lifecycle configuration for transitioning objects
resource "aws_s3_bucket_lifecycle_configuration" "csye6225-bucket_lifecycle" {
  bucket = aws_s3_bucket.csye6225-bucket.bucket

  rule {
    id     = "transition-to-ia"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
  }
}

# Output the generated bucket name
output "bucket_name" {
  value = aws_s3_bucket.csye6225-bucket.bucket
}

# Route 53 Zone Data
data "aws_route53_zone" "selected_zone" {
  name         = var.selected_zone_name
  private_zone = false
}

# Route 53 A Record pointing to EC2 instance IP
resource "aws_route53_record" "domain_name" {
  zone_id = data.aws_route53_zone.selected_zone.zone_id
  name    = var.domain_name
  type    = var.record_type
  ttl     = 60
  records = [aws_instance.my_instance.public_ip]

}

output "domain_name" {
  value = aws_route53_record.domain_name.fqdn
}

# IAM Role for CloudWatch Agent
resource "aws_iam_role" "cloudwatch_agent_role" {
  name = "CloudWatchAgentRole"

  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "ec2.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })
}

# Attach CloudWatch and SSM Policies to Role
resource "aws_iam_role_policy_attachment" "cloudwatch_agent_policy" {
  role       = aws_iam_role.cloudwatch_agent_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy_attachment" "s3_policy" {
  role       = aws_iam_role.cloudwatch_agent_role.name
  policy_arn = aws_iam_policy.csye6225-bucket_policy.arn
}

# Instance Profile for EC2
resource "aws_iam_instance_profile" "cloudwatch_instance_profile" {
  name = "CloudWatchAgentInstanceProfile"
  role = aws_iam_role.cloudwatch_agent_role.name
}

