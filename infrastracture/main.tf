terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}


provider "aws" {
  region = "eu-north-1"
}

resource "aws_vpc" "adewale_vpc" {
    cidr_block = "10.0.0.0/16"
    tags = {
        Name = "terraform-adewale-EC2-to-RDS-VPC"
    }
}

resource "aws_subnet" "public_subnet" {
  vpc_id     = aws_vpc.adewale_vpc.id
  availability_zone = "eu-north-1a"
  cidr_block = "10.0.1.0/24"
  tags = {
    Name = "terraform-adewale-Public Subnet"
  }
}

resource "aws_internet_gateway" "adewale_igw" {
  vpc_id = aws_vpc.adewale_vpc.id

  tags = {
    Name = "terraform-adewale-Internet Gateway for EC2-to-RDS VPC"
  }
}

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.adewale_vpc.id
  tags = {
    Name = "terraform-adewale-Public route_table"
  }
}

#public subnet associated with the subnet
resource "aws_route_table_association" "public-route-table-association" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_route_table.id
}

#routing internet to public subnet
resource "aws_route" "public_route" {
  route_table_id         = aws_route_table.public_route_table.id
  destination_cidr_block = "0.0.0.0/0"  # This is the default route for internet-bound traffic
  gateway_id             = aws_internet_gateway.adewale_igw.id
}

resource "aws_security_group" "adewale_sg_for_ec2" {
  name        = "allow_ssh"
  vpc_id      = aws_vpc.adewale_vpc.id

  ingress {
    description      = "TLS from VPC"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "grocery_mate_port"
    from_port        = 5000
    to_port          = 5000
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "http_access"
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
  }
}

resource "aws_instance" "adewale-ec2" {
    ami = "ami-0f50f13aefb6c0a5d"
    instance_type = "t3.micro"
    subnet_id = aws_subnet.public_subnet.id
    associate_public_ip_address = true
    tags = {
        Name = "terraform_adewale_EC2-for-RDS"
    }
    vpc_security_group_ids = [ aws_security_group.adewale_sg_for_ec2.id ]
}


resource "aws_subnet" "private_subnet_1" {
  vpc_id     = aws_vpc.adewale_vpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "eu-north-1a"
  tags = {
    Name = "terraform-adewale-private subnet"
  }
}

resource "aws_subnet" "private_subnet_2" {
  vpc_id     = aws_vpc.adewale_vpc.id
  cidr_block = "10.0.4.0/24"
  availability_zone = "eu-north-1b"
  tags = {
    Name = "terraform-adewale-private subnet"
  }
}

#private route table without internet
resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.adewale_vpc.id
  tags = {
    Name = "private route_table"
  }
}

#private subnet associated with the subnet
resource "aws_route_table_association" "private-route-table-association" {
  subnet_id      = aws_subnet.private_subnet_1.id
  route_table_id = aws_route_table.private_route_table.id
}

resource "aws_route_table_association" "private-route-table-association-2" {
  subnet_id      = aws_subnet.private_subnet_2.id
  route_table_id = aws_route_table.private_route_table.id
}


resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "my-db-subnet-group"
  subnet_ids = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id ]  #if multi AZ add another subnet
}

resource "aws_security_group" "sg_for_rds" {
  name        = "my-db-sg"
  vpc_id = aws_vpc.adewale_vpc.id
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    security_groups = [aws_security_group.adewale_sg_for_ec2.id]
  }
}

resource "aws_db_instance" "my_db_instance" {
  allocated_storage    = 20
  engine               = "postgres"
  engine_version       = "17.4"
  instance_class       = "db.t3.micro"
  db_name              = "grocerymate_db"
  username             = "grocery_user"
  password             = "12345"
  skip_final_snapshot  = true
  publicly_accessible = false
  db_subnet_group_name = aws_db_subnet_group.rds_subnet_group.name

    # Attach the DB security group
  vpc_security_group_ids = [aws_security_group.sg_for_rds.id]
    tags = {
        Name = "adewale_tf_ec2_to_postgres"
    }
}
