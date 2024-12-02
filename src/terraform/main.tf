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

// Updated EC2 Security Group for Application Instances
resource "aws_security_group" "instance_sg" {
  vpc_id = aws_vpc.my_vpc.id

  // Allow SSH access from the Load Balancer Security Group only
  # ingress {
  #   from_port       = 22
  #   to_port         = 22
  #   protocol        = "tcp"
  #   # cidr_blocks      = ["0.0.0.0/0"]
  #   # ipv6_cidr_blocks = ["::/0"]
  #   security_groups = [aws_security_group.load_balancer_sg.id]
  #   description     = "Allow SSH from Load Balancer Security Group"
  # }

  // Allow application traffic (e.g., HTTP/HTTPS) from the Load Balancer Security Group only
  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.load_balancer_sg.id]
    description     = "Allow app traffic from Load Balancer Security Group"
  }

  // Egress rule to allow all outbound traffic
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

# Generate a random password for the database
resource "random_password" "db_password" {
  length           = 16
  special          = true
  upper            = true
  lower            = true
  override_special = "!#$%&*()-_+="
}

# Create Secrets Manager Secret for DB Password
resource "aws_secretsmanager_secret" "db_password_secret" {
  name        = "db-password-secret_${random_uuid.unique_id.result}"
  description = "Database password"
  kms_key_id  = aws_kms_key.secrets_kms_key.arn
}

# Store the Password in Secrets Manager
resource "aws_secretsmanager_secret_version" "db_password_secret_version" {
  secret_id     = aws_secretsmanager_secret.db_password_secret.id
  secret_string = jsonencode({ password = random_password.db_password.result })
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
  password               = random_password.db_password.result
  parameter_group_name   = aws_db_parameter_group.postgresql_parameter_group.name
  db_subnet_group_name   = aws_db_subnet_group.my_db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  storage_encrypted      = true
  kms_key_id             = aws_kms_key.rds_kms_key.arn

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

# For secrets
resource "random_uuid" "unique_id" {}

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
      kms_master_key_id = aws_kms_key.s3_kms_key.arn
      sse_algorithm     = "aws:kms"
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

# IAM policy to access rds
resource "aws_iam_role_policy" "rds_access_policy" {
  name = "rds_access_policy"
  role = aws_iam_role.cloudwatch_agent_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "rds-db:connect"
        ]
        Resource = aws_db_instance.my_postgres_db.arn
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

# Define a policy to allow EC2 instances to interact with SNS topics
resource "aws_iam_policy" "ec2_sns_policy" {
  name        = "ec2-sns-policy"
  description = "Policy to allow EC2 instances to interact with SNS topics"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "sns:Publish",                  # Allow publishing messages to SNS
          "sns:Subscribe",                # Allow subscribing to SNS topics
          "sns:Unsubscribe",              # Allow unsubscribing from SNS topics
          "sns:ListSubscriptionsByTopic", # Allow listing subscriptions by topic
          "sns:ListTopics"                # Allow listing SNS topics
        ],
        Resource = var.sns_policy_resource_name
      }
    ]
  })
}

# Attach the SNS policy to the EC2 IAM role
resource "aws_iam_role_policy_attachment" "ec2_sns_policy_attachment" {
  role       = aws_iam_role.cloudwatch_agent_role.name # Use the correct IAM role for EC2 instances
  policy_arn = aws_iam_policy.ec2_sns_policy.arn
}


// Load Balancer Security Group
resource "aws_security_group" "load_balancer_sg" {
  vpc_id = aws_vpc.my_vpc.id

  # ingress {
  #   from_port        = 80
  #   to_port          = 80
  #   protocol         = "tcp"
  #   cidr_blocks      = ["0.0.0.0/0"]
  #   ipv6_cidr_blocks = ["::/0"]
  #   description      = "Allow HTTP from port 80"
  # }

  ingress {
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
    description      = "Allow HTTPS traffic from anywhere"
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "Load Balancer Security Group"
  }
}

