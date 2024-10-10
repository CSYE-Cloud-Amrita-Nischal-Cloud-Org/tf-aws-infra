resource "aws_vpc" "csye6225_vpc" {
  cidr_block = "10.0.0.0/16"

  tags ={
    Name = "demo_vpc"
  }
}