/** Declaration of DKEndpoint class for integrating DBus into NSRunLoop.
   Copyright (C) 2010 Free Software Foundation, Inc.

   Written by:  Niels Grewe <niels.grewe@halbordnung.de>
   Created: May 2010

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

/**
 * DKEndpoint is used internally to manage the low level details of a connection
 * to a D-Bus peer. This can be a well known bus as well as some special peer.
 */
@interface DKEndpoint: NSObject
{
  DBusConnection *connection;
}
/**
 * Use this initializer to use a pre-existing DBusConnection. Please note that
 * this will increase the reference count of the connection. It will still need
 * to be unreferenced by calling code.
 */
- (id) initWithConnection: (DBusConnection*)conn;

- (id) initWithConnectionTo: (NSString*)endpoint;

- (id) initWithWellKnownBus: (DBusBusType)type;
@end

@interface DKSystemBusEndpoint: DKEndpoint;
- (id) init;
@end

@interface DKSessionBusEndpoint: DKEndpoint;
- (id) init;
@end
