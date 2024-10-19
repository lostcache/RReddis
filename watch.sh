#!/bin/bash
BUILD_PID=0

terminate_build() {
    if [ $BUILD_PID -ne 0 ]; then
        kill $BUILD_PID 2> /dev/null
        wait $BUILD_PID 2> /dev/null
    fi
}

free_port() {
    PORT=6379
    PID=$(lsof -ti tcp:$PORT)
    if [ ! -z "$PID" ]; then
        echo "Port $PORT is in use by process $PID. Terminating process..."
        kill -9 $PID
    fi
}

start_build() {
    clear
    free_port
    zig build &
    ./zig-out/bin/rreddis &
    BUILD_PID=$!
}

start_build

fswatch -o ./src | while read -r event; do
    terminate_build
    start_build
done

