data "aws_availability_zones" "zones" {
  state = "available"
}

resource "aws_instance" "swarm_manager_instances" {
  ami                    = var.swarm_ami
  instance_type          = var.swarm_instance_type
  availability_zone      = data.aws_availability_zones.zones.names[count.index % length(data.aws_availability_zones.zones.names)]
  key_name               = aws_key_pair.swarm_server_key.id
  vpc_security_group_ids = [aws_security_group.swarm_security_group.id]
  tags = {
    "Name" = "swarm_manager_${count.index + 1}"
  }
  count = var.swarm_manager_count
}

resource "aws_instance" "swarm_worker_instances" {
  ami                    = var.swarm_ami
  instance_type          = var.swarm_instance_type
  availability_zone      = data.aws_availability_zones.zones.names[count.index % length(data.aws_availability_zones.zones.names)]
  key_name               = aws_key_pair.swarm_server_key.id
  vpc_security_group_ids = [aws_security_group.swarm_security_group.id]
  tags = {
    "Name" = "swarm_worker_${count.index + 1}"
  }
  count = var.swarm_worker_count
}

resource "aws_key_pair" "swarm_server_key" {
  public_key = file(var.swarm_ssh_public_key_file)
}

resource "aws_security_group" "swarm_security_group" {
  name = var.swarm_security_group_name

  ingress { # Inbound Voting App
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress { # Inbound Voting App
    from_port   = 5001
    to_port     = 5001
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress { # Inbound SSH
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress { # Outbound Internet
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress { # Internal Swarm Mgmt
    from_port = 2377
    to_port   = 2377
    protocol  = "tcp"
    self      = true
  }

  ingress { # Internal Swarm Container Network Discovery
    from_port = 7946
    to_port   = 7946
    protocol  = "tcp"
    self      = true
  }

  ingress { # Internal Swarm Container Ingress Network
    from_port = 4789
    to_port   = 4789
    protocol  = "udp"
    self      = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

output "swarm_manager_public_ips" {
  value = [for swarm_mgr in aws_instance.swarm_manager_instances : swarm_mgr.public_ip]
}

output "swarm_manager_names" {
  value = [for swarm_mgr in aws_instance.swarm_manager_instances : swarm_mgr.tags.Name]
}

output "swarm_worker_public_ips" {
  value = [
    for swarm_mgr in aws_instance.swarm_worker_instances : swarm_mgr.public_ip
  ]
}

output "swarm_worker_names" {
  value = [
    for swarm_mgr in aws_instance.swarm_worker_instances : swarm_mgr.tags.Name
  ]
}

# Generate inventory file for Ansible
resource "local_file" "ansible_hosts_cfg" {
  content = templatefile("${path.module}/templates/hosts.tftpl",
    {
      swarm_manager_ips   = aws_instance.swarm_manager_instances.*.public_ip
      swarm_manager_names = aws_instance.swarm_manager_instances.*.tags.Name
      swarm_worker_ips    = aws_instance.swarm_worker_instances.*.public_ip
      swarm_worker_names  = aws_instance.swarm_worker_instances.*.tags.Name
    }
  )
  filename = "../ansible/hosts.cfg"
}

