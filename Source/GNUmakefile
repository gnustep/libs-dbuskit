#
#  GUI test apps 
#
#  Copyright (C) 2006 Free Software Foundation, Inc.
#
#   Written by: Fred Kiefer <FredKiefer@gmx.de>
#   Created: Febuary 2006
#
#  This file is part of the GNUstep X/RAW GUI Backend.
#
#  This library is free software; you can redistribute it and/or
#  modify it under the terms of the GNU Library General Public
#  License as published by the Free Software Foundation; either
#  version 2 of the License, or (at your option) any later version.
#
#  This library is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	 See the GNU
#  Library General Public License for more details.
#
#  You should have received a copy of the GNU Library General Public
#  License along with this library; see the file COPYING.LIB.
#  If not, write to the Free Software Foundation,
#  59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.

include $(GNUSTEP_MAKEFILES)/common.make

# The application to be compiled
#gcc dbus-example.c  -I /usr/include/dbus-1.0/ -ldbus-1 -o dbus-example
TEST_APP_NAME = dbus \

dbus_OBJC_FILES = DBUSConnection.m DBUSProxy.m DBUSMessage.m AppController.m

# The Resource files to be copied into the app's resources directory
dbus_RESOURCE_FILES = 

ADDITIONAL_OBJCFLAGS += -I /usr/include/dbus-1.0/
ADDITIONAL_LDFLAGS +=-ldbus-1

-include GNUmakefile.preamble

-include GNUmakefile.local

include $(GNUSTEP_MAKEFILES)/test-application.make

-include GNUmakefile.postamble
