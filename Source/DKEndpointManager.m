/** Implemenation of the DKEndpointManager class that manages D-Bus endpoints.
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

#import "DKEndpointManager.h"
#import "DKEndpoint.h"
#import <Foundation/NSDate.h>
#import <Foundation/NSDebug.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSException.h>
#import <Foundation/NSLock.h>
#import <Foundation/NSMapTable.h>
#import <Foundation/NSRunLoop.h>
#import <Foundation/NSThread.h>
#import <Foundation/NSTimer.h>

#include <sched.h>


@interface DKEndpoint (Private)
- (void)_mergeInfo: (NSDictionary*)info;
@end
static DKEndpointManager *sharedManager;

#define DKTheManager getManager(managerClass, getManagerSelector)
#define DKManagerThread managerThread
#define DKPerformOnManagerThread(target,payloadSelector,object) performOnThread(target,\
  perfonOnThreadSelector,\
  payloadSelector, \
  DKManagerThread,\
  object,\
  NO)



/* Definitions for the ring buffer, designwise inspired by EtoileThread */

// Needs to be 2^n
#define DKRingSize 8

#define DKRingMask (DKRingSize - 1)

#define DKRingSpace (DKRingSize - (producerCounter - consumerCounter))

#define DKRingFull (DKRingSpace == 0)
#define DKRingEmpty ((producerCounter - consumerCounter) == 0)
#define DKMaskIndex(index) ((index) & DKRingMask)

/*
 * This works the following way:
 * 1. Check whether the buffer is full
 * 2. If so, spin for a short while to allow it to drain or yield to other
 *    threads if it's taking to long.
 * 3. Lock the producer lock since multiple threads might want to write to the
 *    buffer.
 * 4. Check again if the buffer hasn't filled in the meantime.
 * 5. Retain the target for its trip to the other thread.
 * 6. Insert the new request into the buffer.
 * 7. Increment the producer counter.
 * 8. Unlock the producer lock.
 * 9. If the consumer thread has not been  instructed to start draining the
 *    buffer, do so.
 */
#define DKRingInsert(x) do {\
  NSUInteger count = 0; \
  while (DKRingFull)\
  {\
    if ((++count % 16) == 0)\
    {\
      sched_yield();\
    }\
  }\
  [producerLock lock];\
    while (DKRingFull)\
    {\
      if ((++count % 16) == 0)\
      {\
	sched_yield();\
      }\
    }\
  [x.target retain];\
  ringBuffer[DKMaskIndex(producerCounter)] = x;\
  __sync_fetch_and_add(&producerCounter, 1);\
  [producerLock unlock];\
  NSDebugMLog(@"Inserting into ringbuffer (remaining capacity: %lu).",\
    DKRingSpace);\
  if (NO == DKRingEmpty)\
  {\
    NSDebugMLog(@"Stuff in buffer: Scheduling buffer draining.");\
    [self performSelector: @selector(drainBuffer:)\
                 onThread: workerThread\
	       withObject: nil\
            waitUntilDone: NO];\
  }\
} while (0)


/*
 * If the buffer is not empty, remove an element and process it.
 */
#define DKRingRemove(x) do {\
  if (NO == DKRingEmpty)\
  {\
    NSDebugMLog(@"Removing element at %lu from ring buffer", DKMaskIndex(consumerCounter));\
    x = ringBuffer[DKMaskIndex(consumerCounter)];\
    ringBuffer[DKMaskIndex(consumerCounter)] = (DKRingBufferElement){nil, NULL, nil, NULL};\
    [x.target autorelease];\
    __sync_fetch_and_add(&consumerCounter, 1);\
  }\
  NSDebugMLog(@"(new capacity: %lu).",\
    DKRingSpace);\
} while (0)

@implementation DKEndpointManager

+ (void)initialize
{
  if ([DKEndpointManager class] != self)
  {
    return;
  }

  /*
   * It might be smart to put DBus into thread-safe mode by default because
   * there is a fair chance of missing NSWillBecomeMultiThreadedNotification.
   * (This code might be executed pretty late in the application lifecycle.)
   * Note: We could define our own hooks and use NSLock and friends, but that's
   * pretty pointless because DBus will use pthreads itself, just as NSLock
   * would.
   */
   dbus_threads_init_default();

  sharedManager = [[DKEndpointManager alloc] init];
}

+ (id)sharedEndpointManager
{
  return sharedManager;
}

- (id)init
{
  if (nil != sharedManager)
  {
    [self release];
    return nil;
  }

  if (nil == (self = [super init]))
  {
    return nil;
  }

   activeConnections = NSCreateMapTable(NSNonOwnedPointerMapKeyCallBacks,
     NSNonRetainedObjectMapValueCallBacks,
     3);
   faultedConnections = NSCreateMapTable(NSNonOwnedPointerMapKeyCallBacks,
     NSNonRetainedObjectMapValueCallBacks,
     3);
   connectionStateLock = [NSRecursiveLock new];
   workerThread = [[NSThread alloc] initWithTarget: self
                                          selector: @selector(start:)
                                            object: nil];
   [workerThread setName: @"DBusKit worker thread"];
   [workerThread start];
   ringBuffer = calloc(sizeof(DKRingBufferElement), DKRingSize);
   producerLock = [NSLock new];
   if (NO == (activeConnections && faultedConnections && connectionStateLock &&
     workerThread && ringBuffer && producerLock))
   {
     [self release];
     return nil;
   }
   return self;
}

- (NSThread*)workerThread
{
  return workerThread;
}

