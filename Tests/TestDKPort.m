/* Unit tests for DKPort
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
#import <Foundation/NSConnection.h>
#import <UnitKit/UnitKit.h>

#import "DBusKit/DKPort.h"
#import "DBusKit/DKProxy.h"
#import "../Source/DKPort+Private.h"
#import "../Source/DKObjectPathNode.h"
@interface TestDKPort: NSObject <UKTest>
@end

@implementation TestDKPort
- (void)testReturnProxy
{
  NSConnection *conn = nil;
  id aProxy = nil;
  NSWarnMLog(@"This test is an expected failure if the session message bus is not available!");
  conn = [NSConnection connectionWithReceivePort: [DKPort port]
                                        sendPort: [[[DKPort alloc] initWithRemote: @"org.freedesktop.DBus"] autorelease]];
  aProxy = [conn rootProxy];
  UKNotNil(aProxy);
}

- (void)testObjectPathManagementRootObject
{
  DKPort *p = (DKPort*)[DKPort port];
  id obj = @"p";
  id<DKObjectPathNode> n = nil;
  [p _setObject: obj
         atPath: @"/"];
  n = [p _objectPathNodeAtPath: @"/"];
  UKNotNil(n);
  UKTrue(GSObjCIsKindOf(object_getClass(n),objc_getClass("DKOutgoingProxy")));
  UKObjectsEqual(n, [p _proxyForObject: obj]);
  UKObjectsEqual(p, [(DKOutgoingProxy*)n _port]);
  [p _setObject: nil
         atPath: @"/"];
}

- (void)testObjectPathManagementLeafObject
{
  DKPort *p = (DKPort*)[DKPort port];
  id obj = @"p";
  id<DKObjectPathNode> n = nil;
  id<DKObjectPathNode> innerNode = nil;
  [p _setObject: obj
         atPath: @"/org/gnustep/test/p"];
  n = [p _objectPathNodeAtPath: @"/org/gnustep/test/p"];
  innerNode = [p _objectPathNodeAtPath: @"/org/gnustep"];
  UKNotNil(n);
  UKNotNil(innerNode);
  UKTrue(GSObjCIsKindOf(object_getClass(n), objc_getClass("DKOutgoingProxy")));
  UKTrue(GSObjCIsKindOf(object_getClass(innerNode), objc_getClass("DKObjectPathNode")));
  UKObjectsEqual(n, [p _proxyForObject: obj]);
  UKObjectsEqual(p, [(DKOutgoingProxy*)n _port]);
  [p _unregisterAllObjects];
}



@end
