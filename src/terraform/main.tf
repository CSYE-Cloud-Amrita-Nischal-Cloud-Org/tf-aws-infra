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
  ami                         = var.ami_id
  instance_type               = var.ec2_instance_type
  subnet_id                   = aws_subnet.public_subnets[0].id
  vpc_security_group_ids      = [aws_security_group.instance_sg.id]
  associate_public_ip_address = true
  key_name                    = var.ssh_key_name
  tags = {
    Name = "Java Application Instance"
  }
}