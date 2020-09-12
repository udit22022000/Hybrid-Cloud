
//Provider

provider "aws"{
    region = "ap-south-1"
    profile = "Udit"
}

//creating VPC
resource "aws_vpc" "udit_vpc" {
  cidr_block       = "192.168.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "udit_vpc"
  }
}

//creating subnets
resource "aws_subnet" "udit_public_subnet" {
  vpc_id     = "${aws_vpc.udit_vpc.id}"
  cidr_block = "192.168.0.0/24"
  availability_zone = "ap-south-1a"
  map_public_ip_on_launch = true


  tags = {
    Name = "udit_public_subnet"
  }
}

resource "aws_subnet" "udit_private_subnet" {
  vpc_id     = "${aws_vpc.udit_vpc.id}"
  cidr_block = "192.168.100.0/24"
  availability_zone = "ap-south-1b"


  tags = {
    Name = "udit_private_subnet"
  }
}


//creating internet gateway and Routing Table

resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = "${aws_vpc.udit_vpc.id}"

  tags = {
    Name = "internet_gateway"
  }
}


resource "aws_route_table" "udit_route1" {
  vpc_id = "${aws_vpc.udit_vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.internet_gateway.id}"
  }

  tags = {
    Name = "udit_route1"
  }
}

resource "aws_route_table_association" "route_association1" {
  subnet_id      = aws_subnet.udit_public_subnet.id
  route_table_id = aws_route_table.udit_route1.id
}

//creating elastic ip

resource "aws_eip" "udit_elasticip"{
  vpc = true
}

//creating NAT Gateway and Route Table

resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = aws_eip.udit_elasticip.id
  subnet_id = aws_subnet.udit_public_subnet.id
  
  tags = {
    Name = "nat_gateway"
  }
}


resource "aws_route_table" "udit_route2" {
  vpc_id = "${aws_vpc.udit_vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_nat_gateway.nat_gateway.id}"
  }

  tags = {
    Name = "udit-route2"
  }
}

resource "aws_route_table_association" "route_association2" {
  subnet_id      = aws_subnet.udit_private_subnet.id
  route_table_id = aws_route_table.udit_route2.id
}


//key creation
resource "tls_private_key" "udit_key_pair"{
    algorithm = "RSA"
  }
 
resource "aws_key_pair" "udit_key"{
    key_name   = "udit33"
    public_key = tls_private_key.udit_key_pair.public_key_openssh
    
    depends_on = [
        tls_private_key.udit_key_pair
    ]
}


//creating Security groups
resource "aws_security_group" "wordpress_sg" {
  name        = "wordpress_sg"
  description = "Allow ssh, http and icmp"
  vpc_id      = "${aws_vpc.udit_vpc.id}"


  ingress {
    description = "Allow Icmp"
    from_port   = 1
    to_port     = 1
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

  }

  ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTP"
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
    Name = "wordpress_sg"
  }
}


resource "aws_security_group" "mysql_sg1" {
  name        = "mysql_sg1"
  description = "Allow wordpress"
  vpc_id      = "${aws_vpc.udit_vpc.id}"

  ingress {
    description = "Allow Wordpress"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    security_groups = [ "${aws_security_group.wordpress_sg.id}"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "mysql_sg1"
  }
}


resource "aws_security_group" "bastion_host_sg" {
  name        = "bastion_host_sg"
  description = "Allow ssh"
  vpc_id      = "${aws_vpc.udit_vpc.id}"

  ingress {
    description = "Allow SSH"
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
    Name = "bastion_host_sg"
  }
}


resource "aws_security_group" "mysql_sg2" {
  name        = "mysql_sg2"
  description = "Allow Bastion Host"
  vpc_id      = "${aws_vpc.udit_vpc.id}"

  ingress {
    description = "allow bastion host"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    security_groups = [ "${aws_security_group.bastion_host_sg.id}"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "mysql_sg2"
  }
}



//creating instances

resource "aws_instance" "wordpress_instance" {
  ami           = "ami-01b9cb595fc660622"
  instance_type = "t2.micro"
  subnet_id      = aws_subnet.udit_public_subnet.id
  associate_public_ip_address = true
  key_name   = "udit33"
  vpc_security_group_ids = [ "${aws_security_group.wordpress_sg.id}"]

  tags = {
    Name = "Wordpress Instance"
  }
}

resource "aws_instance" "mysql_instance" {
  ami           = "ami-0025b3a1ef8df0c3b"
  instance_type = "t2.micro"
  subnet_id      = aws_subnet.udit_private_subnet.id
  key_name   = "udit33"
  vpc_security_group_ids = [ "${aws_security_group.mysql_sg1.id}", "${aws_security_group.mysql_sg2.id}"]

  tags = {
    Name = "Mysql Instance"
  }
}

resource "aws_instance" "bastion_instance" {
  ami           = "ami-07a8c73a650069cf3"
  instance_type = "t2.micro"
  subnet_id      = aws_subnet.udit_public_subnet.id
  associate_public_ip_address = true
  key_name   = "udit33"
  vpc_security_group_ids = [ "${aws_security_group.bastion_host_sg.id}"]

  tags = {
    Name = "Bastion Host Instance"
  }
}
