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
 *
 * DKEndpointManager also provides a synchronized mode so that it can be safely
 * called from +initialize methods. In that case, the caller is expected to wrap
 * method calls that might trigger the manager (especially to DKEndpoint,
 * DKPort, DKPortNameServer, DKProxy, or DKNotificationCenter) with calls to
 * -enterInitialize and -leaveInitialize.
 */
@interface DKEndpointManager: NSObject
{
  /**
   * The thread running the runloop which interacts with libdbus.
   */
  NSThread *workerThread;
  @private

  /**
   * Tracks whether the thread has been started.
   */
  BOOL threadStarted;

  /**
   * Tracks whether we already enabled threading.
   */
  BOOL threadEnabled;

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
   * Free-running counter for the producer threads
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
   * Counter to track how many callers are calling into the endpoint-manager
   * from +initialize.
   */
   NSUInteger initializeRefCount;

   /**
    * Lock to protect changes to the accounting tables in synchronised mode.
    */
    NSRecursiveLock *synchronizationStateLock;


  /**
   * The <ivar>syncedWatchers</ivar> map table keeps track of watchers that were
   * created while the endpoint manager is in synchronised mode. Each is mapped
   * to the thread it was created in. When the last +initialize call using the
   * manager finishes, the manager will reap these watchers and reschedule them
   * on the worker thread.
   */
   NSMapTable *syncedWatchers;

  /**
   * The <ivar>syncedTimers</ivar> map table keeps track of watchers that were
   * created while the endpoint manager is in synchronised mode. Each is mapped
   * to the thread it was created in. When the last +initialize call using the
   * manager finishes, the manager will invalidate these timers and reschedule
   * then on the worker thread.
   */
   NSMapTable *syncedTimers;
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
 * Returns an endpoint connected to an arbitrary address. This is only useful
 * for specific cases where you don't want to use one of the standard message
 * busses. Use -endpointForWellKnownBus: to get a connection for one of those.
 */
- (DKEndpoint*)endpointForConnectionTo: (NSString*)address;

/**
 * Returns an endpoint connected to one of the well-known message busses as per
 * D-Bus documentation (i.e. DBUS_BUS_SYSTEM, DBUS_BUS_SESSION or
 * DBUS_BUS_STARTER).
 */
- (DKEndpoint*)endpointForWellKnownBus: (DBusBusType)type;

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
 * worker thread. With <var>doWait</var> set to YES this method becomes a
 * synchonisation point: It will spin until the request has completed. This
 * should only be used when a return value is required by the libdbus API.
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


/**
 * Will be called in order to enable threaded mode.
 */
- (void)enableThread;

/**
 * Will be called by DBusKit classes that require usage of the bus in their
 * +initialize method.
 */
- (void)enterInitialize;

/**
 * Will be called by DBusKit classes that require usage of the bus in their
 * +initialize method.
 */
- (void)leaveInitialize;

/**
 * This method can be used to determine whether the manager is in synchronized
 * mode due to being called from an initialize method.
 */
- (BOOL)isSynchronizing;

/**
 * This method will be used by instances of <class>DKRunLoopContext</class> to
 * inform the endpoint manager of timers it is presently using. If the manager
 * is in synchronized mode (i.e. being called from +initialize), a reference to
 * the timer will be tracked until it either no longer needed or has
 * successfully been rescheduled on the worker thread. In order to track all
 * data required, the <var>context</var> the timer comes from must be specified.
 */
- (void)registerTimer: (id)timer
          fromContext: (id)context;

/**
 * This method will be used by instances of <class>DKRunLoopContext</class> to
 * inform the endpoint manager of <class>DKWatcher</class> instances it is
 * presently using to monitor file descriptors on behalf of libdbus. If the manager
 * is in synchronized mode (i.e. being called from +initialize), a reference to
 * the watcher will be tracked until it either no longer needed or has
 * successfully been rescheduled on the worker thread.
 */
- (void)registerWatcher: (id)watcher;

/**
 * If the receiver is in synchronized mode, this removes the reference to the
 * timer object.
 */
- (void)unregisterTimer: (id)timer;

/**
 * If the receiver is in synchronized mode, this removes the reference to the
 * watcher object.
 */
- (void)unregisterWatcher: (id)watcher;
@end

/**
 * Macro to check whether the code is presently executing in the worker thread
 */
#define DKInWorkerThread (BOOL)[[[DKEndpointManager sharedEndpointManager] workerThread] isEqual: [NSThread currentThread]];
