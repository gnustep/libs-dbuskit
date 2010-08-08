/** Interface for DKSignal class encapsulating D-Bus signal information.
   Copyright (C) 2010 Free Software Foundation, Inc.

   Written by:  Niels Grewe <niels.grewe@halbordnung.de>
   Created: July 2010

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

   <title>DKMethod class reference</title>
   */

#import "DKIntrospectionNode.h"
#include <dbus/dbus.h>
@class NSString, NSMutableArray, DKArgument;
@interface DKSignal: DKIntrospectionNode
{
  NSMutableArray *args;
}

- (void)addArgument: (DKArgument*)arg
          direction: (NSString*)direction;

/**
 * Returns a custom notification name if one was set for the signal.
 */
- (NSString*)notificationName;

/**
 * Registers the signal with the instance of DKNotificationCenter that is
 * responsible for the proxy that the signal descends from.
 */
- (void)registerWithNotificationCenter;
@end
