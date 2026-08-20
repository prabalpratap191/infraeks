resource "aws_iam_role" "irsa_role" {

  name = "${var.service_account}-role"
}
