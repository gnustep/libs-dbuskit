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

#ifndef _DBUSConnection_H_
#define _DBUSConnection_H_

#import <Foundation/NSObject.h>

#include <dbus/dbus.h>

@class NSInvocation;
@class NSString;
@class DBUSMessage;
@class DBUSMessageCall;
@class DBUSMessageReturn;
@class DBUSProxy;

@interface DBUSConnection : NSObject
{
  DBusConnection *conn;
}

/**
 * Initializes a new instance capable of accessing the system bus. Please note
 * that the system bus is locked down by default, so some restrictions may
 * apply unless appropriate access control rules are in place.
 * May throw DBUSConnectionErrorException.
 */
+ (id) connectionWithSystemBus;

/**
 * Initializes an instance capable of accessing the system bus. Please note
 * that the system bus is locked down by default, so some restrictions may
 * apply unless appropriate access control rules are in place.
 * May throw DBUSConnectionErrorException.
 */
- (id) initWithSystemBus;

/**
 * Initializes a new instance capable of accessing the session bus.
 * May throw DBUSConnectionErrorException.
 */
+ (id) connectionWithSessionBus;

/**
 * Initializes an instance capable of accessing the session bus.
 * May throw DBUSConnectionErrorException.
 */
- (id) initWithSessionBus;

/**
 * Initializes a new instance for a private (peer to peer) connection.
 */
//- (id) initWithName: (NSString *)name;

/**
 * Returns the name by which this process' connection is known on the bus.
 */
//- (NSString *) name;

/**
 * Closes this connection to the remote host. It's called automatically when
 * dealloc'ing this object.
 */
- (void) close;

/**
 * Returns a proxy to the remote object given a name, path and interface.
 */
- (DBUSProxy *) objectWithName: (NSString *)name
                          path: (NSString *)path
                     interface: (NSString *)interface;

/**
 * Sends a message to the remote end and blocks while waiting for a reply.
 * May throw DBUSMessageSendException.
 */
- (DBUSMessageReturn *) sendWithReplyAndBlock: (DBUSMessageCall *)message
                                      timeout: (int)milliseconds;

/**
 * Returns whether the connection is currently connected.
 */
- (BOOL) isConnected;

/**
 * Returns whether the connection was authenticated.
 */
- (BOOL) isAuthenticated;

/**
 * Blocks execution until all the data in the message queue has been sent.
 */
- (void) flush;

/**
 * Returns the low level D-Bus connection object.
 */
- (DBusConnection *) connection;

@end

#endif // _DBUSConnection_H_
