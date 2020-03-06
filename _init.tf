variable "cluster_size" {
  type        = string
  description = "Number of instances in the mongo cluster"
}

variable "environment" {
  type        = string
  description = "Environment/production tier"
}

variable "private_subnets" {
  type        = list(string)
  description = "List of private subnet IDs Mongo launches in"
}

variable "region" {
  type        = string
  description = "AWS region"
  default     = "us-east-1"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID of something we connect to somewhere"
}

provider "aws" {
  region = var.region
}

provider "random" {}

provider "template" {}
