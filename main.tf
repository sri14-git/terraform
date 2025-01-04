provider "aws" {
    region = "us-east-1"
    
}

#1. Create vpc 
resource "aws_vpc" "main" {
    cidr_block = "10.0.0.0/16"
    tags = {
      name = "mainvpc"
    }
  
}
#2. Create Internet Gateway
resource "aws_internet_gateway" "igw" {
    vpc_id = aws_vpc.main.id
    tags = {
      name = "maingateway"
    }
  
}   
#3. Create Custom Route Table
resource "aws_route_table" "main-route-table" {
    vpc_id = aws_vpc.main.id
    route  {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.igw.id
    }
     
  tags = {
    Name = "mainroutetable"
  }
}
  

#4. Create a Subnet 
resource "aws_subnet" "main-subnet-1" {
    vpc_id = aws_vpc.main.id
    cidr_block = "10.0.0.0/18"
    tags = {
      name = "mainsubnet"
    }
  
}
#5. Associate subnet with Route Table
resource "aws_route_table_association" "association" {
    subnet_id = aws_subnet.main-subnet-1.id
    route_table_id = aws_route_table.main-route-table.id
    
  
}
#6. Create Security Group to allow port 22,80,443
resource "aws_security_group" "allowweb" {
    vpc_id = aws_vpc.main.id
    name = "allow_all_HTTPS"
    description = "allow HTTPS in and SSH in"
  tags = {
    name = "allowaccess"
  }
}
resource "aws_vpc_security_group_ingress_rule" "allowhttps" {
    description = "allow https"
    security_group_id = aws_security_group.allowweb.id
    ip_protocol = "tcp"
    cidr_ipv4 = "10.0.0.0/16" #aws_vpc.cidr_block instead of typing manually we are using an object from aws_vpc to define in security group
    from_port = 443
    to_port = 443
}
resource "aws_vpc_security_group_ingress_rule" "allowssh" {
    ip_protocol = "tcp"
    security_group_id = aws_security_group.allowweb.id
    cidr_ipv4 = "0.0.0.0/0"
    description = "allows ssh"
    from_port = 22
    to_port = 22
  
}

resource "aws_vpc_security_group_egress_rule" "allow_all_trafficipv6" {
    security_group_id = aws_security_group.allowweb.id
  cidr_ipv6         = "::/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
  
}
#7. Create a network interface with an ip in the subnet that was created in step 4 

resource "aws_network_interface" "networkinterface" {
  subnet_id       = aws_subnet.main-subnet-1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allowweb.id]

  }

#8. Assign an elastic IP to the network interface created in step 7 
resource "aws_eip" "one" {
    vpc = true
    network_interface = aws_network_interface.networkinterface.id
    associate_with_private_ip = "10.0.1.50"
    depends_on = [ aws_internet_gateway.igw ]
  
}
#9. Create Ubuntu server and install/enable apache2
resource "aws_instance" "myinstance" {
    ami = "ami-01816d07b1128cd2d"
    instance_type = "t2.micro"
    availability_zone = "us-east-1b" #use where the network interface is created
    network_interface {
        device_index = 0
        network_interface_id = aws_network_interface.networkinterface.id

    }
    user_data = <<-EOF
        #!/bin/bash
        sudo apt update -y
        sudo apt install apache2 -y
        sudo systemctl start apache2
        sudo bash -c 'echo your first html server' > /var/www/html/index.html
        EOF
    tags = {
      name = "web-server"
    }


    
  
}

