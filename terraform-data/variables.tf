# Define variables.tf for storing variable declarations 

variable "aws_region" {
  description = "AWS region where resources will be provisioned"
  default     = "us-east-1"
}

variable "ecs_instance_type" {
  description = "Instance type for ECS cluster instances"
  default     = "t2.micro"
}

variable "database_engine" {
  description = "Database engine for RDS instance"
  default     = "postgres"
}

variable "database_instance_class" {
  description = "Instance class for RDS instance"
  default     = "db.t3.micro"
}

variable "database_username" {
  description = "Username for the database"
  default     = "prerit"
}
# cannot use admin as it is reserved word

variable "database_password" {
  description = "Password for the database"
  default     = "bhandari"
}

