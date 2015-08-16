#!/bin/sh
#
#  Copyright (C) 2015 Michael Richard <michael.richard@oriaks.com>
#
#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 2 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

#set -x

export DEBIAN_FRONTEND='noninteractive'
export TERM='linux'

_install () {
  [ -f /usr/bin/mongod ] && return 1

  apt-get update -q
  apt-get install -y mongodb pwgen

  sed -ir -f- /etc/mongodb.conf <<- EOF
	s|^[[:space:]#]*\(auth[[:space:]]*\)=.*$|\1= true|
	s|^[[:space:]#]*\(bind_ip[[:space:]]*\)=.*$|\1= 0.0.0.0|
	s|^[[:space:]#]*\(noauth[[:space:]]*\)=.*$|\1= false|
	s|^[[:space:]#]*\(nohttpinterface[[:space:]]*\)=.*$|\1= true|
	s|^[[:space:]#]*\(sslOnNormalPorts[[:space:]]*\)=.*$|#\1= true|
	s|^[[:space:]#]*\(sslPEMKeyFile[[:space:]]*\)=.*$|#\1= /etc/mongodb.pem|
EOF

  rm -rf /var/lib/mongodb/*

  return 0
}

_init () {
  if [ ! -d /var/lib/mongodb/journal ]; then
    install -o mongodb -g mongodb -m 755 -d /var/lib/mongodb
  fi

  [ -z "${MONGO_PASSWORD}" -a ! -f /root/.mongorc.js ] && MONGO_PASSWORD=`pwgen 32 1`

  if [ -n "${MONGO_PASSWORD}" ]; then
    install -o root -p root -m 600 /dev/null /root/.mongorc.js
    cat > /root/.mongorc.js <<- EOF
	db=db.getMongo().getDB("admin");
	db.auth("root","${MONGO_PASSWORD}");
EOF

    _post_init &
  fi

  exec /usr/bin/mongod --config /etc/mongodb.conf --smallfiles

  return 0
}

_manage () {
  _CMD="$1"
  [ -n "${_CMD}" ] && shift

  case "${_CMD}" in
    "db")
      _manage_db $*
      ;;
    *)
      _usage
      ;;
  esac

  return 0
}

_manage_db () {
  _CMD="$1"
  [ -n "${_CMD}" ] && shift

  case "${_CMD}" in
    "create")
      _manage_db_create $*
      ;;
    "edit")
      _manage_db_edit $*
      ;;
    *)
      _usage
      ;;
  esac

  return 0
}

_manage_db_create () {
  _DB="$1"
  [ -z "${_DB}" ] && return 1 || shift
  [ `echo "show dbs" | mongo --quiet localhost/admin | grep -c "^${_DB}[[:space:]]"` -ge 1 ] && return 1


  _USER="$1"
  [ -z "${_USER}" ] && _USER="${_DB}" || shift
  [ `echo "show users" | mongo --quiet "localhost/${_DB}" | grep -c "^${_USER}[[:space:]]"` -ge 1 ] && return 1

  _PASSWORD="$1"
  [ -z "${_PASSWORD}" ] && _PASSWORD=`pwgen 12 1` || shift

#  mongo --quiet --ssl localhost/admin <<- EOF
  mongo --quiet localhost/admin <<- EOF
	use ${_DB};
	db.addUser( { user: '${_USER}', pwd: '${_PASSWORD}', roles: [ 'dbAdmin', 'readWrite' ] } );
EOF

  echo "db: ${_DB}, user: ${_USER}, password: ${_PASSWORD}"

  return 0
}

_manage_db_edit () {
  _DB="$1"
  [ -z "${_DB}" ] && return 1 || shift
  [ `echo "show dbs" | mongo --quiet localhost/admin | grep -c "^${_DB}[[:space:]]"` -ge 1 ] || return 1

#  mongo --ssl "localhost/${_DB}"
  mongo "localhost/${_DB}"

  return 0
}

_shell () {
  exec /bin/bash

  return 0
}

_post_init () {
  sleep 15

#  mongo --quiet --ssl localhost/admin <<- EOF
  mongo --quiet localhost/admin <<- EOF
	db.addUser( { user: "root", pwd: "${MONGO_PASSWORD}", roles: [ "clusterAdmin", "dbAdminAnyDatabase", "readWriteAnyDatabase", "userAdminAnyDatabase" ] } )
EOF

  return 0
}

_usage () {
  cat <<- EOF
	Usage: $0 install
	       $0 init
	       $0 manage db create <database_name> [ <user_name> [ <password> ]]
	       $0 manage db edit <database_name>
	       $0 shell
EOF

  return 0
}

_CMD="$1"
[ -n "${_CMD}" ] && shift

case "${_CMD}" in
  "install")
    _install $*
    ;;
  "init")
    _init $*
    ;;
  "manage")
    _manage $*
    ;;
  "shell")
    _shell $*
    ;;
  *)
    _usage
    ;;
esac
