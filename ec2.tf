# A minimal, cheap EC2 instance tagged as a clinical workload — purely to
# generate real idle CPU history so the waste scanner's idle-clinical-
# workload detection pass (and the Grafana dashboard) have something real
# to show, rather than only synthetic/mocked data.
#
# t3.micro left running idle costs roughly $0.01/hr (~$7.50/mo) — cheap
# enough for portfolio testing.

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Uses the default VPC/subnet to avoid needing a full networking setup
# for what is just a throwaway test resource.
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "tls_private_key" "test_workload" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_key_pair" "test_workload" {
  key_name   = "${var.project_name}-test-workload-key"
  public_key = tls_private_key.test_workload.public_key_openssh
}

resource "local_file" "test_workload_pem" {
  content         = tls_private_key.test_workload.private_key_pem
  filename        = "${path.module}/${var.project_name}-test-workload-key.pem"
  file_permission = "0400"
}

resource "aws_security_group" "test_workload" {
  name        = "${var.project_name}-test-workload-sg"
  description = "No inbound access needed - this instance exists purely to sit idle"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-test-workload-sg"
  }
}

resource "aws_iam_role" "test_workload_role" {
  name = "${var.project_name}-test-workload-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "test_workload_ssm" {
  role       = aws_iam_role.test_workload_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "test_workload_profile" {
  name = "${var.project_name}-test-workload-profile"
  role = aws_iam_role.test_workload_role.name
}

resource "aws_instance" "test_fhir_server" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"
  subnet_id              = data.aws_subnets.default.ids[0]
  vpc_security_group_ids = [aws_security_group.test_workload.id]
  iam_instance_profile   = aws_iam_instance_profile.test_workload_profile.name
  key_name               = aws_key_pair.test_workload.key_name

  tags = {
    Name         = "${var.project_name}-test-fhir-server"
    WorkloadType = "fhir-server"
    Environment  = "dev"
  }
}

output "test_instance_id" {
  description = "Use this to confirm the idle-detector and Grafana pick it up"
  value       = aws_instance.test_fhir_server.id
}
