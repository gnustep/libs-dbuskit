/** Declaration of private methods for DKPort.
   Copyright (C) 2012 Free Software Foundation, Inc.

   Written by:  Niels Grewe <niels.grewe@halbordnung.de>
   Created: March 2012

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

#import "DBusKit/DKPort.h"
#import "DKObjectPathNode.h"

@class DKOutgoingProxy, DKProxy, NSString;

@interface DKPort (DKPortPrivate)
- (DKOutgoingProxy*)_autoregisterObject: (id)obj
                             withParent: (DKProxy*)parent;

- (void)_setObject: (id)obj
            atPath: (NSString*)path;

- (id<DKObjectPathNode>)_objectPathNodeAtPath: (NSString*)path;
- (id<DKObjectPathNode>)_proxyForObject: (id)obj;
@end


