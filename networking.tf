variable "dns_name" {
  type        = "string"
  description = "Hostname prefix for route53 record creation"
  default     = "mongo0"
}

variable "dns_zone" {
  type        = "string"
  description = "Route 53 zone id to create records in"
}

variable "mongo_security_group" {
  type        = "list"
  description = "list of security group ids to grant mongo access"
}

variable "ssh_security_group" {
  type        = "list"
  description = "list of security group ids to grant ssh access"
}

# security group for mongo front end
resource "aws_security_group" "balancer" {
  name   = "${var.environment}-mongo-balancer"
  vpc_id = "${var.vpc_id}"

  tags = {
    Environment = "${var.environment}"
    Name        = "${var.environment}-mongo-balancer"
    Platform    = "ots"
    Role        = "database"
    Service     = "core"
    terraform   = "true"
  }
}

## allow outbound access
resource "aws_security_group_rule" "bal_outbound" {
  type              = "egress"
  from_port         = "0"
  to_port           = "0"
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = "${aws_security_group.balancer.id}"
}

## external ssh access
resource "aws_security_group_rule" "bal_ssh" {
  count                    = "${length(var.ssh_security_group)}"
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  source_security_group_id = "${element(var.ssh_security_group, count.index)}"
  security_group_id        = "${aws_security_group.balancer.id}"
}

## mongo has to talk to itself
resource "aws_security_group_rule" "bal_mongo_self" {
  # Mongo necessary port range
  type                     = "ingress"
  from_port                = 27017
  to_port                  = 27017
  protocol                 = "tcp"
  source_security_group_id = "${aws_security_group.node.id}"
  security_group_id        = "${aws_security_group.balancer.id}"
}

## external mongo access
resource "aws_security_group_rule" "bal_mongo" {
  count                    = "${length(var.mongo_security_group)}"
  type                     = "ingress"
  from_port                = 27017
  to_port                  = 27017
  protocol                 = "tcp"
  source_security_group_id = "${element(var.mongo_security_group, count.index)}"
  security_group_id        = "${aws_security_group.balancer.id}"
}

# external access
resource "aws_elb" "mongo" {
  count                       = "${var.cluster_size}"
  name                        = "${var.environment}-mongo0${count.index + 1}"
  security_groups             = ["${aws_security_group.balancer.id}"]
  subnets                     = ["${element(var.private_subnets, count.index)}"]
  idle_timeout                = 1800
  connection_draining         = true
  connection_draining_timeout = 300
  internal                    = true

  listener {
    instance_port     = 27017
    instance_protocol = "tcp"
    lb_port           = 27017
    lb_protocol       = "tcp"
  }

  listener {
    instance_port     = 22
    instance_protocol = "tcp"
    lb_port           = 22
    lb_protocol       = "tcp"
  }

  health_check {
    healthy_threshold   = 3
    unhealthy_threshold = 2
    timeout             = 3
    target              = "TCP:22"
    interval            = 10
  }

  tags = {
    Environment = "${var.environment}"
    Name        = "${var.environment}-mongo0${count.index + 1}"
    Platform    = "ots"
    Role        = "database"
    Service     = "core"
    terraform   = "true"
  }
}

resource "aws_autoscaling_attachment" "mongo" {
  count                  = "${var.cluster_size}"
  autoscaling_group_name = "${element(aws_autoscaling_group.mongo.*.id, count.index)}"
  elb                    = "${element(aws_elb.mongo.*.id, count.index)}"
}

resource "aws_route53_record" "mongo" {
  count   = "${var.cluster_size}"
  zone_id = "${var.dns_zone}"
  name    = "${lookup(var.dns_name, var.environment)}${count.index + 1}"
  type    = "A"

  alias {
    name                   = "${element(aws_elb.mongo.*.dns_name, count.index)}"
    zone_id                = "${element(aws_elb.mongo.*.zone_id, count.index)}"
    evaluate_target_health = false
  }
}

output "security_group_id" {
  value = "${aws_security_group.balancer.id}"
}
