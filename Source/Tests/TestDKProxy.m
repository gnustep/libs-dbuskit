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
#import <Foundation/NSObject.h>
#import <UnitKit/UnitKit.h>
#define INCLUDE_RUNTIME_H
#include "../config.h"
#undef INCLUDE_RUNTIME_H

#import "../../Headers/DKProxy.h"
#import "../DKEndpoint.h"
#import "../../Headers/DKPort.h"

@interface DKProxy (Private)
- (SEL)_unmangledSelector: (SEL)selector
            boxingRequest: (BOOL*)shallBox
                interface: (NSString**)interface;
- (void)_buildMethodCache;
- (NSDictionary*)_interfaces;
@end

@interface TestDKProxy: NSObject <UKTest>
@end

@interface NSObject (FakeDBusSelectors)
- (NSString*)Introspect;
- (NSString*)GetId;
- (NSString*)Hello;
- (char*)GetNameOwner: (char*)name;
// Also declare the mangled variant:
- (char*)_DKNoBox_GetNameOwner: (char*)name;
@end

@implementation TestDKProxy
- (void)testSelectorUnmangling
{

  NSString *mangledString = @"_DKNoBox_DKIf_org_freedesktop_DBus_DKIfEnd_GetNameOwner:";
  SEL mangledSelector = 0;
  SEL unmangledSel = 0;
  BOOL shallBox = YES;
  NSString *interface = nil;
  NSConnection *conn = nil;
  id proxy = nil;
  NSWarnMLog(@"This test is an expected failure if the session message bus is not available!");
  conn = [NSConnection connectionWithReceivePort: [DKPort port]
                                        sendPort: [[DKPort alloc] initWithRemote: @"org.freedesktop.DBus"]];
  proxy = [conn rootProxy];
  [proxy _buildMethodCache];

  sel_registerName([mangledString UTF8String]);
  mangledSelector = NSSelectorFromString(mangledString);

  unmangledSel = [proxy _unmangledSelector: mangledSelector
                             boxingRequest: &shallBox
                                 interface: &interface];
  UKObjectsEqual(@"GetNameOwner:", NSStringFromSelector(unmangledSel));
  UKFalse(shallBox);
  UKObjectsEqual(@"org.freedesktop.DBus", interface);
}

- (void)testSendIntrospectMessage
{
  NSConnection *conn = nil;
  id aProxy = nil;
  id returnValue = nil;
  NSWarnMLog(@"This test is an expected failure if the session message bus is not available!");
  conn = [NSConnection connectionWithReceivePort: [DKPort port]
                                        sendPort: [[DKPort alloc] initWithRemote: @"org.freedesktop.DBus"]];
  aProxy = [conn rootProxy];
  returnValue = [aProxy Introspect];

  UKNotNil(returnValue);
  UKTrue([returnValue isKindOfClass: [NSString class]]);
  UKTrue([returnValue length] > 0);
}

- (void)testBuildMethodCache
{
  NSConnection *conn = nil;
  id aProxy = nil;
  NSDictionary *interfaces = nil;
  NSWarnMLog(@"This test is an expected failure if the session message bus is not available!");
  conn = [NSConnection connectionWithReceivePort: [DKPort port]
                                        sendPort: [[DKPort alloc] initWithRemote: @"org.freedesktop.DBus"]];
  aProxy = [conn rootProxy];
  [aProxy _buildMethodCache];
  interfaces = [aProxy _interfaces];
  UKNotNil(interfaces);
  UKTrue([interfaces count] > 0);
}

- (void)testSendGetId
{
  NSConnection *conn = nil;
  id aProxy = nil;
  id returnValue = nil;
  NSWarnMLog(@"This test is an expected failure if the session message bus is not available!");
  conn = [NSConnection connectionWithReceivePort: [DKPort port]
                                        sendPort: [[DKPort alloc] initWithRemote: @"org.freedesktop.DBus"]];
  aProxy = [conn rootProxy];
  returnValue = [aProxy GetId];
  UKNotNil(returnValue);
  UKTrue([returnValue isKindOfClass: [NSString class]]);
  UKTrue([returnValue length] > 0);
}

- (void)testExceptionOnSecondHello
{
  NSConnection *conn = nil;
  id aProxy = nil;
  NSWarnMLog(@"This test is an expected failure if the session message bus is not available!");
  conn = [NSConnection connectionWithReceivePort: [DKPort port]
                                        sendPort: [[DKPort alloc] initWithRemote: @"org.freedesktop.DBus"]];
  aProxy = [conn rootProxy];
  UKRaisesExceptionNamed([aProxy Hello], @"DKDBusMethodReplyException");
}

- (void)testUnboxedMethodCallMangled
{
  NSConnection *conn = nil;
  id aProxy = nil;
  char *returnValue = NULL;
  NSWarnMLog(@"This test is an expected failure if the session message bus is not available!");
  conn = [NSConnection connectionWithReceivePort: [DKPort port]
                                        sendPort: [[DKPort alloc] initWithRemote: @"org.freedesktop.DBus"]];
  aProxy = [conn rootProxy];
  returnValue = [aProxy _DKNoBox_GetNameOwner: "org.freedesktop.DBus"];
  UKTrue(NULL != returnValue);
}
@end
