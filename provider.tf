terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws     = { source = "hashicorp/aws", version = "~> 5.0" }
    archive = { source = "hashicorp/archive", version = "~> 2.4" }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  type    = string
  default = "eu-west-1"
}

variable "project_name" {
  type    = string
  default = "medcloud-finops"
}

variable "alert_email" {
  type    = string
  default = "nicolastesla404010@gmail.com"
}

variable "cpu_threshold_percent" {
  type    = number
  default = 5.0
}

variable "lookback_days" {
  type    = number
  default = 14
}
