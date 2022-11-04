# https://stackoverflow.com/a/13864829
PG_DATADIR=""
if [ -z "${1+x}" ]
then
  PG_DATADIR=".pgdata"
else
  PG_DATADIR="$1"
fi

# grep through current processes running by current user, check which one
# contains the PG_DATADIR we're using. Technically there could be multiple,
# so ideally we would check that there is only one, or, even more ideally;
# we'd just kill the pid of the one we spawned to begin with.
PG_INSTANCES_RUNNING="$(pgrep -u "$(whoami)" -fa -- -D | grep "$PG_DATADIR")"
if [ -n "$PG_INSTANCES_RUNNING" ]; then
  pg_ctl stop -D "$PG_DATADIR" -w -m immediate
fi

if [ -d "$PG_DATADIR" ]; then
  rm -rf "$PG_DATADIR"
fi
