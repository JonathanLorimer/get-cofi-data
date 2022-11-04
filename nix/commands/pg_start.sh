# Initialise and Configure PostgresQL
init_db() {
  local PG_SOCKET_DIR="$1"
  local PG_DATADIR="$2"

  initdb -D "$PG_DATADIR"

  {
    # use this in builds (CI)
    #"unix_socket_directories = ${NIX_BUILD_TOP}"

    # use this locally
    # N.B.: wrap in single quotes
    echo "unix_socket_directories = $(echo "$PG_SOCKET_DIR" | sed -e "s/\(.*\)/'\1'/")"
    echo "shared_buffers = 128MB"
    echo "fsync = off"
    echo "full_page_writes = off"
  } >> "$PG_DATADIR/postgresql.conf"
}

# Start PostgresQL.
start_db() {
  local PG_SOCKET_DIR="$1"
  local PG_DATADIR="$2"
  pg_ctl start -D "$PG_DATADIR" -w # || (echo "pg_ctl failed"; exit 1)
}

# Check that PostgresQL is working and reachable.
check_db_green_status() {
  local PG_SOCKET_DIR="$1"
  local PG_DATADIR="$2"

  local NUM_TRIES=0
  local MAX_TRIES=10
  until psql postgres -h "$PG_SOCKET_DIR" -c "SELECT 1" > /dev/null 2>&1 ; do
    if [ "$NUM_TRIES" -gt "$MAX_TRIES" ]; then
      echo "Attempt to reach PostgresQL exceeded '${MAX_TRIES}'; Stopping."
      exit 1
    fi
    NUM_TRIES=$((NUM_TRIES + 1))
    echo "waiting for postgres..."
    # PostgresQL can potentially take a second or two to start up
    sleep 0.5
  done
}

setup_db_for_local_dev() {
  local PG_SOCKET_DIR="$1"
  local PG_SETUP_COMMANDS=(
    "CREATE DATABASE cofi_data"
    "CREATE USER cofi"
    "GRANT ALL PRIVILEGES ON DATABASE cofi_data TO cofi"
  )

  for SETUP in "${PG_SETUP_COMMANDS[@]}"; do
    psql postgres -h "$PG_SOCKET_DIR" -w -c "$SETUP"
  done
}

main() {
  local PG_SOCKET_DIR;
  #PG_SOCKET_DIR=".pgtmp"
  PG_SOCKET_DIR="$(mktemp -d)"
  local PG_DATADIR=".pgdata"

  # Catch failures and perform cleanup
  # N.B.: Using double quotes performs expansion now, which is what we want.
  #       Single quotes would result in delayed expansion, i.e., empty variables.
  trap "pg-stop ${PG_DATADIR}" ERR EXIT SIGINT SIGQUIT

  if test -d "$PG_DATADIR";
  then
    # TODO should we make it possible to persist?
    echo "Found local PostgresQL data directory '${PG_DATADIR}'. Deleting it and starting fresh."
    rm -rf "$PG_DATADIR"
  else
    echo "Didn't find local PostgresQL data directory '${PG_DATADIR}'. Initialisating DB."
  fi

  init_db "$PG_SOCKET_DIR" "$PG_DATADIR"
  start_db "$PG_SOCKET_DIR" "$PG_DATADIR"
  check_db_green_status "$PG_SOCKET_DIR" "$PG_DATADIR"
  setup_db_for_local_dev "$PG_SOCKET_DIR"

  echo "PostgresQL is running in ${PG_SOCKET_DIR}."

  # Remove signal catching so we can exit cleanly.
  trap - ERR EXIT SIGINT SIGQUIT
}

main
