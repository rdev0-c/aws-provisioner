variable "ami" {
  description = "AMI ID for the instance"
  type        = string
}

variable "instance_type" {
  description = "Instance type for the EC2 instance"
  type        = string
}

variable "key_name" {
  description = "Key name for SSH access"
  type        = string
}

variable "availability_zone" {
  description = "Availability zone for the subnet"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "ssh_ingress_cidr" {
  description = "CIDR block for SSH access"
  type        = string
}

variable "name_tag" {
  description = "The name tag for the EC2 instance"
  type        = string
}