# Launch Template for Auto Scaling Group
resource "aws_launch_template" "csye6225_launch_template" {
  name          = var.aws_launch_template_name
  image_id      = var.ami_id
  instance_type = var.ec2_instance_type
  key_name      = var.ssh_key_name
  iam_instance_profile {
    name = aws_iam_instance_profile.cloudwatch_instance_profile.name
  }

  # Define network interface with security groups and public IP association
  network_interfaces {
    associate_public_ip_address = true
    delete_on_termination       = true
    security_groups             = [aws_security_group.instance_sg.id]
  }

  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      volume_size           = var.volume_size
      volume_type           = var.volume_type
      delete_on_termination = true
      encrypted             = true
      kms_key_id            = aws_kms_key.ec2_encryption_key.arn
    }
  }

  user_data = base64encode(<<EOF
#!/bin/bash

exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

# Install updates and dependencies
sudo apt-get update
sudo apt-get install -y curl unzip jq

curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip

sudo ./aws/install

# Database connection details
SECRET_DATA=$(aws secretsmanager get-secret-value \
  --secret-id "${aws_secretsmanager_secret.db_credentials.id}" \
  --region "${var.aws_current_region}" \
  --query SecretString \
  --output text)

# Database connection details
DB_HOST=$(echo $SECRET_DATA | jq -r '.DB_HOST')
DB_USER=$(echo $SECRET_DATA | jq -r '.DB_USER')
DB_PASSWORD=$(echo $SECRET_DATA | jq -r '.DB_PASSWORD')
DB_NAME=$(echo $SECRET_DATA | jq -r '.DB_NAME')

echo "# App Environment Variables"
echo "DB_URL=jdbc:postgresql://$DB_HOST:5432/$DB_NAME?useSSL=false&useUnicode=true&useJDBCCompliantTimezoneShift=true&useLegacyDatetimeCode=false&serverTimezone=UTC" >> /etc/environment
echo "DB_USERNAME=$DB_USER" >> /etc/environment
echo "DB_PASSWORD=$DB_PASSWORD" >> /etc/environment
echo "AWS_S3_BUCKET_NAME=${aws_s3_bucket.csye6225-bucket.bucket}" >> /etc/environment
echo "AWS_REGION=${var.aws_current_region}" >> /etc/environment
echo "AWS_SNS_TOPIC_NAME=${var.aws_sns_topic_name}" >> /etc/environment

sudo truncate -s 0 /opt/webapp/logs/webapp.log

sudo systemctl daemon-reload
sudo systemctl restart app.service
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
             -a fetch-config \
             -m ec2 \
             -c file:/opt/aws/amazon-cloudwatch-agent/bin/cloudwatch-config.json \
             -s
EOF
  )
}

# Application Load Balancer
resource "aws_lb" "app_load_balancer" {
  name               = var.aws_lb_name
  internal           = false
  load_balancer_type = var.load_balancer_type
  security_groups    = [aws_security_group.load_balancer_sg.id]
  subnets            = aws_subnet.public_subnets[*].id

  tags = {
    Name = "Application Load Balancer"
  }
}

# Target Group for Auto Scaling Group Instances
resource "aws_lb_target_group" "target_group" {
  name     = var.aws_lb_target_group
  port     = var.target_group_port
  protocol = var.target_group_protocol
  vpc_id   = aws_vpc.my_vpc.id
  health_check {
    path                = var.health_check_path
    protocol            = var.target_group_protocol
    port                = var.target_group_port
    interval            = var.health_check_interval
    timeout             = var.health_check_timeout
    healthy_threshold   = var.health_check_healthy_threshold
    unhealthy_threshold = var.health_check_unhealthy_threshold
    matcher             = var.health_check_matcher
  }

  tags = {
    Name = "WebAppTargetGroup"
  }
}

# Listener for Application Load Balancer
# resource "aws_lb_listener" "app_listener" {
#   load_balancer_arn = aws_lb.app_load_balancer.arn
#   port              = var.aws_lb_listener_port
#   protocol          = var.aws_lb_listener_protocol

#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.target_group.arn
#   }
# }

# Auto Scaling Policies
# Scale Up Policy
resource "aws_autoscaling_policy" "scale_up_policy" {
  name                   = var.scale_up_policy_name
  scaling_adjustment     = var.scale_up_adjustment
  adjustment_type        = var.adjustment_type
  autoscaling_group_name = aws_autoscaling_group.csye6225_asg.name
  cooldown               = var.cooldown_period
}

