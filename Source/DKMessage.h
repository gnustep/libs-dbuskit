/** Interface for the DKMessage class wrapping D-Bus messages

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

#import <Foundation/NSObject.h>

#include <dbus/dbus.h>
#include <stdint.h>
@class DKEndpoint;

/**
 * DKMessage is a superclass for specific types of D-Bus messages that can be
 * sent via D-Bus. Usually, you do not allocate instances of this class but use
 * the provided subclasses.
 */
@interface DKMessage: NSObject
{
  /**
   * The D-Bus message wrapped by this object.
   */
  DBusMessage *msg;

  /**
   * The endpoint via which the message will be sent.
   */
  DKEndpoint *endpoint;

  /**
   * D-Bus resources preallocated for sending the message.
   */
  DBusPreallocatedSend *res;

  /**
   * The serial number assigned to the message when it is sent.
   */
  uint32_t serial;
}

/**
 * Initializes the object so that the specified D-Bus message can be sent via
 * the endpoint specified. The caller can request the resources for sending the
 * message to be preallocated.
 */
- (id) initWithDBusMessage: (DBusMessage*)aMsg
               forEndpoint: (DKEndpoint*)anEndpoint
      preallocateResources: (BOOL)preallocate;

/**
 * Returns the D-Bus message represented by this object.
 */
- (DBusMessage*) DBusMessage;

/**
 * Sends the message via the endpoint.
 */
- (void) send;

/**
 * Returns the serial number assigned to the message upon sending it.
 */
- (NSUInteger)serial;
@end;
