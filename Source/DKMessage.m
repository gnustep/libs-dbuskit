/** Implementation of the DKMessage class wrapping D-Bus messages

   Copyright (C) 2010 Free Software Foundation, Inc.

   Written by:  Niels Grewe <niels.grewe@halbordnung.de>
   Created: June 2010

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02111 USA.
   */

#import "DKMessage.h"

#import <Foundation/NSException.h>
#import "DKEndpoint.h"

#include <dbus/dbus.h>


@implementation DKMessage

- (id) initWithDBusMessage: (DBusMessage*)aMsg
               forEndpoint: (DKEndpoint*)anEndpoint
      preallocateResources: (BOOL)preallocate
{
  DBusConnection *connection = NULL;
  if (nil == (self = [super init]))
  {
    return nil;
  }

  if ((aMsg == NULL) || (anEndpoint == nil))
  {
    [self release];
    return nil;
  }

  ASSIGN(endpoint,anEndpoint);

  msg = aMsg;
  /* Reference the message so it won't disappear behind our back. */
  dbus_message_ref(msg);

  connection = [anEndpoint DBusConnection];
  if (connection == NULL)
  {
    [self release];
    return nil;
  }

  if (preallocate)
  {
    /* Preallocate the resources needed to send the message. */
    res = dbus_connection_preallocate_send(connection);

    if (res == NULL)
    {
      [self release];
      return nil;
    }
  }
  return self;
}

- (void) dealloc
{
  if (res != NULL)
  {
    dbus_connection_free_preallocated_send([endpoint DBusConnection], res);
    res = NULL;
  }
  if (msg != NULL)
  {
    dbus_message_unref(msg);
    msg = NULL;
  }
  [endpoint release];
  [super dealloc];
}

- (void) send
{
  if (res != NULL)
  {
    // We have preallocated resources and use those to send the message
    dbus_connection_send_preallocated([endpoint DBusConnection],
      res,
      msg,
      &serial);
    // The resources have been "consumed" so we set the pointer to NULL in order
    // not to double free it on dealloc time.
    res = NULL;
  }
  else
  {
    // If we were asked not to preallocate the resources, the send might fail,
    // so we need to check and raise an exception if necessary.
    BOOL couldSend = dbus_connection_send([endpoint DBusConnection],
      msg,
      &serial);
    if (NO == couldSend)
    {
      [NSException raise: @"DKDBusOutOfMemoryException"
                  format: @"Out of memory when sending D-Bus message"];
    }
  }

}

- (DBusMessage*) DBusMessage
{
  return msg;
}

- (NSUInteger)serial
{
  return serial;
}
@end;
