/* 
   Tester for d-bus
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
#include <Foundation/NSAutoreleasePool.h>
#include <AppKit/NSApplication.h>
#include <AppKit/NSMenu.h>
#include "DBUS.h"

@interface AppController: NSObject
{
}
@end

@implementation AppController

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
  NSMenu *menu = [NSMenu new];

  [menu addItemWithTitle: @"Send"
        action: @selector(doSend:)
        keyEquivalent: @"s"];
  [menu addItemWithTitle: @"Quit"
        action: @selector(terminate:)
        keyEquivalent: @"q"];
  [NSApp setMainMenu: menu];
  RELEASE(menu);
}

/*
- (void)doSend: (id) sender
{
  DBUSConnection *conn;
  DBUSProxy *obj;
  NSString *target = @"org.freedesktop.Hal";
  NSString *name = @"/org/freedesktop/Hal/devices/computer";
  NSString *interface = @"org.freedesktop.Hal.Device.SystemPowerManagement";
  NSString *myName = @"test.method.caller";

  conn = [[DBUSConnection alloc] init: YES];
  [conn openWithName: myName];

  obj = [conn getObjectWithTarget: target name: name andInterface: interface];
  [obj Suspend: 1];

  [conn close];
  RELEASE(conn);
}
*/

/*
- (void)doSend: (id) sender
{
  DBUSConnection *conn;
  DBUSProxy *obj;
  NSString *target = @"org.freedesktop.DBus";
  NSString *name = @"/org/freedesktop/DBus";
  NSString *interface = @"org.freedesktop.DBus";

  conn = [[DBUSConnection alloc] init: YES];

  obj = [conn getObjectWithTarget: target name: name andInterface: interface];
  [obj ListServices];

  [conn close];
  RELEASE(conn);
}
*/

- (void)doSend: (id) sender
{
  DBUSConnection *conn;
  DBUSProxy *obj;
  NSString *target = @"org.freedesktop.DBus";
  NSString *name = @"/org/freedesktop/DBus";
//  NSString *interface = @"org.freedesktop.DBus.Introspectable";
  NSString *interface = @"org.freedesktop.DBus";

  conn = [[DBUSConnection alloc] init: YES];

  obj = [conn getObjectWithTarget: target name: name andInterface: interface];
//  NSLog(@" %s", [obj Introspect]);
  NSLog(@" %s", [obj Hello]);

  [conn close];
  RELEASE(conn);
}

@end

int main (int argc, const char *argv[])
{
  CREATE_AUTORELEASE_POOL(pool);
  id app;

  app = [NSApplication sharedApplication];
  [app setDelegate: [AppController new]];
  [app run];
  RELEASE(pool);
  return 0;
}
