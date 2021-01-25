
provider "aws" {
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  region     = var.region
}

# create a vpc
resource "aws_vpc" "dev" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "dev"
  }
}

# create subnet
resource "aws_subnet" "subnet1" {
  vpc_id     = aws_vpc.dev.id
  cidr_block = "10.0.1.0/24"

  tags = {
    Name = "subnet1"
  }
}

resource "aws_subnet" "subnet2" {
  vpc_id     = aws_vpc.dev.id
  cidr_block = "10.0.2.0/24"

  tags = {
    Name = "subnet2"
  }
}

# create internet gateway
resource "aws_internet_gateway" "dev-gw" {
  vpc_id = aws_vpc.dev.id

  tags = {
    Name = "dev-gw"
  }
}

# route table
resource "aws_route_table" "dev-rt" {
  vpc_id = aws_vpc.dev.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.dev-gw.id
  }

  tags = {
    Name = "dev-rt"
  }
}

# associate subnet with route table
resource "aws_route_table_association" "dev-a" {
  subnet_id      = aws_subnet.subnet1.id
  route_table_id = aws_route_table.dev-rt.id
}

# create security group
resource "aws_security_group" "allow_web" {
  name        = "allow_web"
  description = "Allow http and ssh"
  vpc_id      = aws_vpc.dev.id

  ingress {
    description = "http from world"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "ssh from office"
    from_port   = 22
    to_port     = 22
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
    Name = "allow_web"
  }
}
#create network interface
resource "aws_network_interface" "web-nic" {
  subnet_id       = aws_subnet.subnet1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]
}
# assign elastic IP
resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.web-nic.id
  associate_with_private_ip = "10.0.1.50"
}

#create ec2-instance
resource "aws_instance" "web-instance" {
  ami           = "ami-0be2609ba883822ec"
  instance_type = "t2.micro"
  key_name      = "demo_key"

  network_interface {
    network_interface_id = aws_network_interface.web-nic.id
    device_index         = 0
  }

  user_data = <<EOF
        #!/bin/bash
        sudo yum update -y
        sudo yum install -y httpd
        sudo systemctl start httpd
        sudo systemctl enable httpd
        echo "<h1>Deployed via Terraform</h1>" | sudo tee /var/www/html/index.html
        EOF

  tags = {
    Name = "web-server"
  }
}
