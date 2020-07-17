provider "aws" {
	region  = "ap-south-1"
	profile = "myprofile"
}

// Creating VPC
resource "aws_vpc" "vpc_proj3" {
  	cidr_block           = "192.168.0.0/16"
  	instance_tenancy     = "default"
	enable_dns_hostnames = true
  	tags = {
    		Name = "VPC-proj3"
  	}
}

// Creating subnet in 1a
resource "aws_subnet" "subnet1" {
  	vpc_id     	  	= "${aws_vpc.vpc_proj3.id}"
  	cidr_block 	 	= "192.168.0.0/24"
	availability_zone 	= "ap-south-1a"
	map_public_ip_on_launch = true
  	tags = {
    		Name = "Subnet1-1a-proj3"
  	}
}

// Creating subnet in 1b
resource "aws_subnet" "subnet2" {
  	vpc_id     	  	= "${aws_vpc.vpc_proj3.id}"
  	cidr_block 	 	= "192.168.1.0/24"
	availability_zone 	= "ap-south-1b"
  	tags = {
    		Name = "Subnet2-1b-proj3"
  	}
}

// Creating Internet Gateway for vpc
resource "aws_internet_gateway" "gw_proj3" {
  	vpc_id 	     = "${aws_vpc.vpc_proj3.id}"
	tags = {
    		Name = "IGW_proj3"
  	}
}

// Creating Route Table
resource "aws_route_table" "rt_proj3" {
  	vpc_id 		   = "${aws_vpc.vpc_proj3.id}"
  	route {
    		cidr_block = "0.0.0.0/0"
    		gateway_id = "${aws_internet_gateway.gw_proj3.id}"
  	}
  	tags = {
    		Name = "RT_proj3"
  	}
}

// Associating Route Table with the subnet to make it public
resource "aws_route_table_association" "rt_assos" {
  	subnet_id      = aws_subnet.subnet1.id
  	route_table_id = aws_route_table.rt_proj3.id
}

// Key Pair
resource "tls_private_key" "mykey" {
	algorithm = "RSA"
}

resource "aws_key_pair" "generated_key" {
	key_name   = "project3_key"
	public_key = tls_private_key.mykey.public_key_openssh

	depends_on = [
		tls_private_key.mykey
	]
}

resource "local_file" "key-file" {
	content = tls_private_key.mykey.private_key_pem
	filename = "project3_key.pem"
}

// Creating S.G. for WordPress
resource "aws_security_group" "sg_wordpress" {
  	name        = "allow_WordPress"
  	description = "Allow HTTP & SSH inbound traffic"
	vpc_id = "${aws_vpc.vpc_proj3.id}"
  	ingress {
		description = "SSH"
    		from_port   = 22
    		to_port     = 22
    		protocol    = "tcp"
    		cidr_blocks = ["0.0.0.0/0"]
  	}
  	ingress {
		description = "HTTP"
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
    		Name = "SG_WordPress"
  	}
}

// Creating S.G. for MySQL
resource "aws_security_group" "sg_mysql" {
	depends_on  = [
		aws_security_group.sg_wordpress
	]
  	name        = "allow_MySQL"
  	description = "Allow MySQL inbound traffic"
	vpc_id = "${aws_vpc.vpc_proj3.id}"
  	ingress {
		description = "MySQL"
    		from_port   = 3306
    		to_port     = 3306
    		protocol    = "tcp"
    		security_groups = ["${aws_security_group.sg_wordpress.id}"]
  	}
  	egress {
    	from_port   = 0
    	to_port     = 0
    	protocol    = "-1"
    	cidr_blocks = ["0.0.0.0/0"]
  	}
  	tags = {
    		Name = "SG_MySQL"
  	}
}

resource "aws_instance" "mysqlos" {
   	ami             = "ami-0019ac6129392a0f2"
   	instance_type   = "t2.micro"
   	key_name        = "${aws_key_pair.generated_key.key_name}"
   	security_groups = ["${aws_security_group.sg_mysql.id}" ]
   	subnet_id       = aws_subnet.subnet2.id
  	tags         = {
      		Name = "MySQL-OS"
	}
}

resource "aws_instance" "wpos" {
	depends_on = [
		aws_instance.mysqlos
	]
   	ami 		= "ami-000cbce3e1b899ebd"
   	instance_type   = "t2.micro"
   	key_name 	= "${aws_key_pair.generated_key.key_name}"
   	security_groups = ["${aws_security_group.sg_wordpress.id}"]
   	subnet_id 	= aws_subnet.subnet1.id
  	tags	     = {
      		Name = "WP-OS"
	}
}

resource "null_resource" "null_local" {
	depends_on = [
		aws_instance.wpos
	]
	provisioner "local-exec" {
    		command = "chrome ${aws_instance.wpos.public_ip}"
 	}
}