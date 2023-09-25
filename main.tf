#creating vpc
resource "aws_vpc" "Terraform" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "Terraform"
  }
}

#creating subnet for vpc
resource "aws_subnet" "sub1" {
  vpc_id     = aws_vpc.Terraform.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "ap-south-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "sub1"
  }
}

resource "aws_subnet" "sub2" {
  vpc_id     = aws_vpc.Terraform.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "ap-south-1b"
  map_public_ip_on_launch = true
  tags = {
    Name = "sub2"
  }
}

#creating internet-getway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.Terraform.id

  tags = {
    Name = "igw"
  }
}

#creating Route tables

resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.Terraform.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name="Route table"
  }
}

#Associat route table 
resource "aws_route_table_association" "rt1" {
  subnet_id      = aws_subnet.sub1.id
  route_table_id = aws_route_table.rt.id
}

resource "aws_route_table_association" "rt2" {
  subnet_id      = aws_subnet.sub2.id
  route_table_id = aws_route_table.rt.id
}

#creating security group

resource "aws_security_group" "terraform_sg" {
  name        = "terraform_sg"
  vpc_id      = aws_vpc.Terraform.id

  ingress {
    description      = "HTTP from VPC"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
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
    Name = "terraform_sg"
  }
}

#creating S3 bucket

resource "aws_s3_bucket" "example" {
  bucket = "terraform-project-on-250923"
}

#creating an instantses 

resource "aws_instance" "host-1" {
  ami                     = "ami-0f5ee92e2d63afc18"
  instance_type           = "t2.micro"
  key_name                = "practice-key"
  vpc_security_group_ids  = [aws_security_group.terraform_sg.id]
  subnet_id               = aws_subnet.sub1.id
  user_data               = base64encode(file("userdata.sh"))

  tags = {
    Name = "host-1"
  }
}

resource "aws_instance" "host-2" {
  ami                     = "ami-0f5ee92e2d63afc18"
  instance_type           = "t2.micro"
  key_name                = "practice-key"
  vpc_security_group_ids  =  [aws_security_group.terraform_sg.id]
  subnet_id               = aws_subnet.sub2.id
  user_data               = base64encode(file("Zomato.sh"))

   tags = {
    Name = "host-2"
  }
}

#creating load balancer 

resource "aws_lb" "web_lb" {
  name               = "web-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.terraform_sg.id]
  subnets            = [aws_subnet.sub1.id , aws_subnet.sub2.id]

  tags = {
    Name = "web_lb"
  }
}

#creating target group

resource "aws_lb_target_group" "tg" {
  name     = "terraform-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.Terraform.id

  health_check {
    path = "/"
  }
}

#attaching target group to load balancer

resource "aws_lb_target_group_attachment" "attach-1" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.host-1.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "attach-2" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.host-2.id
  port             = 80
}

#creating lb_lisner

resource "aws_lb_listener" "terraform_lb" {
  load_balancer_arn = aws_lb.web_lb.arn
  port              = "80"
  protocol          = "HTTP"

    default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

output "loadbalancerdns" {
  value = aws_lb.web_lb.dns_name
}



