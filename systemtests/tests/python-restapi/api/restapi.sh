#!/bin/bash

set -e
set -u

cd $(dirname "$BASH_SOURCE")
. ../environment
. ../environment-local

if [ "${PYTHONPATH:-}" ]; then
    export PYTHONPATH=${CMAKE_SOURCE_DIR}/rest-api/bareosRestapiModels/:$PYTHONPATH
else
    export PYTHONPATH=${CMAKE_SOURCE_DIR}/rest-api/bareosRestapiModels/
fi

start()
{
    printf "Starting bareos-restapi: "

    if lsof -i:$REST_API_PORT >/dev/null; then
        printf " FAILED (port $REST_API_PORT already in use)\n"
        exit 1
    fi

    $PYTHON_EXECUTABLE -m uvicorn bareos-restapi:app --port ${REST_API_PORT} > ../log/bareos-restapi.log 2>&1 &
    PID=$!
    
    WAIT=10
    while ! curl --silent ${REST_API_URL}/token >/dev/null; do
        if ! ps -p $PID >/dev/null; then
            printf " FAILED\n"
            exit 1
        fi

        WAIT=$[$WAIT-1]
        if [ "$WAIT" -le 0 ]; then
            printf " FAILED\n"
            exit 2
        fi

        printf "."
        sleep 1
    done
    echo $PID > api.pid
    printf " OK (PORT=${REST_API_PORT}, PID=$PID)\n"
}

stop()
{
  printf "Stopping bareos-restapi: "
  if [ -e api.pid ]; then
    PID=$(cat api.pid)
    kill $PID
    rm api.pid
    printf "OK\n"
    return
  fi
  printf "OK (already stopped)\n"
}

status()
{
  printf "bareos-restapi: "
  if ! lsof -i:$REST_API_PORT >/dev/null; then
    printf "not running\n"
    exit 1
  fi
  PORTPID=$(lsof -t -i:$REST_API_PORT)
  PID=$(cat api.pid)
  if [ "$PORTPID" != "$PID" ]; then
    printf "running with unexpected PID (expected PID=$PID, running PID=$PORTPID)\n"
    exit 1
  fi
  printf "running (PORT=${REST_API_PORT}, PID=$PID)\n"
  exit 0
}

case "$1" in
   start)
      start
      ;;

   stop)
      stop
      ;;

  restart)
      stop
      sleep 1
      start
      ;;

   status)
      status
      ;;

   *)
      echo "Usage: $0 {start|stop|restart|status}"
      exit 1
      ;;
esac

exit 0
