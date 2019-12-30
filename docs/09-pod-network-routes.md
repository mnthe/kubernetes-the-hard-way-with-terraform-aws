# Provisioning Pod Network Routes

노드에 예약 된 Pod은 노드의 Pod CIDR 범위에서 IP 주소를받습니다. 이 시점에서 Pod은 네트워크 경로 누락으로 인해 다른 노드에서 실행중인 다른 Pod과 통신 할 수 없습니다.

이 챕터에서는 노드의 Pod CIDR 범위를 노드의 내부 IP 주소에 매핑하는 각 Worker 노드에 대한 경로를 만듭니다.

## The Routing Table

챕터 1에서 생성한 Route Table에 각 Worker 인스턴스를 위한 Route를 생성합니다

```terraform
resource "aws_route" "pod_route" {
    count = 3

    route_table_id = aws_route_table.public.id
    destination_cidr_block = "10.200.${count.index}.0/24"
    instance_id = aws_instance.worker[count.index].id
}
```
