##My Full-Stack Deployment Journey with AWS ECS ☁️

Deploying my Django app to ECS productionize my coding skills. Using Terraform I declaratively defined my entire infrastructure - VPC, subnets, security groups, ECS cluster and more.

A key part was containerizing my app and pushing the image to ECR. Linking ECS to pull from ECR automated my deployment process.

I then defined my ECS task which pulled the image from ECR. Linking a task definition to a service and auto scaling group allowed my containers to run on EC2 instances behind an ALB.

Seeing my app live and accessible was extremely rewarding. Containerizing, deploying with ECS and using Terraform gave me valuable experience delivery production applications on AWS.
