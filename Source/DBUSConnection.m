/* 
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

#include <Foundation/NSString.h>
#include "DBUS.h"
// For sleep()
#include <unistd.h>

@implementation DBUSConnection

- (BOOL) _getBus: (DBusBusType)type
{
  DBusError err;

  // initialiset the errors
  dbus_error_init(&err);

  // connect to the system bus and check for errors
  conn = dbus_bus_get(type, &err);
  if (dbus_error_is_set(&err)) 
    {
      NSLog(@"Connection Error (%s)\n", err.message); 
      dbus_error_free(&err);
    }

  if (NULL == conn) 
    { 
      return NO;
    }

  return YES;
}

- (id) init
{
  return [self init: NO];
}

- (id) init: (BOOL)system
{
    DBusBusType type;
  
  if (system)
    {
      type = DBUS_BUS_SYSTEM;
    }
  else
    {
      type = DBUS_BUS_SESSION;
    }

  if (![self _getBus: type])
    {
      RELEASE(self);
      return nil;
    }

  return self;
}

- (void) dealloc
{
  [self close];
  RELEASE(name);
  [super dealloc];
}

- (NSString*) name
{
  return name;
}

- (BOOL) _requestName: (NSString*)dname
{
  DBusError err;
  int ret;

  // initialiset the errors
  dbus_error_init(&err);

  // register our name on the bus, and check for errors
  ret = dbus_bus_request_name(conn, [dname UTF8String], 
                              DBUS_NAME_FLAG_REPLACE_EXISTING, &err);
  if (dbus_error_is_set(&err)) 
    {
      NSLog(@"Name Error (%s)\n", err.message); 
      dbus_error_free(&err);
    }

  if (DBUS_REQUEST_NAME_REPLY_PRIMARY_OWNER != ret) 
    {
      NSLog(@"Not owner error\n"); 
      return NO;
    }

  return YES;
}

- (BOOL) openWithName: (NSString*)rname
{
  // set watcher and timeout handler

  ASSIGN(name, rname);
  if (![self _requestName: [self name]])
    {
      return NO;
    }
  
  return YES;
}

- (void) close
{
  if (conn)
  {
    if (dbus_connection_get_is_connected(conn))
    {
      // Don't even try to handle errors.
      if (name != nil)
        {
          dbus_bus_release_name(conn, [[self name] UTF8String], NULL);
        }
      //dbus_connection_close(conn);
    }
    dbus_connection_unref(conn);
  }
}

- (DBUSProxy*) getObjectWithTarget: (NSString*)target 
                              name: (NSString*)pname
                      andInterface: (NSString*)interface
{
  DBUSProxy *proxy;

  proxy = [[DBUSProxy alloc] initForConnection: self
                             withTarget: target
                             name: pname
                             andInterface: interface];

  return proxy;
}

- (void) forwardInvocation: (DBUSMessage *)message
                invocation: (NSInvocation*)inv
{
  DBusMessage *msg;
  DBusPendingCall *pending;
  
  msg = [message msg];

  // send message and get a handle for a reply
  // -1 is default timeout
  if (!dbus_connection_send_with_reply(conn, msg, &pending, -1)) 
    {
      NSLog(@"Out Of Memory!\n"); 
      exit(1);
    }
  if (NULL == pending) 
    { 
      NSLog(@"Pending Call Null\n"); 
      exit(1); 
    }
  dbus_connection_flush(conn);
  
   // block until we recieve a reply
  dbus_pending_call_block(pending);
  
  // get the reply message
  msg = dbus_pending_call_steal_reply(pending);

  // free the pending message handle
  dbus_pending_call_unref(pending);

  message = [[DBUSMessage alloc] initWith: msg];
  [message getResultInto: inv];  

  RELEASE(message);
}

- (void) receive: (DBusMessage*) msg
{
  DBusMessageIter iter;
  DBusMessage *reply;
  dbus_uint32_t serial = 0;
  int current_type;

  // check this is a method call for the right interface & method
  //if (dbus_message_is_method_call(msg, "test.method.Type", "Method")) 

 dbus_message_iter_init(msg, &iter);
 while ((current_type = dbus_message_iter_get_arg_type(&iter)) != DBUS_TYPE_INVALID)
   {
     // get the arguments and build up an invocation
       
     dbus_message_iter_next(&iter);
     // FIXME

   }

  // make a local call

  // create a reply from the message
  reply = dbus_message_new_method_return(msg);

  // Fill the reply parameters

   // send the reply && flush the connection
   if (!dbus_connection_send(conn, reply, &serial)) {
      NSLog(@"Out Of Memory!\n"); 
      exit(1);
   }
   dbus_connection_flush(conn);

   // free the reply
   dbus_message_unref(reply);
}

- (void)receiveLoop
{
   DBusMessage *msg;

   // loop, testing for new messages
   while (1) {
      // non blocking read of the next available message
      dbus_connection_read_write(conn, 0);
      msg = dbus_connection_pop_message(conn);

      // loop again if we haven't got a message
      if (NULL == msg) { 
         sleep(1); 
         continue; 
      }
      
      [self receive: msg];

      // free the message
      dbus_message_unref(msg);
   }
}

@end

