locals {
  nginx_port = XXXXX
}

resource "aws_security_group_rule" "nginx" {
    type = "ingress"
    from_port = local.nginx_port
    to_port = local.nginx_port
    protocol = "tcp"

    cidr_blocks = ["0.0.0.0/0"]
    security_group_id = aws_security_group.external.id
}