- (id)endpointForDBusConnection: (DBusConnection*)connection
                    mergingInfo: (NSDictionary*)info
{
  DKEndpoint *endpoint = nil;
  [connectionStateLock lock];
  NS_DURING
  {
    // Check whether we can reuse an old connection:
    endpoint = NSMapGet(activeConnections, (void*)connection);
    if (nil != endpoint)
    {
      NSDebugMLog(@"Will reuse old connection");
      /*
       * We want to retain the endpoint because the map table only weakly
       * references it and we want to pass ownership of this endpoint to the
       * caller at the end of the function (we will autorelease it there).
       */
      [endpoint retain];
      NS_DURING
      {
	[endpoint _mergeInfo: info];
      }
      NS_HANDLER
      {
	[endpoint release];
	[localException raise];
      }
      NS_ENDHANDLER
    }
  }

  /* We couldn't find a preexisting endpoint, so we create a new one: */
  if (nil == endpoint)
  {
    endpoint = [[DKEndpoint alloc] initWithConnection: connection
                                                 info: info];
  }

  if (nil != endpoint)
  {
    NSMapInsert(activeConnections, connection, endpoint);
  }
  else
  {
    NSDebugMLog(@"Could not create endpoint!");
  }
  NS_HANDLER
  {
    [connectionStateLock unlock];
    [localException raise];
  }
  NS_ENDHANDLER
  [connectionStateLock unlock];
  return [endpoint autorelease];
}

- (void)removeEndpointForDBusConnection: (DBusConnection*)connection
{
  [connectionStateLock lock];
  NS_DURING
  {
    NSMapRemove(activeConnections, connection);
    NSMapRemove(faultedConnections, connection);
  }
  NS_HANDLER
  {
    [connectionStateLock unlock];
    [localException raise];
  }
  NS_ENDHANDLER

  [connectionStateLock unlock];
}

- (void)distantFutureReached: (id)ignored
{
  //Won't happen.
}

- (void)start: (id)ignored
{
  NSAutoreleasePool *arp = [NSAutoreleasePool new];
  // We schedule a timer to make sure that the run loop actually runs:
  [NSTimer scheduledTimerWithTimeInterval: [[NSDate distantFuture] timeIntervalSinceNow]
                                   target: self
                                 selector: @selector(distantFutureReached:)
                                 userInfo: nil
                                  repeats: NO];
  [[NSRunLoop currentRunLoop] run];
  [arp release];
}

- (void)attemptRecoveryForEndpoint: (DKEndpoint*)endpoint
{
  //TODO: Implement
}

- (BOOL)boolReturnForPerformingSelector: (SEL)selector
                                 target: (id)target
		 		   data: (void*)data
                          waitForReturn: (BOOL)doWait
{
  /*
   * Setup the returnValue with -1 to signify that the call has not been
   * completed.
   */
  volatile NSInteger retVal = -1;
  NSInteger *retValPointer = NULL;
  NSUInteger count = 0;
  static DKRingBufferElement request;
  if (doWait)
  {
    // If we are waiting for the return value, we pass the return value pointer.
    retValPointer = (NSInteger*)&retVal;
  }
  else
  {
    //Otherwise we pass NULL and set the return value to 1.
    retVal = 1;
  }

  request = (DKRingBufferElement){target, selector, (id)data, retValPointer};

  /*
   * In case of the unlikely event that we are being called from within the
   * worker thread, we want to directly execute the request (at least when we
   * are supposed to wait for it.
   */
  if ([workerThread isEqual: [NSThread currentThread]])
  {
    IMP performRequest = [target methodForSelector: selector];
    NSDebugMLog(@"Performing on current thread");
    NSAssert2(performRequest, @"Could not perform selector %@ on %@",
      selector,
      target);
    if (doWait)
    {
      return (BOOL)(intptr_t)performRequest(target, selector, data);
    }
  }

  /*
   * Otherwise, we insert the request and spin until the worker thread completes
   * the request.
   */
  DKRingInsert(request);
  while ((-1 == retVal) && (YES == doWait))
  {
    if (count % 16)
    {
      sched_yield();
    }
  }
  return (BOOL)retVal;
}

- (void)drainBuffer: (id)ignored
{
  DKRingBufferElement element = {nil, NULL, nil, NULL};
  NSInteger *returnPointer = NULL;
  NSDebugMLog(@"Started draining buffer");
  DKRingRemove(element);

  if (nil != element.target)
  {
    IMP performRequest = [element.target methodForSelector: element.selector];
    returnPointer = element.returnPointer;
    NSAssert2(performRequest, @"Could not perform selector %@ on %@",
      element.selector,
      element.target);
    if (NULL != returnPointer)
    {
      NS_DURING
      {
        *returnPointer = (NSInteger)performRequest(element.target,
          element.selector,
          element.object);
      }
      NS_HANDLER
      {
        // Set the pointer to 0 so that the requesting thread does not
        // continue to wait for the result.
        *returnPointer = 0;
        [localException raise];
      }
      NS_ENDHANDLER
    }
    else
    {
      // If no return pointer is set, the other thread is not waiting for
      // completion.
      performRequest(element.target, element.selector, element.object);
    }
  }
  else
  {
    // If there was no object:
    if (NULL != returnPointer)
    {
      *returnPointer = 0;
    }
  }

  /*
   * If there are further elements to remove, we will reschedule draining the
   * buffer.
   */
/*  if ((NO == DKRingEmpty))
  {
    NSDebugMLog(@"Elements remain in buffer, rescheduling draining");
    __sync_bool_compare_and_swap(&willDrain, NO, YES);
    [self performSelector: @selector(drainBuffer:)
                 onThread: workerThread
	       withObject: nil
            waitUntilDone: NO];
  }
  else
  {
    __sync_bool_compare_and_swap(&willDrain, YES, NO);
  }*/
}
@end
