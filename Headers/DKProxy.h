/** Interface for the DKProxy class representing D-Bus objects on the
    GNUstep side.
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

#import <Foundation/NSProxy.h>
#import <DBusKit/DKPort.h>

@class DKEndpoint, DKInterface, NSCondition, NSLock, NSString, NSMapTable, NSMutableArray, NSMutableDictionary;
@protocol NSCoding;

/**
 * The DKProxy class is used to send messages to D-Bus objects. Usually, you
 * don't create them yourself but by using the DKPort and NSConnection classes.
 */
@interface DKProxy: NSProxy <NSCoding>
{
  @private
  /**
   * The endpoint object used for communication with D-Bus.
   */
  DKEndpoint *endpoint;

  /**
   * The name of the service the object proxied by this instance of DKProxy.
   */
  NSString *service;

  /**
   * The object path identifying the object proxied.
   */
  NSString *path;

  /**
   *
   */
  NSMutableDictionary *interfaces;

  /**
   * The array of all direct children of the node.
   */
  NSMutableArray *children;

  /**
   * A reference to the interface that is marked active and will be preferred
   * for method resolution.
   */
  DKInterface *activeInterface;

  /**
   * The lock protecting modifications to the tables.
   */
  NSLock *tableLock;

  /**
   * The condition object ensures that state changes in the proxy can be
   * conducted in a snychronized manner.
   */
  NSCondition *condition;

  /**
   * Identifies the present state of the proxy.
   */
  NSInteger state;
}

+ (id) proxyWithEndpoint: (DKEndpoint*)anEndpoint
              andService: (NSString*)aService
                 andPath: (NSString*)aPath;

- (id) initWithEndpoint: (DKEndpoint*)anEndpoint
             andService: (NSString*)aService
                andPath: (NSString*)aPath;

/**
 * Checks whether the to proxies are attached to the same D-Bus service.
 */
- (BOOL) hasSameScopeAs: (DKProxy*)aProxy;

/**
 * D-Bus allows identically named methods to appear in multiple interfaces. By
 * default and in accordance with the D-Bus specification, DKProxy will call the
 * first available implementation unless you specify the interface. If you
 * usually call methods from a specific interface, you can designate the
 * interface as the primary one by calling -setPrimaryDBusInterface:.
 */
- (void)setPrimaryDBusInterface: (NSString*)anInterface;
@end


/**
 * The DKDBus class exposes the D-Bus objects specifically (i.e. the
 * "org.freedesktop.DBus" service). The instances returned by this class are
 * shared objects: Calling -setPrimaryDBusInterface: on them has no effect.
 */
@interface DKDBus: DKProxy

/**
 * Returns a reference to the org.freedesktop.DBus service on the bus specified
 * by type.
 */
+(id)busWithBusType: (DKDBusBusType)type;

/**
 * Returns a reference to the org.freedesktop.DBus service on the session
 * message bus.
 */
+(id)sessionBus;

/**
 * Returns a reference to the org.freedesktop.DBus service on the system
 * message bus.
 */
+(id)systemBus;
@end
