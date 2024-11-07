variable "vpc_identifier" {
  description = "The user-defined name for the Virtual Private Cloud (VPC)"
  type        = string
}

variable "vpc_cidr_block" {
  description = "The CIDR block defining the IP address range for the Virtual Private Cloud (VPC)"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_blocks" {
  description = "List of CIDR blocks for the public subnets within the VPC"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "private_subnet_blocks" {
  description = "List of CIDR blocks for the private subnets within the VPC"
  type        = list(string)
  default     = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
}

variable "availability_zones_list" {
  description = "A list of Availability Zones in which to deploy resources within the VPC"
  type        = list(string)
}

variable "igw_name" {
  description = "The user-defined name for the Internet Gateway associated with the VPC"
  type        = string
}

variable "public_subnet_route_table" {
  description = "The user-defined name for the Public Routing Table associated with the VPC"
  type        = string
}

variable "public_cidr_routing_table" {
  description = "CIDR block used for routing public traffic in the routing table"
  type        = string
}

variable "private_subnet_route_table" {
  description = "The user-defined name for the private routing table associated with the VPC"
  type        = string
}

variable "aws_current_region" {
  description = "The AWS region where resources will be deployed"
  type        = string
}

variable "ami_id" {
  description = "AMI id of the instance to be used"
  type        = string
}

variable "ec2_instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

variable "ssh_key_name" {
  description = "SSH key name"
  type        = string
}

variable "volume_size" {
  description = "The size of the root volume in GB"
  type        = number
}

variable "volume_type" {
  description = "The type of the root volume"
  type        = string
}

variable "db_username" {
  description = "Database Username"
  type        = string
}

variable "db_password" {
  description = "Database Password"
  type        = string
}

variable "db_name" {
  description = "Database Name"
  type        = string
}

variable "db_engine" {
  description = "Database Engine"
  type        = string
}

variable "db_engine_version" {
  description = "Database Engine Version"
  type        = string
}

variable "rds_instance_class" {
  description = "RDS Instance class"
  type        = string
}

variable "rds_allocated_storage" {
  description = "RDS Allocated Storage"
  type        = string
}

variable "rds_parameter_group_family" {
  description = "RDS parameter group family"
  type        = string
}

variable "selected_zone_name" {
  description = "Name of selected zone"
  type        = string
}

variable "domain_name" {
  description = "Name of the domain"
  type        = string
}

variable "record_type" {
  description = "Type of record added"
  type        = string
}

variable "aws_launch_template_name" {
  description = "Name of the aws launch lemplate"
  type        = string
}

variable "aws_lb_name" {
  description = "Name of the aws load balancer"
  type        = string
}

variable "load_balancer_type" {
  description = "Type of the aws load balancer"
  type        = string
}

variable "aws_lb_target_group" {
  description = "Name of the aws load balancer target group"
  type        = string
}

variable "target_group_port" {
  description = "Port number for target group"
  type        = number
}

variable "target_group_protocol" {
  description = "Protocol"
  type        = string
}

variable "health_check_path" {
  description = "Path for health check"
  type        = string
}

variable "health_check_interval" {
  description = "Interval for health check"
  type        = number
}

variable "health_check_timeout" {
  description = "Time out for health check"
  type        = number
}

variable "health_check_healthy_threshold" {
  description = "Healthy threshold for health check"
  type        = number
}

variable "health_check_unhealthy_threshold" {
  description = "Unhealthy threshold for health check"
  type        = number
}

variable "health_check_matcher" {
  description = "Status code for healthz"
  type        = string
}

variable "aws_lb_listener_port" {
  description = "Load balancer listerner port"
  type        = number
}

variable "aws_lb_listener_protocol" {
  description = "Load balancer listener protocol"
  type        = string
}

variable "scale_up_policy_name" {
  description = "Scale up policy name"
  type        = string
}

variable "scale_down_policy_name" {
  description = "Scale down policy name"
  type        = string
}

variable "scale_up_adjustment" {
  description = "Scale up adjustement"
  type        = number
}

variable "scale_down_adjustment" {
  description = "Scale down adjustement"
  type        = number
}

variable "cooldown_period" {
  description = "Cooldown Period"
  type        = number
}

variable "adjustment_type" {
  description = "Adjustment type"
  type        = string
}

variable "high_cpu_alarm_name" {
  description = "High CPU alarm name"
  type        = string
}

variable "low_cpu_alarm_name" {
  description = "Low CPU alarm name"
  type        = string
}

variable "low_cpu_comparison_operator" {
  description = "Low CPU comparision operator"
  type        = string
}

variable "high_cpu_comparison_operator" {
  description = "High CPU comparision operator"
  type        = string
}

variable "cpu_utilization_metric_name" {
  description = "Cpu utilization metric name"
  type        = string
}

variable "autoscaling_group_min_size" {
  description = "Autoscaling group min size"
  type        = number
}

variable "autoscaling_group_max_size" {
  description = "Autoscaling group max size"
  type        = number
}

variable "autoscaling_group_desired_size" {
  description = "Autoscaling group desired size"
  type        = number
}

variable "autoscaling_statistic" {
  description = "Autoscaling statistic"
  type        = string
}

variable "autoscaling_period" {
  description = "Autoscaling period"
  type        = number
}

variable "autoscaling_namespace" {
  description = "Autoscaling namespace"
  type        = string
}

variable "autoscaling_evaluation_periods" {
  description = "Autoscaling evaluation periods"
  type        = number
}

variable "scale_up_threshold" {
  description = "Autoscaling scale up threshold"
  type        = number
}

variable "scale_down_threshold" {
  description = "Autoscaling scale down threshold"
  type        = number
}

variable "autoscaling_group_health_check_type" {
  description = "Autoscaling group health check type"
  type        = string
}

variable "autoscaling_group_health_check_grace_period" {
  description = "Autoscaling group health grace period"
  type        = number
}