
resource "aws_lb" "public" {
    name = "k8s-the-hard-way-${local.name}-lb"
    load_balancer_type = "network"

    subnet_mapping {
        subnet_id = aws_subnet.public.id
        allocation_id = aws_eip.public.id
    }
}

resource "aws_lb_target_group" "controllers" {
    name     = "k8s-the-hard-way-${local.name}-tg"
    port     = 6443
    protocol = "TCP"
    vpc_id   = aws_vpc.vpc.id
}

resource "aws_lb_target_group_attachment" "controller_attachment" {
    count            = 3
    target_group_arn = aws_lb_target_group.controllers.arn
    target_id        = aws_instance.controller[count.index].id
    port             = 6443
}

resource "aws_lb_listener" "controllers" {
    load_balancer_arn = aws_lb.public.arn
    port              = "6443"
    protocol          = "TCP"

    default_action {
        type             = "forward"
        target_group_arn = aws_lb_target_group.controllers.arn
    }
}