# Scale Down Policy
resource "aws_autoscaling_policy" "scale_down_policy" {
  name                   = var.scale_down_policy_name
  scaling_adjustment     = var.scale_down_adjustment
  adjustment_type        = var.adjustment_type
  autoscaling_group_name = aws_autoscaling_group.csye6225_asg.name
  cooldown               = var.cooldown_period
}

# CloudWatch Metric Alarms for Auto Scaling
# Scale Up Alarm
resource "aws_cloudwatch_metric_alarm" "high_cpu_alarm" {
  alarm_name          = var.high_cpu_alarm_name
  comparison_operator = var.high_cpu_comparison_operator
  evaluation_periods  = var.autoscaling_evaluation_periods
  metric_name         = var.cpu_utilization_metric_name
  namespace           = var.autoscaling_namespace
  period              = var.autoscaling_period
  statistic           = var.autoscaling_statistic
  threshold           = var.scale_up_threshold
  alarm_actions       = [aws_autoscaling_policy.scale_up_policy.arn]
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.csye6225_asg.name
  }
}

# Scale Down Alarm
resource "aws_cloudwatch_metric_alarm" "low_cpu_alarm" {
  alarm_name          = var.low_cpu_alarm_name
  comparison_operator = var.low_cpu_comparison_operator
  evaluation_periods  = var.autoscaling_evaluation_periods
  metric_name         = var.cpu_utilization_metric_name
  namespace           = var.autoscaling_namespace
  period              = var.autoscaling_period
  statistic           = var.autoscaling_statistic
  threshold           = var.scale_down_threshold
  alarm_actions       = [aws_autoscaling_policy.scale_down_policy.arn]
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.csye6225_asg.name
  }
}

# Auto Scaling Group with Target Group Attachment
resource "aws_autoscaling_group" "csye6225_asg" {
  launch_template {
    id      = aws_launch_template.csye6225_launch_template.id
    version = "$Latest"
  }
  name                      = var.auto_scaling_group_name
  min_size                  = var.autoscaling_group_min_size
  max_size                  = var.autoscaling_group_max_size
  desired_capacity          = var.autoscaling_group_desired_size
  vpc_zone_identifier       = aws_subnet.public_subnets[*].id
  health_check_type         = var.autoscaling_group_health_check_type
  health_check_grace_period = var.autoscaling_group_health_check_grace_period
  target_group_arns         = [aws_lb_target_group.target_group.arn]

  tag {
    key                 = "Name"
    value               = "AutoScaledJavaAppInstance"
    propagate_at_launch = true
  }

  depends_on = [aws_lb_target_group.target_group]
}

# Route 53 A Record as Alias for ALB
resource "aws_route53_record" "app_alias_record" {
  zone_id = data.aws_route53_zone.selected_zone.zone_id
  name    = var.domain_name
  type    = var.record_type

  alias {
    name                   = aws_lb.app_load_balancer.dns_name
    zone_id                = aws_lb.app_load_balancer.zone_id
    evaluate_target_health = true
  }

  depends_on = [aws_lb.app_load_balancer]
}

resource "aws_secretsmanager_secret" "email_config" {
  name        = "email_config__${random_uuid.unique_id.result}"
  description = "Email configuration for Lambda function"
}

resource "aws_secretsmanager_secret_version" "email_config_version" {
  secret_id = aws_secretsmanager_secret.email_config.id
  secret_string = jsonencode({
    MAILGUN_API_KEY = var.mailgun_api_key
    MAILGUN_DOMAIN  = var.mailgun_domain
    APP_URL         = var.mailgun_domain
  })
}

resource "aws_secretsmanager_secret" "db_credentials" {
  name        = "db_credentials__${random_uuid.unique_id.result}"
  description = "Database credentials for Lambda function"
  kms_key_id  = aws_kms_key.secrets_kms_key.arn
}

