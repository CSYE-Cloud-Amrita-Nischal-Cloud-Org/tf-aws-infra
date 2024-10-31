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