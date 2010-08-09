/** Interface for DKPort for NSConnection integration.
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

#import <Foundation/NSPort.h>

@class DKEndpoint;


enum
{
  DKDBusSessionBus,
  DKDBusSystemBus,
  DKDBusBusTypeOther,
  DKDBusBusTypeMax,
};

typedef NSUInteger DKDBusBusType;

/**
 * DKPort is used by the Distributed Objects system to communicate with
 * D-Bus. Unless you have special needs, don't create DKPort instances
 * yourself, but use the interfaces provided by NSConnection instead.
 * The default +port message will return a port connected to the session bus.
 */
@interface DKPort: NSPort
{
  /** The endpoint doing the connection handling. */
  DKEndpoint *endpoint;

  /**
   * The remote side of the port. Will not be specified for peer-to-peer
   * connections bypassing the bus and for ports used in service connections.
   */
  NSString *remote;
}

/**
 * Returns a port to the specified message bus without any specified remote
 * side.
 */
+ (id)portForBusType: (DKDBusBusType)type;

/** Returns a port to the session message bus. */
+ (id)sessionBusPort;

/** Returns a port to the system message bus. */
+ (id)systemBusPort;

/**
 * Return a DKPort instance connected to the specified D-Bus peer on the session
 * message bus.
 */
- (id)initWithRemote: (NSString*)remote;

/**
 * Return a DKPort instance connected to the specified D-Bus peer on the
 * specified message bus.
 */
- (id)initWithRemote: (NSString*)remote
               onBus: (DKDBusBusType)bus;
@end
