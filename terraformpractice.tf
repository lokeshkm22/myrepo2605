# Configure the AWS Provider
provider "aws" {
  region = "ap-south-1"
}
# Create a VPC
resource "aws_vpc" "myvpc" {
  cidr_block = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "terraformvpc"
  }
}
#create public subnet
resource "aws_subnet" "pubsub"{
  vpc_id     = aws_vpc.myvpc.id
  cidr_block = "10.0.1.0/24"

  tags = {
    Name = "publicsubnet"
  }
}
#create private subnet
resource "aws_subnet" "privsub"{
  vpc_id     = aws_vpc.myvpc.id
  cidr_block = "10.0.2.0/24"

  tags = {
    Name = "privatesubnet"
  }
}
#create internet gatway
resource "aws_internet_gateway" "tigw" {
  vpc_id = aws_vpc.myvpc.id

  tags = {
    Name = "IGW"
  }
}
#create public route table
resource "aws_route_table" "pubrt" {
  vpc_id = aws_vpc.myvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.tigw.id
  }
  tags = {
    Name = "publicrt"
  }
}
#route table association with public subnet 
resource "aws_route_table_association" "publicassociation" {
  subnet_id      = aws_subnet.pubsub.id
  route_table_id = aws_route_table.pubrt.id
}

#nat need elastic ip so create eip first
resource "aws_eip" "eip"{
  vpc=true
}
#create nat gateway for private subnet
resource "aws_nat_gateway" "tnat" {
  allocation_id = aws_eip.eip.id
  subnet_id     = aws_subnet.pubsub.id
  tags = {
    Name = "natgw"
  }
}
#create private route table
resource "aws_route_table" "privrt" {
  vpc_id = aws_vpc.myvpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.tnat.id
  }
  tags = {
    Name = "privatert"
  }
}
#route table association with private subnet 
resource "aws_route_table_association" "privateassociation" {
  subnet_id      = aws_subnet.privsub.id
  route_table_id = aws_route_table.privrt.id
}
#create security group
resource "aws_security_group" "allow_all" {
  name        = "allow_all"
  description = "Allow all inbound traffic"
  vpc_id      = aws_vpc.myvpc.id

  ingress {
    description      = "TLS from VPC"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  ingress {
    description      = "TLS from VPC"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_all"
  }
}

#create ec2 for public subnet
resource "aws_instance" "publicmachine" {
  ami                         =  "ami-010aff33ed5991201"
  instance_type               =  "t2.micro"  
  subnet_id                   =  aws_subnet.pubsub.id
  key_name                    =  "route53"
  vpc_security_group_ids      =  ["${aws_security_group.allow_all.id}"]
  associate_public_ip_address =  true
  user_data= <<-EOF
            #!/bin/bash
            yum install httpd -y
            service httpd start
            echo "Hello Terraform----27-05-2021" > /var/www/html/index.html
            EOF
}
#create ec2 for private subnet
resource "aws_instance" "private" {
  ami                         =  "ami-010aff33ed5991201"
  instance_type               =  "t2.micro"  
  subnet_id                   =  aws_subnet.privsub.id
  key_name                    =  "route53"
  vpc_security_group_ids      =  ["${aws_security_group.allow_all.id}"]
  
}