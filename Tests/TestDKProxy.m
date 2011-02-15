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
#include "../Source/config.h"
#undef INCLUDE_RUNTIME_H

#import "DBusKit/DKProxy.h"
#import "../Source/DKEndpoint.h"
#import "DBusKit/DKPort.h"
#import "DBusKit/NSConnection+DBus.h"

#import <Foundation/NSArray.h>
#import <Foundation/NSException.h>
#import <Foundation/NSThread.h>

#include <unistd.h>

@interface DKProxy (Private)
- (SEL)_unmangledSelector: (SEL)selector
                interface: (NSString**)interface;
- (void)DBusBuildMethodCache;
- (NSDictionary*)_interfaces;
@end

@interface TestDKProxy: NSObject <UKTest>
@end

@interface NSObject (FakeDBusSelectors)
- (NSString*)Introspect;
- (NSString*)GetId;
- (NSString*)Hello;
- (NSString*)ListNames;
- (char*)GetNameOwner: (char*)name;
- (BOOL)NameHasOwner: (NSString*)name;
@end

@implementation DKProxy (ArpWrapping)

- (void)arpWrappedNameHasOwner: (NSString*)name
{
  NSAutoreleasePool *arp = [[NSAutoreleasePool alloc] init];
  NS_DURING
  {
    UKTrue([(id)self NameHasOwner: name]);
  }
  NS_HANDLER
  {
    NSLog(@"Got exception: %@", localException);
    UKFail();
  }
  NS_ENDHANDLER
  [arp release];
  [NSThread exit];
}
@end


@implementation TestDKProxy
- (void)testSelectorUnmangling
{

  NSString *mangledString = @"_DKIf_org_freedesktop_DBus_DKIfEnd_GetNameOwner:";
  SEL mangledSelector = 0;
  SEL unmangledSel = 0;
  NSString *interface = nil;
  NSConnection *conn = nil;
  id proxy = nil;
  NSWarnMLog(@"This test is an expected failure if the session message bus is not available!");
  conn = [NSConnection connectionWithReceivePort: [DKPort port]
                                        sendPort: [[[DKPort alloc] initWithRemote: @"org.freedesktop.DBus"] autorelease]];
  proxy = [conn rootProxy];

  // Call a method to trigger cache generation:
  [proxy NameHasOwner: @"org.freedesktop.DBus"];

  sel_registerName([mangledString UTF8String]);
  mangledSelector = NSSelectorFromString(mangledString);

  unmangledSel = [proxy _unmangledSelector: mangledSelector
                                 interface: &interface];
  UKObjectsEqual(@"GetNameOwner:", NSStringFromSelector(unmangledSel));
  UKObjectsEqual(@"org.freedesktop.DBus", interface);
}

- (void)testSendIntrospectMessage
{
  NSConnection *conn = nil;
  id aProxy = nil;
  id returnValue = nil;
  NSWarnMLog(@"This test is an expected failure if the session message bus is not available!");
  conn = [NSConnection connectionWithReceivePort: [DKPort port]
                                        sendPort: [[[DKPort alloc] initWithRemote: @"org.freedesktop.DBus"] autorelease]];
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
                                        sendPort: [[[DKPort alloc] initWithRemote: @"org.freedesktop.DBus"] autorelease]];
  aProxy = [conn rootProxy];
  [aProxy DBusBuildMethodCache];
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
                                        sendPort: [[[DKPort alloc] initWithRemote: @"org.freedesktop.DBus"] autorelease]];
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
                                        sendPort: [[[DKPort alloc] initWithRemote: @"org.freedesktop.DBus"] autorelease]];
  aProxy = [conn rootProxy];
  UKRaisesExceptionNamed([aProxy Hello], @"DKDBusRemoteErrorException");
}

- (void)testUnboxedMethodCall
{
  NSConnection *conn = nil;
  id aProxy = nil;
  char *returnValue = NULL;
  NSWarnMLog(@"This test is an expected failure if the session message bus is not available!");
  conn = [NSConnection connectionWithReceivePort: [DKPort port]
                                        sendPort: [[[DKPort alloc] initWithRemote: @"org.freedesktop.DBus"] autorelease]];
  aProxy = [conn rootProxy];
  returnValue = [aProxy GetNameOwner: "org.freedesktop.DBus"];
  UKTrue(NULL != returnValue);
}

- (void)testMixedBoxingStateMethodCall
{
  NSConnection *conn = nil;
  id aProxy = nil;
  BOOL returnValue = NO;
  NSWarnMLog(@"This test is an expected failure if the session message bus is not available!");
  conn = [NSConnection connectionWithReceivePort: [DKPort port]
                                        sendPort: [[[DKPort alloc] initWithRemote: @"org.freedesktop.DBus"] autorelease]];
  aProxy = [conn rootProxy];
  returnValue = [aProxy NameHasOwner: @"org.freedesktop.DBus"];
  UKTrue(returnValue);
}

- (void)testProxyAtPath
{
  NSConnection *conn = nil;
  id aProxy = nil;
  id returnValue = nil;
  NSWarnMLog(@"This test is an expected failure if the org.freedesktop.Hal service on the system message bus is not available!");
  conn = [NSConnection connectionWithReceivePort: [DKPort systemBusPort]
                                        sendPort: [[[DKPort alloc] initWithRemote: @"org.freedesktop.Hal"
                                                                            onBus: DKDBusSystemBus] autorelease]];
  aProxy = [conn proxyAtPath: @"/org/freedesktop/Hal"];

  UKDoesNotRaiseException(returnValue = [aProxy Introspect]);


  UKNotNil(returnValue);
  UKTrue([returnValue isKindOfClass: [NSString class]]);
  UKTrue([returnValue length] > 0);
}


- (void)testThreadedMethodCalls
{
  NSConnection *conn = nil;
  id aProxy = nil;
  NSString *name = @"org.freedesktop.DBus";
  NSMutableArray *threads = [NSMutableArray new];
  NSUInteger count = 0;
  NSWarnMLog(@"This test is an expected failure if the session message bus is not available!");
  [DKPort enableWorkerThread];
  conn = [NSConnection connectionWithReceivePort: [DKPort port]
                                        sendPort: [[[DKPort alloc] initWithRemote: @"org.freedesktop.DBus"] autorelease]];
  aProxy = [conn rootProxy];
  /*
   * NOTE: D-Bus does not seem to handle more than five concurrent calls very
   * well and will sometimes start complaining about being OOM.
   */
  for (count = 0; count < 5; count++)
  {
    NSThread *aThread = [[NSThread alloc] initWithTarget: aProxy
                                                selector: @selector(arpWrappedNameHasOwner:)
                                                  object: name];
    [threads addObject: aThread];
    [aThread start];
    [aThread release];
  }
  NSLog(@"Sleeping two second to allow threads to terminate:");
  sleep(2);
  for (count = 0;count < 5; count++)
  {
    UKTrue([(NSThread*)[threads objectAtIndex: count] isFinished]);
  }
}


@end

@interface TestDKDBus: NSObject <UKTest>
@end
@implementation TestDKDBus
- (void)testGetSessionBus
{
  UKNotNil([DKDBus sessionBus]);
}
- (void)testGetSystemBus
{
  UKNotNil([DKDBus systemBus]);
}

- (void)useSessionBus
{
  UKNotNil([[DKDBus sessionBus] GetId]);
}

- (void)useSystemBus
{
  UKNotNil([[DKDBus systemBus] GetId]);
}
@end
