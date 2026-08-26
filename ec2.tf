# A minimal, cheap EC2 instance tagged as a clinical workload — purely to
# generate real idle CPU history so the waste scanner's idle-clinical-
# workload detection pass (and the Grafana dashboard) have something real
# to show, rather than only synthetic/mocked data.
#
# t3.micro left running idle costs roughly $0.01/hr (~$7.50/mo) — cheap
# enough for portfolio testing, but remember to `terraform destroy` this
# resource (or stop the instance) once you've captured what you need.

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

resource "aws_security_group" "test_workload" {
  name        = "${var.project_name}-test-workload-sg"
  description = "No inbound access needed - this instance exists purely to sit idle"
  vpc_id      = data.aws_vpc.default.id

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

resource "aws_instance" "Kribiform" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"
  subnet_id              = data.aws_subnets.default.ids[0]
  vpc_security_group_ids = [aws_security_group.test_workload.id]

  tags = {
    Name         = "${var.project_name}-Kribiform"
    WorkloadType = "fhir-server"
    Environment  = "dev"
  }
}

output "test_instance_id" {
  description = "Use this to confirm the idle-detector and Grafana pick it up"
  value       = aws_instance.Kribiform.id
}
