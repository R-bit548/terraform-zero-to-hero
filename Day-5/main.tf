provider "aws" {
  region = "us-east-1"
  skip_metadata_api_check = true
  
}

# Define a variable for the VPC CIDR block
variable "cidr" {
  default = "10.0.0.0/16"
}

# Generate an AWS key pair using the public key
resource "aws_key_pair" "example" {
  key_name   = "terraform-demo-mayur"
  public_key = file("/home/ubuntu/.ssh/id_rsa.pub")
}

# Create a VPC
resource "aws_vpc" "myvpc" {
  cidr_block = var.cidr
}

# Create a subnet inside the VPC
resource "aws_subnet" "sub1" {
  vpc_id                  = aws_vpc.myvpc.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
}

# Create an Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.myvpc.id
}

# Create a route table
resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.myvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

# Associate the subnet with the route table
resource "aws_route_table_association" "rta1" {
  subnet_id      = aws_subnet.sub1.id
  route_table_id = aws_route_table.rt.id
}

# Define a security group allowing HTTP and all outbound traffic
resource "aws_security_group" "webSg" {
  name   = "web"
  vpc_id = aws_vpc.myvpc.id

  ingress {
    description = "Allow HTTP from the internet"
    from_port   = 80
    to_port     = 80
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
    Name = "Web-sg"
  }
}

# Create an EC2 instance
resource "aws_instance" "server" {
  ami                    = "ami-0e1bed4f06a3b463d"
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.example.key_name
  subnet_id              = aws_subnet.sub1.id
  vpc_security_group_ids = [aws_security_group.webSg.id]

  # SSH Connection details
  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file("/home/ubuntu/.ssh/id_rsa")
    host        = self.public_ip
  }

  # Upload file to the instance
  provisioner "file" {
    source      = "app.py"
    destination = "/home/ubuntu/app.py"
  }

  # Run remote commands on the instance
  provisioner "remote-exec" {
    inline = [
      "echo 'Hello from the remote instance'",
      "sudo apt update -y",
      "sudo apt-get install -y python3-pip",
      "cd /home/ubuntu",
      "sudo pip3 install flask",
      "nohup sudo python3 app.py &",
    ]
  }
}