resource "aws_secretsmanager_secret_version" "db_credentials_version" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    DB_HOST     = aws_db_instance.my_postgres_db.address
    DB_USER     = aws_db_instance.my_postgres_db.username
    DB_PASSWORD = random_password.db_password.result
    DB_NAME     = aws_db_instance.my_postgres_db.db_name
  })
  depends_on = [aws_db_instance.my_postgres_db]
}

# Creates an SNS topic
resource "aws_sns_topic" "email_verification" {
  name = var.aws_sns_topic_name
}

# Creates an IAM Role for Lambda Function
resource "aws_iam_role" "lambda_iam_role" {
  name = "lambda_iam_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Creates an IAM Policy for Lambda Function
resource "aws_iam_policy" "lambda_iam_policy" {
  name        = "lambda_iam_policy"
  description = "Policy to grant Lambda access to SNS"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["sns:Publish", "sns:Subscribe"]
        Resource = aws_sns_topic.email_verification.arn
      },
      {
        Effect : "Allow",
        Action : [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource : "arn:aws:logs:*:*:*"
      },
      # Allow Lambda to retrieve secrets from Secrets Manager
      {
        Effect : "Allow",
        Action : [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ],
        Resource : [
          aws_secretsmanager_secret.email_config.arn
        ]
      },
      {
        Effect : "Allow",
        Action : ["kms:Decrypt"],
        Resource : aws_kms_key.secrets_kms_key.arn
      }
    ]
  })
}

# Attach role and policy arn to lambda
resource "aws_iam_role_policy_attachment" "lambda_attach_role" {
  role       = aws_iam_role.lambda_iam_role.name
  policy_arn = aws_iam_policy.lambda_iam_policy.arn
}

# Creates Lambda function to verify email
resource "aws_lambda_function" "email_verification_lambda" {
  s3_bucket = var.lambda_function_s3_bucket
  s3_key    = var.lambda_function_s3_key
  # filename      = "${path.module}/lambda_function.zip"
  function_name = "SendVerificationEmailFunction"
  role          = aws_iam_role.lambda_iam_role.arn
  handler       = "index.handler"
  runtime       = "nodejs18.x"
  timeout       = 15

  environment {
    variables = {
      MAILGUN_SECRET_ARN = aws_secretsmanager_secret.email_config.arn
    }
  }

  depends_on = [aws_iam_role_policy_attachment.lambda_attach_role]
}

# Creates permissions for Lambda for SNS
resource "aws_lambda_permission" "allow_sns" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.email_verification_lambda.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.email_verification.arn
}

# Subscirbes topic for lambda
resource "aws_sns_topic_subscription" "lambda_subscription" {
  topic_arn = aws_sns_topic.email_verification.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.email_verification_lambda.arn
}

# HTTPS Listener
resource "aws_lb_listener" "https_listener" {
  load_balancer_arn = aws_lb.app_load_balancer.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = data.aws_acm_certificate.ssl_certificate.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target_group.arn
  }

}

data "aws_acm_certificate" "ssl_certificate" {
  domain      = var.domain_name
  most_recent = true
  statuses    = ["ISSUED"]
}

# Data Source to Retrieve Current AWS Account Information
data "aws_caller_identity" "current" {}

# KMS Key for EC2
resource "aws_kms_key" "ec2_encryption_key" {
  customer_master_key_spec = "SYMMETRIC_DEFAULT"
  description              = "KMS key for EC2 EBS Encryption"
  key_usage                = "ENCRYPT_DECRYPT"
  is_enabled               = true
  enable_key_rotation      = true
  rotation_period_in_days  = 90
  deletion_window_in_days  = 7

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow service-linked role use of the customer managed key"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      },
      {
        Sid    = "Allow attachment of persistent resources"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling"
        }
        Action = [
          "kms:CreateGrant",
          "kms:ListGrants",
          "kms:RevokeGrant"
        ]
        Resource = "*"
        Condition = {
          Bool = {
            "kms:GrantIsForAWSResource" : "true"
          }
        }
      }
    ]
  })
}

# KMS Alias for EC2
resource "aws_kms_alias" "ec2_encryption_key_alias" {
  name          = "alias/ec2-encryption-key"
  target_key_id = aws_kms_key.ec2_encryption_key.key_id
}

