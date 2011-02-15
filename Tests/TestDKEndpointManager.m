/* Unit tests for DKEndpointManager
   Copyright (C) 2011 Free Software Foundation, Inc.

   Written by:  Niels Grewe <niels.grewe@halbordnung.de>
   Created: January 2011

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

#import "../Source/DKEndpointManager.h"
#import "../Headers/DKPort.h"

#include <unistd.h>

@interface DKTestDummy: NSObject
{
  int callCount;
}
@end

@interface DKTestMultiCaller: NSObject
@end

@implementation DKTestDummy
- (BOOL)boolFunction: (id)ignored
{
  return YES;
}

- (BOOL)boolMulti: (id)ignored
{
  callCount++;
  return YES;
}

- (void)voidMulti: (id)ignored
{
  sleep(1);
  callCount++;
}

- (int)callCount
{
  return callCount;
}
@end

@implementation DKTestMultiCaller: NSObject
- (void)run: (DKTestDummy*)dummy
{

  NSAutoreleasePool *arp = [NSAutoreleasePool new];
  UKTrue([[DKEndpointManager sharedEndpointManager] boolReturnForPerformingSelector: @selector(boolMulti:)
                                                                            target: dummy
                                                                              data: nil
                                                                     waitForReturn: YES]);
  [arp release];
}
@end

@interface TestDKEndpointManager: NSObject <UKTest>
@end

@implementation TestDKEndpointManager
+ (void)initialize
{
  [DKPort enableWorkerThread];
}

- (void)testGetManager
{
  UKNotNil([DKEndpointManager sharedEndpointManager]);
}
- (void)testGetThread
{
  UKNotNil([[DKEndpointManager sharedEndpointManager] workerThread]);
}

- (void)testRingBufferReturn
{
  DKTestDummy *dummy = [DKTestDummy new];
  UKTrue([[DKEndpointManager sharedEndpointManager] boolReturnForPerformingSelector: @selector(boolFunction:)
                                                                             target: dummy
                                                                               data: nil
                                                                      waitForReturn: YES]);
  [dummy release];
}

- (void)testRingBufferAsync
{
  DKTestDummy *dummy = [DKTestDummy new];
  NSUInteger count = 0;
  for (count = 0; count < 5; count++)
  {
    UKTrue([[DKEndpointManager sharedEndpointManager] boolReturnForPerformingSelector: @selector(voidMulti:)
                                                                               target: dummy
                                                                                 data: nil
                                                                        waitForReturn: NO]);
  }
  UKIntsEqual([dummy callCount], 0);
  NSLog(@"Sleeping 6 seconds to have all calls complete");
  sleep(6);
  UKIntsEqual([dummy callCount], 5);
  [dummy release];
}

- (void)testRingBufferMultiProducer
{
  NSUInteger count = 0;
  id* threads = calloc(sizeof(id),5);
  id* callers = calloc(sizeof(id),5);
  DKTestDummy *dummy = [DKTestDummy new];
  for (count = 0; count < 5; count++)
  {
    callers[count] = [DKTestMultiCaller new];
    threads[count] = [[NSThread alloc] initWithTarget: callers[count]
	                                     selector: @selector(run:)
					       object: dummy];
    [threads[count] start];
  }
  NSLog(@"Sleeping 6 seconds to have all calls complete");
  sleep(6);
  UKIntsEqual([dummy callCount], 5);
  [dummy release];
  for (count = 0; count < 5; count++)
  {
    [threads[count] release];
    [callers[count] release];
  }
  free(threads);
  free(callers);
}
@end
