terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.0.0"
}

provider "aws" {
  region = "us-east-2" # Change as needed
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true

  tags = {
    Name = "my-vpc"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-2a" # Change as needed
  map_public_ip_on_launch = true

  tags = {
    Name = "my-public-subnet"
  }
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-2a" # Change as needed

  tags = {
    Name = "my-private-subnet"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "my-internet-gateway"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "my-public-route-table"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "public" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Adjust for your IP for better security
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "my-public-sg"
  }
}

resource "aws_security_group" "private" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    security_groups  = [aws_security_group.public.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "my-private-sg"
  }
}

resource "aws_instance" "private_instance" {
  ami                    = "ami-00eb69d236edcfaf8" # Ensure this is a valid AMI ID for your region
  instance_type         = "t2.medium"
  subnet_id             = aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.private.id] # Use vpc_security_group_ids

  tags = {
    Name = "my-private-instance"
  }
}

output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_id" {
  value = aws_subnet.public.id
}

output "private_subnet_id" {
  value = aws_subnet.private.id
}

output "private_instance_id" {
  value = aws_instance.private_instance.id
}

# Fetch the CloudTrail service account
data "aws_cloudtrail_service_account" "saileela" {}

# Reference the existing S3 bucket using a data source
data "aws_s3_bucket" "bucket" {
  bucket = "saileela"
}

# Define the IAM policy to allow CloudTrail to log into the S3 bucket
data "aws_iam_policy_document" "allow_cloudtrail_logging" {
  statement {
    sid    = "PutBucketPolicyForCloudTrail"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = [data.aws_cloudtrail_service_account.saileela.arn]
    }

    actions   = ["s3:PutObject"]
    resources = ["${data.aws_s3_bucket.bucket.arn}/*"]  # Fixed the reference here
  }

  statement {
    sid    = "GetBucketAclForCloudTrail"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = [data.aws_cloudtrail_service_account.saileela.arn]
    }

    actions   = ["s3:GetBucketAcl"]
    resources = [data.aws_s3_bucket.bucket.arn]  # Fixed the reference here
  }
}

# Apply the policy to the S3 bucket
resource "aws_s3_bucket_policy" "allow_cloudtrail_logging" {
  bucket = data.aws_s3_bucket.bucket.id  # Fixed the reference here
  policy = data.aws_iam_policy_document.allow_cloudtrail_logging.json
}

