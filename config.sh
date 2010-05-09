#!/bin/sh

PKG_CONFIG=`which pkg-config 2>/dev/null`
if [ -z "${PKG_CONFIG}" ]; then
   echo "pkg-config not found!"
   exit 1
fi

# dbus
${PKG_CONFIG} --exists dbus-1
if [ $? -ne 0 ]; then
   echo "dbus library required but not found!"
   exit 1
fi
DBUS_CFLAGS=`${PKG_CONFIG} --cflags dbus-1`
DBUS_LIBS="`${PKG_CONFIG} --libs dbus-1`"

# write config.make
echo "# config.make, generated at `date`" >config.make
echo "DBUS_CFLAGS=${DBUS_CFLAGS}" >>config.make
echo "DBUS_LIBS=${DBUS_LIBS}" >>config.make
echo "ADDITIONAL_CFLAGS+=\$(DBUS_CFLAGS)" >> config.make
echo "ADDITIONAL_LDFLAGS+=\$(DBUS_LIBS)" >> config.make

exit 0

