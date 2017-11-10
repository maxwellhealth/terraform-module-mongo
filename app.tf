# Variables
variable "bastion_security_group" {
  type        = "string"
  description = "Security group allowing access from Bastion host"
}

variable "key_name" {
  type        = "string"
  description = "key pair name used with new ec2 instances"
}

variable "instance_type" {
  type        = "string"
  description = "AWS EC2 instance type to use for creating cluster nodes"
  default     = "r4.2xlarge"
}

variable "replica_set_name" {
  type        = "string"
  description = "Mongo replica set name"
}

variable "root_vol_size" {
  type        = "string"
  description = "Space (in Gigabytes) to give to the instance root disk"
  default     = "24"
}

variable "vol_size" {
  type        = "string"
  description = "Space (in Gigabytes) to give to MongoDB"
  default     = "100"
}

# Data sources
data "aws_caller_identity" "current" {}

# find latest ami in your account named "mongo-*"
data "aws_ami" "mongo" {
  most_recent = true

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "owner-id"
    values = ["${data.aws_caller_identity.current.account_id}"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "block-device-mapping.volume-type"
    values = ["gp2"]
  }

  filter {
    name   = "name"
    values = ["mongo-*"]
  }
}

# generate a keyfile for mongo
resource "random_string" "mongo_key" {
  length  = 512
  special = false
}

data "template_file" "userdata" {
  template = "${file("${path.module}/templates/userdata.tmpl.yaml")}"

  vars {
    replica_set_name = "${lookup(var.replica_set_name, var.environment)}"
    mongo_key        = "${random_string.mongo_key.result}"
  }
}

resource "aws_launch_configuration" "mongo" {
  iam_instance_profile = "${aws_iam_instance_profile.mongo.id}"
  image_id             = "${data.aws_ami.mongo.id}"
  instance_type        = "${var.instance_type}"
  name_prefix          = "${var.environment}-mongo-"
  security_groups      = ["${aws_security_group.host.id}"]
  user_data            = "${data.template_file.userdata.rendered}"
  key_name             = "${var.key_name}"

  root_block_device {
    volume_type = "standard"
    volume_size = "${var.root_vol_size}"
  }

  ebs_block_device {
    device_name = "/dev/xvdg"
    volume_size = "${var.vol_size}"
    volume_type = "gp2"
    encrypted   = "true"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "mongo" {
  count                     = "${var.cluster_size}"
  name                      = "${var.environment}-mongo0${count.index + 1}"
  max_size                  = 1
  min_size                  = 1
  health_check_grace_period = 300
  health_check_type         = "EC2"
  launch_configuration      = "${aws_launch_configuration.mongo.id}"
  vpc_zone_identifier       = ["${element(var.private_subnets, count.index)}"]

  tag {
    key                 = "Environment"
    value               = "${var.environment}"
    propagate_at_launch = true
  }

  tag {
    key                 = "Name"
    value               = "${var.environment}-mongo0${count.index + 1}"
    propagate_at_launch = true
  }

  tag {
    key                 = "Platform"
    value               = "ots"
    propagate_at_launch = true
  }

  tag {
    key                 = "Role"
    value               = "database"
    propagate_at_launch = true
  }

  tag {
    key                 = "Service"
    value               = "core"
    propagate_at_launch = true
  }

  tag {
    key                 = "terraform"
    value               = "true"
    propagate_at_launch = true
  }

  enabled_metrics = [
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupMaxSize",
    "GroupMinSize",
    "GroupPendingInstances",
    "GroupStandbyInstances",
    "GroupTerminatingInstances",
    "GroupTotalInstances",
  ]
}

# security group for mongo hosts
resource "aws_security_group" "host" {
  name   = "${var.environment}-mongo-host"
  vpc_id = "${var.vpc_id}"

  tags = {
    Environment = "${var.environment}"
    Name        = "${var.environment}-mongo-host"
    Platform    = "ots"
    Role        = "database"
    Service     = "core"
    terraform   = "true"
  }
}

## allow outbound access from cluster
resource "aws_security_group_rule" "host_outbound" {
  type              = "egress"
  from_port         = "0"
  to_port           = "0"
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = "${aws_security_group.host.id}"
}

## allow all from the bastion
resource "aws_security_group_rule" "host_bastion" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = "${var.bastion_security_group}"
  security_group_id        = "${aws_security_group.host.id}"
}

## allow ssh inbound from load balancer to cluster
resource "aws_security_group_rule" "host_ssh" {
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  source_security_group_id = "${aws_security_group.balancer.id}"
  security_group_id        = "${aws_security_group.host.id}"
}

## allow mongo inbound from load balancer to cluster
resource "aws_security_group_rule" "host_mongo" {
  type                     = "ingress"
  from_port                = 27017
  to_port                  = 27017
  protocol                 = "tcp"
  source_security_group_id = "${aws_security_group.balancer.id}"
  security_group_id        = "${aws_security_group.host.id}"
}

## allow mongo to talk to itself
resource "aws_security_group_rule" "host_mongo_self" {
  type              = "ingress"
  from_port         = 27017
  to_port           = 27017
  protocol          = "tcp"
  self              = true
  security_group_id = "${aws_security_group.host.id}"
}
