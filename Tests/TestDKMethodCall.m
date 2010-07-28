/* Unit tests for DKMethodCall
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
#import <Foundation/NSInvocation.h>
#import <Foundation/NSMethodSignature.h>
#import <Foundation/NSString.h>
#import <UnitKit/UnitKit.h>

#import "../Headers/DKPort.h"
#import "../Headers/DKProxy.h"
#import "../Source/DKProxy+Private.h"
#import "../Source/DKInterface.h"
#import "../Source/DKMethodCall.h"
#import "../Source/DKMethod.h"

@interface TestDKMethodCall: NSObject <UKTest>
@end

@interface NSObject (FakeIntrospectionSelector)
- (NSString*)Introspect;
@end

@implementation TestDKMethodCall
- (void)testMethodCall
{
  NSConnection *conn = nil;
  id aProxy = nil;
  NSMethodSignature *sig = [NSMethodSignature signatureWithObjCTypes: "@8@0:4"];
  NSInvocation *inv = [NSInvocation invocationWithMethodSignature: sig];
  DKMethodCall *call = nil;
  id returnValue = nil;
  NSWarnMLog(@"This test is an expected failure if the session message bus is not available!");
  conn = [NSConnection connectionWithReceivePort: [DKPort port]
                                        sendPort: [[DKPort alloc] initWithRemote: @"org.freedesktop.DBus"]];
  aProxy = [conn rootProxy];
  [inv setTarget: aProxy];
  [inv setSelector: @selector(Introspect)];
  call = [[DKMethodCall alloc] initWithProxy: aProxy
                                      method: [_DKInterfaceIntrospectable methodForSelector: @selector(Introspect)]
                                  invocation: inv];
  UKNotNil(call);
  [call sendSynchronouslyAndWaitUntil: 0];

  UKDoesNotRaiseException([inv getReturnValue: &returnValue]);
  UKNotNil(returnValue);
  UKTrue([returnValue isKindOfClass: [NSString class]]);
  UKTrue([returnValue length] > 0);
}
@end
