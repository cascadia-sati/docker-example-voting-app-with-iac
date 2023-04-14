variable "swarm_manager_count" {
  description = "How many Swarm manager instances to deploy"
  type        = number
  default     = 3
}

variable "swarm_worker_count" {
  description = "How many Swarm worker instances to deploy"
  type        = number
  default     = 3
}

variable "swarm_ami" {
  type    = string
  default = "ami-00ad2436e75246bba"
}

variable "swarm_instance_type" {
  type    = string
  default = "t2.micro"
}

variable "swarm_ssh_public_key_file" {
  type    = string
  default = "~/.ssh/id_rsa.pub"
}

variable "swarm_security_group_name" {
  type    = string
  default = "swarm_security_group"
}

variable "lb_security_group_name" {
  type    = string
  default = "lb_security_group"
}
