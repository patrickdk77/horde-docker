#! /bin/sh
#
# Docker entrypoint script to change UID/GID of Debian/Ubuntu Apache
#
set -eu

[ "${DEBUG:-}" = 'yes' ] && set -x

if [ ! -z "${IPS:-}" ]; then
  for i in $IPS; do
    ip addr add $i/32 dev lo
  done
fi

[ -n "${APACHE_GID:-}" ] && {
  groupmod --gid $APACHE_GID www-data
}

[ -n "${APACHE_UID:-}" ] && {
  usermod --uid $APACHE_UID www-data
}
exec "$@"
