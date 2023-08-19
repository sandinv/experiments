echo "etcdctl -w table --endpoints=\$ENDPOINTS endpoint status"
docker run --name etcdclient -it --rm \
    --env ALLOW_NONE_AUTHENTICATION=yes \
    --network etcd \
    -e ENDPOINTS=etcd-0:2379,etcd-1:2379,etcd-2:2379 \
    bitnami/etcd:3.5.9 bash

