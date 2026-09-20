# variables.tf
# Terraform convention: declare every configurable value here instead of
# hardcoding it in main.tf. Lets you reuse this code for staging/prod later
# by just changing values, not logic.

variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "eu-central-1" # Frankfurt — good if targeting Germany-based roles/clients
}

variable "project_name" {
  description = "Prefix used to name/tag every resource, so they're identifiable in the AWS console"
  type        = string
  default     = "devsecops-pipeline"
}

variable "instance_type" {
  description = "EC2 instance size. t3.medium is the minimum comfortable size to run Jenkins + Docker + k3s"
  type        = string
  default     = "t3.medium"
}

variable "my_ip" {
  description = "Your IP address in CIDR form, e.g. 41.226.12.5/32 — used to lock down SSH access to only you"
  type        = string
  # No default on purpose: you must pass this in (terraform.tfvars or -var flag).
  # Never default this to 0.0.0.0/0 (open to the world) for SSH.
}

variable "key_pair_name" {
  description = "Name of an existing EC2 key pair (create one in the AWS console first, under EC2 > Key Pairs)"
  type        = string
}
