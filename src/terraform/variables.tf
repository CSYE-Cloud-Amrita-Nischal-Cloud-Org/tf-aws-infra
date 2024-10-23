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
  description = "The type of the root volume"
  type        = string
}

variable "db_password" {
  description = "The type of the root volume"
  type        = string
}

variable "db_name" {
  description = "The type of the root volume"
  type        = string
}

