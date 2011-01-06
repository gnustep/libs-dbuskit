/** Declaration of DKEndpointManager class that manages D-Bus endpoints.
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


#import <Foundation/NSObject.h>
#include <stdint.h>
#include <dbus/dbus.h>

@class DKEndpoint, NSLock, NSMapTable, NSThread, NSRecursiveLock;


// The structure members should all be of the same size, so the compiler should
// not do any awkward packing.
typedef struct {
  id target;
  SEL selector;
  id object;
  intptr_t* returnPointer;
} DKRingBufferElement;

/**
 * DKEndpointManager is a singleton class that maintains a thread to interact
 * with D-Bus. It is responsible for creating and tracking the endpoints to
 * the specific busses and will attempt to recover from connection failures.
 */
@interface DKEndpointManager: NSObject
{
  /**
   * The thread running the runloop which interacts with libdbus.
   */
  NSThread *workerThread;
  @private
  /**
   * Maps active DBusConnections to the corresponding DKEndpoints.
   */
  NSMapTable *activeConnections;
  /**
   * Keeps track of DBusConnections that no longer work but for which recovery
   * is being attempted.
   */
  NSMapTable *faultedConnections;
  /**
   * Lock to protect changes to the connection tables.
   */
  NSRecursiveLock *connectionStateLock;

  /**
   * A (oneway) ring buffer for queuing tuples of the following form:
   * <target, selector, data, pointer-to-return>. The tuples are inserted
   * whenever a libdbus callback requires a value to be returned from the worker
   * thread.
   */
  DKRingBufferElement *ringBuffer;

  /**
   * Free-running counter for the producer thread
   */
  uint32_t producerCounter;

  /**
   * Since it is possible for more than one thread to write to the ring buffer,
   * it cannot be completely lockless: Producers need to obtain the
   * <ivar>producerLock</ivar> in order to prevent overwriting. Since there is
   * only one consumer thread, it needs no such provisions.
   */
  NSLock *producerLock;

  /**
   * Free-running counter for the consumer thread
   */
  uint32_t consumerCounter;

  /**
   * This variable will be set when a producer thread has requested the
   * ring-buffer to be drained.
   */
   BOOL willDrain;
}

/**
 * Returns the shared endpoint manager that is used to manage interactions with
 * libdbus.
 */
+ (id)sharedEndpointManager;

/**
 * Returns a reference to the worker thread that interacts with D-Bus.
 */
- (NSThread*)workerThread;

/**
 * Creates or reuses an endpoint.
 */
- (id)endpointForDBusConnection: (DBusConnection*)connection
                    mergingInfo: (NSDictionary*)info;

/**
 * Method to be called by endpoints that are being deallocated.
 */
- (void)removeEndpointForDBusConnection: (DBusConnection*)connection;


/**
 * Entry point for the worker thread.
 */
- (void)start: (id)ignored;

/**
 * Schedules periodic recovery attempts for <var>endpoint</var>. Will be used
 * in case of bus failures.
 */
- (void)attemptRecoveryForEndpoint: (DKEndpoint*)endpoint;

/**
 * Inserts the request into the ring buffer and schedules it for draining in the
 * worker thread. This method is a synchonisation point and will spin until the
 * request is completed. It should only be used when a return value is required
 * by the libdbus API.
 */
- (BOOL)boolReturnForPerformingSelector: (SEL)selector
                                 target: (id)target
                                   data: (void*)data
                          waitForReturn: (BOOL)doWait;

/**
 * Called from within the worker thread to process requests from the ring
 * buffer.
 */
- (void)drainBuffer: (id)ignored;
@end

