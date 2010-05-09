/* -*-objc-*- 
   Language bindings for d-bus
   Copyright (C) 2007 Free Software Foundation, Inc.

   Written by: Fred Kiefer <FredKiefer@gmx.de>
   Created: January 2007

   This file is part of the GNUstep Base Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Library General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
*/

#ifndef _DBUS_H_DBUSProxy

#include <Foundation/NSProxy.h>

@class NSString;
@class DBUSConnection;

@interface DBUSProxy: NSProxy
{
  DBUSConnection *conn;
  NSString *target;
  NSString *name;
  NSDictionary *interfaces;
  NSString *interface;
  Protocol *protocol;
}

- (id) initForConnection: (DBUSConnection *)connection
              withTarget: (NSString *)theTarget
                    name: (NSString *)theName
            andInterface: (NSString *)theInterface;
- (NSString*) target;
- (NSString*) name;
- (NSString*) interface;
- (void) setInterface: (NSString*)interface;
- (NSString*) interfaceForMethodName: (NSString*)name;
- (void) setProtocolForProxy: (Protocol*)aProtocol;
- (DBUSConnection*) connectionForProxy;

@end

//@interface DBUSProxy (org.freedesktop.DBus.Introspectable)
@interface DBUSProxy (Introspectable)
- (char*)Introspect;
@end

//@interface DBUSProxy (org.freedesktop.DBus)
@interface DBUSProxy (DBus)
- (int)RequestName: (char*)name : (int)id;
- (int)ReleaseName: (char*)name;
- (int)StartServiceByName: (char*)name : (int)id;
- (char*)Hello;
- (BOOL)NameHasOwner: (char*)name;
- (char**)ListNames;
- (char**)ListActivatableNames;
- (void)AddMatch: (char*)name;
- (void)RemoveMatch: (char*)name;
- (char*)GetNameOwner: (char*)name;

- (void)ReloadConfig;
@end

//@interface DBUSProxy (org.freedesktop.Hal.Device.SystemPowerManagement)
@interface DBUSProxy (SystemPowerManagement)
- (void)Suspend;
- (void)Reboot;
- (void)Shutdown;
@end

#endif // _DBUS_H_DBUSProxy
