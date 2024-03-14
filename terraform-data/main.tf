# Create a directory for your Terraform project.
# Inside this directory, create a file named main.tf where you'll define your Terraform configuration.
# Write Terraform code to provision the necessary AWS resources such as ECS Cluster, Load Balancer, RDS (Relational Database Service), etc. Make sure to use Terraform AWS provider and appropriate modules.
# Define variables.tf for storing variable declarations and values.tf for storing hard-coded values.

# ECR repo has been created using # aws ecr create-repository --repository-name test-repo     
#aws ecr describe-repositories     ----- to see repositories                                                                                              

# See the location(regions like: us-east-1) , keep in mind about it and also allow IAM permission for user AmazonEC2ContainerRegistryFullAccess this should be given                                        


# terraform init
# terraform apply


# Additionally IAm role called as AmazonEC2ContainerServiceforEC2Role was created in Iam Management console and attached it to individual Instances in Management console form Actions> Security> Manage Iam role
#AmazonEC2ContainerServiceforEC2Role and AmazonEC2ContainerServiceAutoscaleRole policies were added to it

provider "aws" {
  region = var.aws_region

}

# Define your ECR repository data source to fetch the repository URI
data "aws_ecr_repository" "test_repo" {
  name = "test-repo" # this is the name of repo which is createed exclusively in ecr from aws console

}

# Creating resources, so that i can create vpc,subnets,etc. from terraform only
# and manage them here accordingly. If there already exists subnets, vpc, we can use that
# accordingly.


#Creating task definition for ECS Service -- So that to link the ecr repo with ecs
resource "aws_ecs_task_definition" "my_task_definition" {
  family = "my-task-family"
  container_definitions = jsonencode([{
    name   = "my-terraform-test-container"
    image  = "${data.aws_ecr_repository.test_repo.repository_url}:latest" # Fetch the ECR repository URI
    cpu    = 256
    memory = 512
    portMappings = [{
      containerPort = 80
      hostPort      = 80
      protocol      = "tcp"
    }]
  }])
}

# resource "aws_instance" "ecs_instances" {
#   count         = 2
#   ami           = "ami-0f0f215a5d51635e3"
#   instance_type = "t2.micro"
#   subnet_id     = aws_subnet.subnet_a.id

#   tags = {
#     Name = "ecs-instance-${count.index}"
#   }

#   # Add user data to install and configure ECS agent
#   user_data = <<-EOF
#               #!/bin/bash
#               echo ECS_CLUSTER=${module.ecs.this_ecs_cluster_name} >> /etc/ecs/ecs.config
#               systemctl start ecs
#               EOF


# }

# # --- ECS Capacity Provider ---
# connect the ECS Cluster to the ASG group so that the cluster can use EC2 instances to deploy containers.

resource "aws_ecs_capacity_provider" "main" {
  name = "terraformtest-ecs-ec2"

  auto_scaling_group_provider {
    auto_scaling_group_arn         = aws_autoscaling_group.ecs_asg.arn
    managed_termination_protection = "DISABLED"

    managed_scaling {
      maximum_scaling_step_size = 2
      minimum_scaling_step_size = 1
      status                    = "ENABLED"
      target_capacity           = 100
    }
  }
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name       = module.ecs.this_ecs_cluster_name
  capacity_providers = [aws_ecs_capacity_provider.main.name]

  default_capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.main.name
    base              = 1
    weight            = 100
  }
}
#Create an ECS Service
resource "aws_ecs_service" "my_ecs_service" {
  name    = "my-ecs-service"
  cluster = module.ecs.this_ecs_cluster_id
  #The task_definition attribute references an existing task definition named my_task_definition.
  # This task definition defines the Docker container configurations, including the image to use and resource allocations.
  task_definition = aws_ecs_task_definition.my_task_definition.arn
  desired_count   = 1
  launch_type     = "EC2" # or "FARGATE" depending on your setup

  # network_configuration {
  #   # Subnets where the service tasks will be launched
  #   subnets          = [aws_subnet.subnet_a.id, aws_subnet.subnet_b.id]
  #   security_groups  = [aws_security_group.ecs_sg.id]
  #   assign_public_ip = true

  # }

  # load_balancer {
  #   target_group_arn = module.alb.this_lb_arn
  #   container_name = 
  # }

}

# Launch template

