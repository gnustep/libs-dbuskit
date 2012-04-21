/** Interface for the DKOutgoingProxy class for vending objects to D-Bus.
   Copyright (C) 2012 Free Software Foundation, Inc.

   Written by:  Niels Grewe <niels.grewe@halbordnung.de>
   Created: January 2012

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

#import "DKProxy+Private.h"

@class NSRecursiveLock;
/**
 * Instance of the DKOutgoingProxy class are used to broker the exchange between
 * local objects and other clients on D-Bus.
 */
@interface DKOutgoingProxy : DKProxy
{
  @private
  /**
   * The represented object.
   */
  id object;

  /**
   * Determines whether the object is autoexported.
   */
  BOOL _DBusIsAutoExported;
  /**
   * Auto-exported objects need to be reference counted by D-Bus clients.
   */
   NSUInteger _DBusRefCount;

  NSRecursiveLock *busLock;
}
+ (id) proxyWithName: (NSString*)name
              parent: (id<DKObjectPathNode>)parentNode
              object: (id)anObject;

- (id)initWithName: (NSString*)name
            parent: (id<DKObjectPathNode>)parentNode
            object: (id)anObject;

/**
 * Queries the autoexporting state of the object.
 */
- (BOOL)_DBusIsAutoExported;

/**
 * Set the flag that determines whether the object counts as autoexported.
 */
- (void)_setDBusIsAutoExported: (BOOL)yesno;
/**
 * Returns the number of D-Bus clients claiming a reference to the proxied
 * object.
 */
- (NSUInteger)_DBusRefCount;

/**
 * Called to inform the proxy that a D-Bus client wants to keep an object
 * around.
 */
- (void)_DBusRetain;

/**
 * Called to inform the proxy that a D-Bus client no longer references this
 * object.
 */
- (void)_DBusRelease;



@end
