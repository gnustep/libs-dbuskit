/* -*-objc-*-
  Language bindings for d-bus
  Copyright (C) 2007 Free Software Foundation, Inc.

  Written by: Fred Kiefer <FredKiefer@gmx.de>
  Modified by: Ricardo Correa <r.correa.r@gmail.com>
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

#import <DBUSServer.h>
#import <DBUSConnection.h>

#include <dbus/dbus.h>

#import <Foundation/NSDebug.h>
#import <Foundation/NSException.h>
#import <Foundation/NSString.h>

DBusHandlerResult _path_message_callback(DBusConnection *con,
                                         DBusMessage *msg,
                                         void *data)
{
  printf("Got message in callback %p\n", msg);
  printf("  Type %d\n", dbus_message_get_type(msg));
  printf("  Interface %s\n", dbus_message_get_interface(msg) ? dbus_message_get_interface(msg) : "");
  printf("  Path %s\n", dbus_message_get_path(msg) ? dbus_message_get_path(msg) : "");
  printf("  Member %s\n", dbus_message_get_member(msg) ? dbus_message_get_member(msg) : "");
  /* Will be de-refed in the DESTROY method */
  //dbus_message_ref(msg);

  return DBUS_HANDLER_RESULT_HANDLED;
}


void _path_unregister_callback(DBusConnection *con, void *data)
{
  printf("unregistering callback");
}

DBusObjectPathVTable _path_callback_vtable = {
    _path_unregister_callback,
    _path_message_callback,
    NULL,
    NULL,
    NULL,
    NULL
};

@implementation DBUSServer

+ (id) serverWithConnection: (DBUSConnection *)aConn
                       name: (NSString *)aName
{
  return AUTORELEASE([[self alloc] initWithConnection: aConn
                                                 name: aName]);
}

- (id) initWithConnection: (DBUSConnection *)aConn
                     name: (NSString *)aName
{
  conn = aConn;
  name = aName;

  [self requestName: aName];

  return [super init];
}

- (void) requestName: (NSString *)aName
{
  DBusError err;
  int reply;

  dbus_error_init(&err);
  if (!(reply = dbus_bus_request_name([conn connection],
                                      [aName UTF8String],
                                      0,
                                      &err)))
    {
      const char *error;
      error = err.message;
      [NSException raise: @"DBUSConnectionNameRequestException"
                  format: [NSString stringWithUTF8String: error]];
      dbus_error_free(&err);
    }
}

- (BOOL) registerCallback: (void *)callback
            forObjectPath: (NSString *)objPath
{
  BOOL res = YES;

  if (!(dbus_connection_register_object_path([conn connection],
                                             [objPath UTF8String],
                                             &_path_callback_vtable,
                                             callback)))
    {
      NSLog(@"failure when registering object path");
      res = NO;
    }

  return res;
}

- (DBUSConnection *) connection
{
  return conn;
}

/**
 * Returns the qualified name by which this service is known.
 */
- (NSString *) name
{
  return name;
}

@end
