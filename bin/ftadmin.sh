#!/bin/sh

  PIKE_ARGS=""

  cd `dirname $0`/..
  appdir=$PWD

  if [ x$FINS_HOME != "x" ]; then
    PIKE_ARGS="$PIKE_ARGS -M$FINS_HOME/lib -M$appdir/modules -M$appdir/client -DFINS_APPDIR=\"$appdir\""
  else
    echo "FINS_HOME is not defined. Define if you have Fins installed outside of your standard Pike module search path."
  fi

  ARG0=$1
  if [ x$ARG0 = "X" ]; then
    echo "$0: no command given."
    exit 1
  fi

  cd `dirname $0`/../..
  exec pike $PIKE_ARGS -x ftadmin $*
