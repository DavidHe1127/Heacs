# for vpc/subnets
provider "aws" {
  profile = "qq"
  region  = "ap-southeast-2"
}

# cluster
resource "aws_ecs_cluster" "dockerzon" {
  name = var.cluster

  tags = {
    Name = "dockerzon-cluster"
  }
}

# ecr repo
resource "aws_ecr_repository" "dockerzon-express" {
  name = "${var.cluster}-express"

  tags = {
    Name = "dockerzon-express-ecr-repo"
  }
}

resource "aws_ecr_repository" "dockerzon-nginx" {
  name = "${var.cluster}-nginx"

  tags = {
    Name = "dockerzon-nginx-ecr-repo"
  }
}

# container instance
module "instances" {
  source = "./ec2"

  instance_count = 2
  name           = var.app_name
  subnets        = [aws_subnet.private-subnet-2a.id, aws_subnet.private-subnet-2b.id]
  ami            = var.ami
  vpc_id         = aws_vpc.dockerzon-ecs-vpc.id
  alb_sg_id      = module.alb.sg_id
  cluster        = var.cluster
  key_name       = var.instance_key_name
}

# modules
module "alb" {
  source = "./alb"

  vpc_id         = aws_vpc.dockerzon-ecs-vpc.id
  vpc_name       = var.vpc_tag_name
  public_subnets = [aws_subnet.public-subnet-2a.id, aws_subnet.public-subnet-2b.id]
  target_count   = 2
  target_ids     = module.instances.instance_ids
  app_sg_id      = module.instances.app_sg_id
}

# subnets
resource "aws_subnet" "public-subnet-2a" {
  vpc_id                  = aws_vpc.dockerzon-ecs-vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-southeast-2a"
  map_public_ip_on_launch = true

  tags = {
    Name = "10.0.1.0/ap-southeast-2a"
  }
}

resource "aws_subnet" "public-subnet-2b" {
  vpc_id                  = aws_vpc.dockerzon-ecs-vpc.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "ap-southeast-2b"
  map_public_ip_on_launch = true

  tags = {
    Name = "10.0.3.0/ap-southeast-2b"
  }
}

resource "aws_subnet" "private-subnet-2a" {
  vpc_id            = aws_vpc.dockerzon-ecs-vpc.id
  cidr_block        = "10.0.5.0/24"
  availability_zone = "ap-southeast-2a"

  tags = {
    Name = "10.0.5.0/ap-southeast-2a"
  }
}

resource "aws_subnet" "private-subnet-2b" {
  vpc_id            = aws_vpc.dockerzon-ecs-vpc.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "ap-southeast-2b"

  tags = {
    Name = "10.0.4.0/ap-southeast-2b"
  }
}

# vpc
resource "aws_vpc" "dockerzon-ecs-vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    env  = "dev"
    app  = "dockerzon-ecs"
    Name = "dockerzon-ecs-vpc"
  }

}

# IGW
resource "aws_internet_gateway" "dockerzon-ecs-vpc-igw" {
  vpc_id = aws_vpc.dockerzon-ecs-vpc.id

  tags = {
    Name = "dockerzon-ecs-vpc-igw"
  }
}

# Route Table
# default route mapping vpc's cidr to local to allow communication
# between subnets is created implicitly and cannot be specified
resource "aws_route_table" "dockerzon-ecs-vpc-public-route" {
  vpc_id = aws_vpc.dockerzon-ecs-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.dockerzon-ecs-vpc-igw.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.dockerzon-ecs-vpc-igw.id
  }

  tags = {
    Name = "dockerzon-ecs-vpc-public-route"
  }
}

# Route Table association
resource "aws_route_table_association" "public-subnet-2a-route-link" {
  subnet_id      = aws_subnet.public-subnet-2a.id
  route_table_id = aws_route_table.dockerzon-ecs-vpc-public-route.id
}

resource "aws_route_table_association" "public-subnet-2b-route-link" {
  subnet_id      = aws_subnet.public-subnet-2b.id
  route_table_id = aws_route_table.dockerzon-ecs-vpc-public-route.id
}