resource "aws_launch_template" "ecs_launch_template" {
  name_prefix = "ecs-launch-template-"
  #aws ec2 describe-images --owners amazon --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*" "Name=virtualization-type,Values=hvm" "Name=root-device-type,Values=ebs" --query 'Images[*].[ImageId, Name]' --region us-east-1
  image_id      = "ami-0f0f215a5d51635e3" # Specify your desired AMI ID  (should be ecs-optimized ami, so not required to individually go to instances, ssh to them and register for ecs.) Can get through #aws ssm get-parameters --names /aws/service/ecs/optimized-ami/amazon-linux-2/recommended
  instance_type = "t2.micro"              # Specify your desired instance type
  key_name      = "key-ssh"               # Specify your key pair name. This is required inorder to ssh . Key pair should be there in specied zone like in us-east-1 you need to create key-pair first and write its name here
  # iam_instance_profile {
  #   name = aws_iam_instance_profile.ecs_instance_profile.name # Specify the IAM instance profile name
  # }
  # user_data = file("user_data.sh") # Optionally provide user data scriptye

  # assigning public ip addresses for our ec2 instances inorder to communicate
  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.ecs_sg.id]

  }

  # Add user data to install and configure ECS agent
  user_data = base64encode(<<-EOF
              #!/bin/bash
              echo ECS_CLUSTER=${module.ecs.this_ecs_cluster_name} >> /etc/ecs/ecs.config
              sudo systemctl enable ecs
              sudo systemctl start ecs
              EOF
  )
}


#  to manage the EC2 instances for our ECS cluster,
resource "aws_autoscaling_group" "ecs_asg" {
  name                = "ecs-asg"
  min_size            = 1                                                # Minimum number of instances
  max_size            = 5                                                # Maximum number of instances
  desired_capacity    = 2                                                # Desired number of instances
  vpc_zone_identifier = [aws_subnet.subnet_a.id, aws_subnet.subnet_b.id] # Subnets where instances should be launched
  launch_template {
    id      = aws_launch_template.ecs_launch_template.id # Launch template to use for launching instances
    version = "$Latest"                                  # Use the latest version of the launch template
  }
  tag {
    key                 = "Name"
    value               = "ecs-instance-terraformtest"
    propagate_at_launch = true
  }


}


resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "terraform-test-vpc"
  }

}

# Internet Gateway 
resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.main.id

}

#Creating route tables for public subnet
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id


  # this is required so that routes for subnet becomes public otherwise only local subnets can access each of them
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_igw.id

  }

  tags = {
    Name = "Terraform test public route table"
  }

}

# VPC is required before creating subnets, as we need their ids
resource "aws_subnet" "subnet_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  tags = {
    Name = "terraform-test-subneta"
  }

  map_public_ip_on_launch = true

}

resource "aws_subnet" "subnet_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"
  tags = {
    Name = "terraform-test-subnetb"
  }
  map_public_ip_on_launch = true

}

# Associate subnets with the public route table
resource "aws_route_table_association" "subnet_a_association" {
  subnet_id      = aws_subnet.subnet_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "subnet_b_association" {
  subnet_id      = aws_subnet.subnet_b.id
  route_table_id = aws_route_table.public.id
}

# Resource for ECS --- Security group (For load balancers required)

resource "aws_security_group" "ecs_sg" {
  name        = "terraform-test-sg"
  description = "Security group for ECS Cluster terraform test"
  vpc_id      = aws_vpc.main.id

  # its required to pull image to start service later
  egress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow inbound traffic from ALB
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow inbound traffic from ALB
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow inbound traffic on ports 51678 and 51679 for ECS communication
  ingress {
    from_port   = 51678
    to_port     = 51679
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


# Modules



module "ecs" {

  source  = "terraform-aws-modules/ecs/aws"
  version = "~> 2.0"

  name = "my-ecs-cluster"



  # Instead of specifying instance_type, you can configure the capacity provider strategy

  # capacity_providers = ["FARGATE"]

  # default_capacity_provider_strategy = {
  #   capacity_provider = "FARGATE"
  #   base              = 0
  #   weight            = 1
  # }



}




# Application Load Balancer
module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 5.0"

  name               = "my-alb"
  load_balancer_type = "application" # network and application load balancers types
  security_groups    = [aws_security_group.ecs_sg.id]
  subnets            = [aws_subnet.subnet_a.id, aws_subnet.subnet_b.id]
}

#RDS Database

module "rds" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 3.0"

  identifier     = "terraform-test-rds-instance" #name for rds instance
  engine         = var.database_engine
  instance_class = var.database_instance_class
  subnet_ids     = [aws_subnet.subnet_a.id, aws_subnet.subnet_b.id]
  # vpc_security_group_ids = aws_security_group.ecs_sg.id
  # name                   = "terraform-test-database"
  allocated_storage = 100 #in GB storage
  family            = "postgres16"
  username          = var.database_username
  password          = var.database_password
}