# KMS Key for RDS
resource "aws_kms_key" "rds_kms_key" {
  customer_master_key_spec = "SYMMETRIC_DEFAULT"
  description              = "KMS key for RDS"
  key_usage                = "ENCRYPT_DECRYPT"
  is_enabled               = true
  enable_key_rotation      = true
  rotation_period_in_days  = 90

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "AllowRootAccess",
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        },
        Action   = "kms:*",
        Resource = "*"
      },
      {
        Sid    = "AllowRDSAccess",
        Effect = "Allow",
        Principal = {
          Service = "rds.amazonaws.com"
        },
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ],
        Resource = "*"
      },
      {
        Sid    = "AllowServiceLinkedRoleAccess",
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling"
        },
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ],
        Resource = "*"
      },
      {
        Sid    = "AllowEC2RoleAccess",
        Effect = "Allow",
        Principal = {
          AWS = aws_iam_role.cloudwatch_agent_role.arn
        },
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_kms_alias" "rds_alias" {
  name          = "alias/rds_kms_key"
  target_key_id = aws_kms_key.rds_kms_key.key_id
}

resource "aws_kms_key" "s3_kms_key" {
  description             = "KMS key for S3"
  key_usage               = "ENCRYPT_DECRYPT"
  is_enabled              = true
  enable_key_rotation     = true
  rotation_period_in_days = 90

  policy = jsonencode({
    Version : "2012-10-17",
    Statement : [
      {
        Sid : "AllowRootAccess",
        Effect : "Allow",
        Principal : {
          AWS : "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        },
        Action : "kms:*",
        Resource : "*"
      },
      {
        Sid : "AllowS3Access",
        Effect : "Allow",
        Principal : {
          Service : "s3.amazonaws.com"
        },
        Action : [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ],
        Resource : "*"
      },
      {
        Sid : "AllowEC2RoleAccess",
        Effect : "Allow",
        Principal : {
          AWS : aws_iam_role.cloudwatch_agent_role.arn
        },
        Action : [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ],
        Resource : "*"
      }
    ]
  })

  tags = {
    Purpose = "Encrypt S3 buckets"
  }
}

resource "aws_kms_alias" "s3_alias" {
  name          = "alias/s3_kms_key"
  target_key_id = aws_kms_key.s3_kms_key.key_id
}

resource "aws_kms_key" "secrets_kms_key" {
  description             = "KMS key for Secrets Manager"
  key_usage               = "ENCRYPT_DECRYPT"
  is_enabled              = true
  enable_key_rotation     = true
  rotation_period_in_days = 90

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "AllowRootAccess",
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        },
        Action   = "kms:*",
        Resource = "*"
      },
      {
        Sid    = "AllowSecretsManagerAccess",
        Effect = "Allow",
        Principal = {
          Service = "secretsmanager.amazonaws.com"
        },
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:GenerateDataKeyWithoutPlaintext",
          "kms:DescribeKey"
        ],
        Resource = "*"
      },
      {
        Sid    = "AllowEC2RoleAccess",
        Effect = "Allow",
        Principal = {
          AWS = aws_iam_role.cloudwatch_agent_role.arn
        },
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:GenerateDataKeyWithoutPlaintext",
          "kms:DescribeKey"
        ],
        Resource = "*"
      }
    ]
  })

  tags = {
    Purpose = "Encrypt Secrets Manager secrets"
  }
}

resource "aws_iam_policy" "secrets_kms_access_policy" {
  name = "secrets-kms-access-policy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:GenerateDataKeyWithoutPlaintext",
          "kms:DescribeKey"
        ]
        Resource = aws_kms_key.secrets_kms_key.arn
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "secrets_kms_policy_attachment" {
  role       = aws_iam_role.cloudwatch_agent_role.name
  policy_arn = aws_iam_policy.secrets_kms_access_policy.arn
}

resource "aws_kms_alias" "secrets_alias" {
  name          = "alias/secrets_kms_key"
  target_key_id = aws_kms_key.secrets_kms_key.key_id
}

output "ssl_certificate" {
  value = data.aws_acm_certificate.ssl_certificate.arn
}

