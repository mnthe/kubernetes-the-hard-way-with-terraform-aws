resource "aws_route" "pod_route" {
  count = 3

  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "10.200.${count.index}.0/24"
  instance_id            = aws_instance.worker[count.index].id
}
