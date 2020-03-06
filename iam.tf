# IAM Role
data "aws_iam_policy_document" "ec2" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    effect = "Allow"
  }
}

resource "aws_iam_role" "mongo" {
  name               = "${var.environment}-mongo"
  assume_role_policy = data.aws_iam_policy_document.ec2.json
}

# IAM profile attached to the Mongo instances
resource "aws_iam_instance_profile" "mongo" {
  name = "${var.environment}-mongo"
  role = aws_iam_role.mongo.name
}

# data "aws_iam_policy_document" "mongo" {
#   statement {
#   }
# }

# # IAM role policy attached to the profile
# resource "aws_iam_role_policy" "mongo" {
#   name   = aws_iam_role.mongo.name
#   role   = aws_iam_role.mongo.id
#   policy = data.aws_iam_policy_document.mongo.json
# }
