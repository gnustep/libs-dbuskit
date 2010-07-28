/** Interface for the DKObjectPathNode helper class.
   Copyright (C) 2010 Free Software Foundation, Inc.

   Written by:  Niels Grewe <niels.grewe@halbordnung.de>
   Created: Jly 2010

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

#import "DKIntrospectionNode.h"

@class DKInterface, DKObjectPathNode, NSMutableArray, NSMutableDictionary;

/**
 * The DKObjectPathNode protocol is implemented by classes representing objects
 * in a D-Bus object path (such as <code>DKProxy</code> and
 * <code>DKObjectPathNode</code>.
 */
@protocol DKObjectPathNode
- (void)_addInterface: (DKInterface*)interface;

- (void)_addChildNode: (DKObjectPathNode*)node;
@end;

@interface DKObjectPathNode: DKIntrospectionNode <DKObjectPathNode>
{
  NSMutableArray *children;
  NSMutableDictionary *interfaces;
}
@end
