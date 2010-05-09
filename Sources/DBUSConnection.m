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

#import "DBUSConnection.h"

#import "DBUSMessage.h"
#import "DBUSMessageReturn.h"
#import "DBUSProxy.h"

#import <Foundation/NSDebug.h>
#import <Foundation/NSException.h>
#import <Foundation/NSString.h>

@interface DBUSConnection (Private)

/**
 * Initializes the low level DBusConnection to be of type.
 */
- (BOOL) _busWithType: (DBusBusType)type;

@end

@interface DBUSSessionConnection : DBUSConnection

- (id) init;

@end

@implementation DBUSSessionConnection

- (id) init
{
  if (![self _busWithType: DBUS_BUS_SESSION])
    {
      RELEASE(self);
      return nil;
    }

  [super init];

  return self;
}

@end

@interface DBUSSystemConnection : DBUSConnection

- (id) init;

@end

@implementation DBUSSystemConnection

- (id) init
{
  if (![self _busWithType: DBUS_BUS_SYSTEM])
    {
      RELEASE(self);
      return nil;
    }

  [super init];

  return self;
}

@end

@implementation DBUSConnection

+ (id) connectionWithSessionBus
{
  return AUTORELEASE([[self alloc] initWithSessionBus]);
}

- (id) initWithSessionBus
{
  isa = [DBUSSessionConnection class];
  return [self init];
}

+ (id) connectionWithSystemBus
{
  return AUTORELEASE([[self alloc] initWithSystemBus]);
}

- (id) initWithSystemBus
{
  isa = [DBUSSystemConnection class];
  return [self init];
}

- (void) dealloc
{
  [self close];
  [super dealloc];
}

- (void) close
{
  if (conn)
  {
    //dbus_connection_close(conn);
    dbus_connection_unref(conn);
  }
}

- (DBUSMessageReturn *) sendWithReplyAndBlock: (DBUSMessageCall *)aMessage
                                      timeout: (int)milliseconds
{
  DBusMessage *msg;
  DBusMessage *reply;
  DBusError err;
  DBUSMessageReturn *ret;

  msg = [aMessage message];

  NSDebugLLog(@"DBUSConnection", @"Sending msg call %p\n", msg);
  NSDebugLLog(@"DBUSConnection", @"  Type %d\n", dbus_message_get_type(msg));
  NSDebugLLog(@"DBUSConnection", @"  Interface %s\n",
        dbus_message_get_interface(msg) ? dbus_message_get_interface(msg) : "");
  NSDebugLLog(@"DBUSConnection", @"  Path %s\n",
        dbus_message_get_path(msg) ? dbus_message_get_path(msg) : "");
  NSDebugLLog(@"DBUSConnection", @"  Member %s\n",
        dbus_message_get_member(msg) ? dbus_message_get_member(msg) : "");

  dbus_error_init(&err);
  if (NULL == (reply = dbus_connection_send_with_reply_and_block(conn, msg,
                                                        milliseconds, &err)))
    {
      const char *error;
      error = err.message;
      [NSException raise: @"DBUSMessageSendException"
                  format: [NSString stringWithUTF8String: error]];
      dbus_error_free(&err);
    }
  else
    {
      NSDebugLLog(@"DBUSConnection", @"Received reply %p\n", reply);
      NSDebugLLog(@"DBUSConnection", @"  Type %d\n",
                  dbus_message_get_type(reply));
    }

  ret = [[DBUSMessageReturn alloc] initWithMessage: reply];
  [ret autorelease];

  return (DBUSMessageReturn *)ret;
}

- (DBUSProxy *) objectWithName: (NSString *)pname
                          path: (NSString *)path
                     interface: (NSString *)interface
{
  DBUSProxy *proxy;

  proxy = [[DBUSProxy alloc] initForConnection: self
                                      withName: pname
                                          path: path
                                     interface: interface];

  return proxy;
}

- (BOOL) isConnected
{
  return (BOOL)dbus_connection_get_is_connected(conn);
}

- (BOOL) isAuthenticated
{
  return (BOOL)dbus_connection_get_is_authenticated(conn);
}

- (void) flush
{
  dbus_connection_flush(conn);
}

- (DBusConnection *) connection
{
  return conn;
}

@end

@implementation DBUSConnection (Private)

- (BOOL) _busWithType: (DBusBusType)type
{
  DBusError err;

  //initialise the errors
  dbus_error_init(&err);

  //connect to the bus and check for errors
  conn = dbus_bus_get(type, &err);
  if (dbus_error_is_set(&err))
    {
      const char *error;
      error = err.message;
      [NSException raise: @"DBUSConnectionErrorException"
                  format: [NSString stringWithUTF8String: error]];
      dbus_error_free(&err);
    }

  if (NULL == conn)
    {
      return NO;
    }

  return YES;
}

@end
