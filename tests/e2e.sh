#!/bin/bash

set -e

declare -A started_containers

cleanup() {
    if [ ${#started_containers[@]} -gt 0 ]; then
        echo "Stopping all remaining containers: ${started_containers[@]}"
        docker container rm -f ${started_containers[@]}
    fi
    echo "Removing shared network"
    docker network rm wesher_test
}

docker network create wesher_test
trap cleanup EXIT

run_test_container() {
    local name=$1
    echo "Starting $name"
    shift
    local hostname=$1
    shift
    docker run -d --cap-add=NET_ADMIN --name ${name} --hostname ${hostname} -v $(pwd):/app --network=wesher_test costela/wesher-test "$@"
    started_containers[$name]=$name
}

stop_test_container() {
    echo "Stopping $1"
    docker container rm -f $1
    unset started_containers[$1]
}

test_3_node_up() {
    run_test_container test1-orig test1 --init
    run_test_container test2-orig test2 --join test1-orig
    run_test_container test3-orig test3 --join test1-orig

    sleep 3

    docker exec test1-orig ping -c1 -W1 test2 || (docker logs test1-orig; docker logs test2-orig; false)
    docker exec test1-orig ping -c1 -W1 test3 || (docker logs test1-orig; docker logs test3-orig; false)

    stop_test_container test3-orig
    stop_test_container test2-orig
    stop_test_container test1-orig
}

test_5_node_up() {
    run_test_container test1-orig test1 --init
    run_test_container test2-orig test2 --join test1-orig
    run_test_container test3-orig test3 --join test1-orig
    run_test_container test4-orig test4 --join test1-orig
    run_test_container test5-orig test5 --join test1-orig

    sleep 5

    docker exec test1-orig ping -c1 -W1 test2 || (docker logs test1-orig; docker logs test2-orig; false)
    docker exec test1-orig ping -c1 -W1 test3 || (docker logs test1-orig; docker logs test3-orig; false)
    docker exec test1-orig ping -c1 -W1 test4 || (docker logs test1-orig; docker logs test4-orig; false)
    docker exec test1-orig ping -c1 -W1 test5 || (docker logs test1-orig; docker logs test5-orig; false)

    stop_test_container test5-orig
    stop_test_container test4-orig
    stop_test_container test3-orig
    stop_test_container test2-orig
    stop_test_container test1-orig
}

test_node_restart() {
    run_test_container test1-orig test1 --init
    run_test_container test2-orig test2 --join test1-orig

    sleep 3

    docker stop test2-orig
    docker start test2-orig

    sleep 3

    docker exec test1-orig ping -c1 -W1 test2 || (docker logs test1-orig; docker logs test2-orig; false)

    stop_test_container test2-orig
    stop_test_container test1-orig
}

test_cluster_simultaneous_start() {
    run_test_container test1-orig test1 --join test2-orig,test3-orig
    run_test_container test2-orig test2 --join test1-orig,test3-orig
    run_test_container test3-orig test3 --join test1-orig,test2-orig

    sleep 3

    docker exec test1-orig ping -c1 -W1 test2 || (docker logs test1-orig; docker logs test2-orig; false)
    docker exec test1-orig ping -c1 -W1 test3 || (docker logs test1-orig; docker logs test3-orig; false)

    stop_test_container test3-orig
    stop_test_container test2-orig
    stop_test_container test1-orig
}

for test_func in $(declare -F | grep -Eo '\<test_.*$'); do
    echo "--- Running $test_func:"
    $test_func
    echo "--- OK"
done
