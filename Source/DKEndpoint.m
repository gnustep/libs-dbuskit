/** Implementation of DKEndpoint class for integrating DBus into NSRunLoop.
   Copyright (C) 2010 Free Software Foundation, Inc.

   Written by:  Niels Grewe <niels.grewe@halbordnung.de>
   Created: May 2010

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

   <title>DKEndpoint class reference</title>
   */

#import "DKEndpoint.h"
#import <Foundation/NSCoder.h>
#import <Foundation/NSDebug.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSException.h>
#import <Foundation/NSKeyedArchiver.h>
#import <Foundation/NSLock.h>
#import <Foundation/NSMapTable.h>
#import <Foundation/NSRunLoop.h>
#import <Foundation/NSString.h>
#import <Foundation/NSTimer.h>
#import <Foundation/NSValue.h>
#import <GNUstepBase/NSDebug+GNUstepBase.h>

#import "DBusKit/DKPort.h"

/*
 * Integration functions:
 */


/*
 * The DK(Timeout|Watch)* functions do what their names imply.
 */
static dbus_bool_t
DKTimeoutAdd(DBusTimeout *timeout, void *data);

static void
DKTimeoutRemove(DBusTimeout *timeout, void *data);

static void
DKTimeoutToggled(DBusTimeout *timeout, void *data);

static dbus_bool_t
DKWatchAdd(DBusWatch *watch, void *data);

static void
DKWatchRemove(DBusWatch *watch, void *data);

static void
DKWatchToggled(DBusWatch *watch, void *data);

/*
 * Informs the run loop that DBus has work for it to do.
 */
static void
DKWakeUp(void *data);

/*
 * Will be called to indicate that messages might be waiting.
 */
static void
DKUpdateDispatchStatus(DBusConnection *conn,
  DBusDispatchStatus status,
  void *data);

/*
 * DBus might want to release objects we created, so we wrap -release for it.
 */
static void
DKRelease(void *ptr);



/*
 * Global state for referencing connections:
 */
static NSMapTable *activeConnections;
static NSRecursiveLock *activeConnectionLock;


@interface DKEndpoint (DBusEndpointPrivate)
- (void)cleanup;
- (void)_mergeInfo: (NSDictionary*)info;
@end

/**
 * Context object to manage runLoop interactions.
 */
@interface DKRunLoopContext: NSObject
{
  DBusConnection *connection;
  NSMapTable *timers;
  NSMapTable *watchers;
  NSString *runLoopMode;
  NSRunLoop *runLoop;
  NSLock *lock;
}

- (id)_initWithConnection: (DBusConnection*)connection;
- (NSRunLoop*)runLoop;
- (NSString*)runLoopMode;
- (void)reschedule;
@end

/**
 * Watcher object to monitor the file descriptors D-Bus signals on.
 */
@interface DKWatcher: NSObject <RunLoopEvents>
{
  DBusWatch *watch;
  BOOL callbackInProgress;
  int fileDesc;
  DKRunLoopContext *ctx;
}
@end

@implementation DKEndpoint

+ (void)initialize
{
  if (self != [DKEndpoint class])
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

   /*
    * Further initializations unfortunately need to be done on a per-connection
    * basis. We can only optimize by reusing existing connections (D-Bus
    * will recycle them behind our back anyways). We do this by weakly
    * referencing the connections and DKEndpoint objects in a global
    * map-table. They will be removed from there prior to deallocation. The
    * downside is that we need to protect the table with a lock. (A capacity of
    * 3 is a good guess because we will probably at most need a connection to
    * the session and one to the system bus).
    */
    activeConnections = NSCreateMapTable(NSNonOwnedPointerMapKeyCallBacks,
      NSNonRetainedObjectMapValueCallBacks,
      3);
    activeConnectionLock = [NSRecursiveLock new];
    NSAssert((activeConnections && activeConnectionLock),
      @"Could not allocate map table and lock for D-Bus connection management");
}

- (id) initWithConnection: (DBusConnection*)conn
                     info: (NSDictionary*)infoDict
{
  DKEndpoint *oldConnection = nil;
  BOOL initSuccess = NO;

  if (nil == (self = [super init]))
  {
    return nil;
  }

  /* NULL connections are useless: */
  if (NULL == conn)
  {
    [self release];
    return nil;
  }

  [activeConnectionLock lock];
  NS_DURING
  {

    /* Check wether we can reuse an old connection. */
    oldConnection = NSMapGet(activeConnections, (void*)conn);
    if (nil != oldConnection)
    {
      NSDebugMLog(@"Will reuse old connection");
      // Retain the old connection to make it stick around:
      [oldConnection retain];
      [oldConnection _mergeInfo: infoDict];
    }
  }
  NS_HANDLER
  {
    [activeConnectionLock unlock];
    [localException raise];
  }
  NS_ENDHANDLER
  if (nil != oldConnection)
  {
    [self release];
    [activeConnectionLock unlock];
    return oldConnection;
  }

  NS_DURING
  {
    // We keep the lock until we're done initializing.

    /*
     * Reference the connection on the dbus level so that it sticks around until
     * -cleanup is called.
     */
    dbus_connection_ref(conn);
    connection = conn;
    ctx = [[DKRunLoopContext alloc] _initWithConnection: connection];

    // Install our runLoop hooks:
    if ((initSuccess = (nil != ctx)))
    {
      initSuccess = (BOOL)dbus_connection_set_timeout_functions(connection,
        DKTimeoutAdd,
        DKTimeoutRemove,
        DKTimeoutToggled,
        (void*)ctx,
        DKRelease);
    }

    if (initSuccess)
    {
      initSuccess = (BOOL)dbus_connection_set_watch_functions(connection,
        DKWatchAdd,
        DKWatchRemove,
        DKWatchToggled,
        (void*)ctx,
        DKRelease);
    }

    if (initSuccess)
    {
      dbus_connection_set_wakeup_main_function(connection,
        DKWakeUp,
        (void*)ctx,
        DKRelease);
      dbus_connection_set_dispatch_status_function(connection,
        DKUpdateDispatchStatus,
        (void*)ctx,
        DKRelease);
    }

    if (!initSuccess)
    {
      [self cleanup];
    }
  }
  NS_HANDLER
  {
    [activeConnectionLock unlock];
    [localException raise];
  }
  NS_ENDHANDLER

  if (!initSuccess)
  {
    [activeConnectionLock unlock];
    [self release];
    return nil;
  }

  NS_DURING
  {
    NSMapInsert(activeConnections, connection, self);
  }
  NS_HANDLER
  {
    [activeConnectionLock unlock];
    [localException raise];
  }
  NS_ENDHANDLER

  [activeConnectionLock unlock];
  ASSIGN(info, infoDict);
  return self;
}

- (DBusConnection*)connection
{
  return connection;
}


/**
 * For use with non-well-known buses, not exteremly useful, but generic.
 */
- (id) initWithConnectionTo: (NSString*)endpoint
{
  DBusError err;
  /* Note: dbus_connection_open_private() would be an option here, but would
   * require us to take care of the connections ourselves. Right now, this does
   * not seem to be worth the effort, so we let D-Bus do this for us (hence we
   * call dbus_connection_unref() and not dbus_connection_close() in -cleanup).
   */
  DBusConnection *conn = NULL;
  NSDictionary *theInfo = [[NSDictionary alloc] initWithObjectsAndKeys: endpoint,
    @"address", nil];
  dbus_error_init(&err);

  conn = dbus_connection_open([endpoint UTF8String], &err);
  if (NULL == conn)
  {
    [theInfo release];
    NSWarnMLog(@"Could not open D-Bus connection. Error: %s. (%s)",
      err.name,
      err.message);
    dbus_error_free(&err);
    return nil;
  }
  dbus_error_free(&err);

  self = [self initWithConnection: conn
                             info: theInfo];
  [theInfo release];

  // -_initWithConnection did increase the refcount, we release ownership of the
  // connection:
  dbus_connection_unref(conn);
  return self;
}

- (id) initWithWellKnownBus: (DBusBusType)type
{
  DBusError err;
  DBusConnection *conn = NULL;
  NSDictionary *theInfo = [[NSDictionary alloc] initWithObjectsAndKeys: [NSNumber numberWithInt: type],
    @"wellKnownBus", nil];
  dbus_error_init(&err);
  conn = dbus_bus_get(type, &err);
  if (NULL == conn)
  {
    [theInfo release];
    NSWarnMLog(@"Could not open D-Bus connection. Error: %s. (%s)",
      err.name,
      err.message);
    dbus_error_free(&err);
    return nil;
  }
  dbus_error_free(&err);

  /*
   * dbus_bus_get() will cause _exit() to be called when the bus goes away.
   * Since we are library code, we don't want to confuse the user with that.
   *
   * TODO: Instead, we will need to watch for the "Disconnected" signal from
   * DBUS_PATH_LOCAL in DBUS_INTERFACE_LOCAL and invalidate all DBus ports.
   */
  dbus_connection_set_exit_on_disconnect(conn, NO);

  self = [self initWithConnection: conn
                             info: theInfo];
  [theInfo release];
  // -initWithConnection did increase the refcount, we release ownership of the
  // connection:
  dbus_connection_unref(conn);
  return self;
}

- (id) initWithCoder: (NSCoder*)coder
{
  // NSObject does not adopt NSCoding
  if (nil == (self = [super init]))
  {
    return nil;
  }

  if ([coder allowsKeyedCoding])
  {
    info = [coder decodeObjectForKey: @"DKEndpointInfo"];
  }
  else
  {
    /*
     * Decoding for a sequential coder (i.e. NSPortCoder) is rather convoluted
     * because we cannot use any Obj-C type, which would be wrapped into proxies
     * by NSPortCoder. Hence we specify a C-ish format to transfer information
     * about the endpoint.
     */
    int endpoint_type = 0;
    char* address = NULL;
    int bus_type = 0;
    [coder decodeValueOfObjCType: @encode(int) at: &endpoint_type];
    if (endpoint_type == 0)
    {
      [coder decodeValueOfObjCType: @encode(int) at: &bus_type];
    }
    else
    {
      [coder decodeValueOfObjCType: @encode(char*) at: &address];
    }

    if (address)
    {
      info = [[NSDictionary alloc] initWithObjectsAndKeys: [NSString stringWithUTF8String: address],
        @"address", nil];
    }
    else
    {
      info = [[NSDictionary alloc] initWithObjectsAndKeys: [NSNumber numberWithInt: bus_type],
        @"wellKnownBus", nil];
    }
  }
  return self;
}

/**
 * Replace the endpoint just decoded (which only contains the info dictionary)
 * with one that actually works.
 */
- (id) awakeAfterUsingCoder: (NSCoder*)coder
{
   id data = nil;
   id newEndpoint = nil;
   if (nil != (data = [info objectForKey: @"wellKnownBus"]))
   {
     newEndpoint = [[DKEndpoint alloc] initWithWellKnownBus: [(NSNumber*)data intValue]];
   }
   else
   {
     data = [info objectForKey: @"address"];
     newEndpoint = [[DKEndpoint alloc] initWithConnectionTo: (NSString*)data];
   }
   [self release];
   return newEndpoint;
}

/**
 * Override the default implementation, which would return a proxy.
 */
- (id)replacementObjectForPortCoder: (NSPortCoder*)coder
{
  return self;
}

/**
 * Encodes the information about the endpoint. Unfortunately, we have no chance
 * of getting this right if somebody used the  -initWithConnection:info:
 * initalizer without passing a proper info dictionary.
 */
- (void) encodeWithCoder: (NSCoder*)coder
{
  if (nil == info)
  {
    [NSException raise: NSInvalidArchiveOperationException
                format: @"This DKEndpoint has been create with a private initializer and cannot be encoded."];
  }

  // NSObject doesn't adopt NSCoding, so we don't do [super encodeWithCoder:].

  if ([coder allowsKeyedCoding])
  {
    [coder encodeObject: info
                 forKey: @"DKEndpointInfo"];
  }
  else
  {
    /*
     * Encoding for a sequential coder (i.e. NSPortCoder) is rather convoluted
     * because we cannot use any Obj-C type, which would be wrapped into proxies
     * by NSPortCoder. Hence we specify a C-ish format to transfer information
     * about the endpoint.
     * The following conventions apply:
     * endpoint_type = 0 - endpoint connected to a well-known bus. The following
     *                     data element will be the integer designating the bus.
     * endpoint_type = 1 - endpoint connected to an arbitrary address. The
     *                     following data element will containt the C string
     *                     describing the address.
     */
    int endpoint_type = 0;
    NSString *address = nil;
    const char *addrString;
    int bus_type;
    if (nil != (address = [info objectForKey: @"address"]))
    {
      endpoint_type = 1;
    }
    [coder encodeValueOfObjCType: @encode(int) at: &endpoint_type];

    if (address)
    {
      addrString = [address UTF8String];
      [coder encodeValueOfObjCType: @encode(char*) at: &addrString];
    }
    else
    {
      bus_type = [(NSNumber*)[info objectForKey: @"wellKnownBus"] intValue];
      [coder encodeValueOfObjCType: @encode(int) at: &bus_type];
    }
  }
}

/**
  * The _mergeInfo: method merges the information from a newly created endpoint
  * into the present one.
  */
- (void)_mergeInfo: (NSDictionary*)newInfo
{
  if (info == nil)
  {
    ASSIGN(info, newInfo);
  }
  else if (NO == [info isEqualToDictionary: newInfo])
  {
    NSMutableDictionary *merged = [NSMutableDictionary new];
    NSString *address = [info objectForKey: @"address"];
    NSString *newAddress = [newInfo objectForKey: @"address"];
    NSNumber *busType = [info objectForKey: @"wellKnownBus"];
    NSNumber *newBusType = [newInfo objectForKey: @"wellKnownBus"];

    // We prefer the values from the new dictionary.
    if (nil != newAddress)
    {
      [merged setObject: newAddress
                 forKey: @"address"];
    }
    else if (nil != address)
    {
      [merged setObject: newAddress
                 forKey: @"address"];
    }
    if (nil != newBusType)
    {
      [merged setObject: newBusType
                 forKey: @"wellKnownBus"];
    }
    else if (nil != busType)
    {
      [merged setObject: busType
                 forKey: @"wellKnownBus"];
    }

    // We know that info does already exists and that the new info dictionary
    // will not be the previous one, so we don't need to use the ASSIGN() macro.
    [info release];
    info = [merged copy];
    [merged release];
  }
}


/* Methods to manipulate the behavior of the endpoint: */

/**
 * Use this method to make the run loop context reschedule all its timers and
 * watchers in the current runloop. Since D-Bus is in thread-safe mode, this
 * will only cause defined behavior.
 */
- (void)scheduleInCurrentThread
{
  [ctx reschedule];
}

/**
 * Flushes all pending messages from the connection.
 */
- (void) flush
{
  dbus_connection_flush(connection);
}

/**
 * Removes the reference that this endpoint holds to its D-Bus connection and
 * unregisteres the endpoint so that it wont be reused any more. Will be called
 * prior to deallocation.
 */
- (void) cleanup
{
  if (connection != NULL)
  {
    // Make this endpoint unavailable to other threads:
    [activeConnectionLock lock];
    NS_DURING
    {
      if (connection != NULL)
      {
        NSMapRemove(activeConnections, connection);

        dbus_connection_unref(connection);
        connection = NULL;
	[ctx release];
      }
    }
    NS_HANDLER
    {
      [activeConnectionLock unlock];
      [localException raise];
    }
    NS_ENDHANDLER
    [activeConnectionLock unlock];
  }

}

/* Methods to access information about the bus: */

- (DKDBusBusType)DBusBusType
{
  NSNumber *typeNo = [info objectForKey: @"wellKnownBus"];
  if (nil == typeNo)
  {
    return DKDBusBusTypeOther;
  }
  return [typeNo unsignedIntegerValue];
}

- (NSRunLoop*)runLoop
{
  return [ctx runLoop];
}

- (NSString*)runLoopMode
{
  return [ctx runLoopMode];
}

- (DBusConnection*)DBusConnection
{
  return connection;
}
- (void)dealloc
{
  [self cleanup];
  [info release];
  [super dealloc];
}
@end

@implementation DKWatcher
/**
 * Tells the run loop to monitor the events that D-Bus wants to monitor.
 */
- (void)monitorForEvents
{
  NSUInteger events = dbus_watch_get_flags(watch);
  // Dispatch new events to the runLoop:
  if (events & DBUS_WATCH_READABLE)
    {
      [[ctx runLoop] addEvent: (void*)(intptr_t)fileDesc
                         type: ET_RDESC
                      watcher: self
                      forMode: [ctx runLoopMode]];
    }
  if (events & DBUS_WATCH_WRITABLE)
    {
      [[ctx runLoop] addEvent: (void*)(intptr_t)fileDesc
                         type: ET_WDESC
                      watcher: self
                      forMode: [ctx runLoopMode]];
    }
}

/**
 * Tells the run loop to stop monitoring the events that D-Bus wants to monitor.
 */
- (void)unmonitorForEvents
{
  NSUInteger events = dbus_watch_get_flags(watch);
  // Remove events to the runLoop:
  if (events & DBUS_WATCH_READABLE)
    {
      [[ctx runLoop] removeEvent: (void*)(intptr_t)fileDesc
                            type: ET_RDESC
                         forMode: [ctx runLoopMode]
                             all: NO];
    }
  if (events & DBUS_WATCH_WRITABLE)
    {
      [[ctx runLoop] removeEvent: (void*)(intptr_t)fileDesc
                            type: ET_WDESC
                         forMode: [ctx runLoopMode]
                             all: NO];
    }

}

- (id)initWithWatch: (DBusWatch*)_watch
         andContext: (DKRunLoopContext*)aCtx
              forFd: (int)fd
{
  if (nil == (self = [super init]))
    {
      return nil;
    }
  fileDesc = fd;
  // The context retains its watchers and timers:
  ctx = aCtx;
  watch = _watch;
  [self monitorForEvents];
  return self;
}


/**
 * Reschedule monitoring the file descriptor in the current run loop.
 */
- (void)reschedule
{
  while (callbackInProgress)
  {
    //No-Op, let the callback complete.
  }
  [self unmonitorForEvents];
  [self monitorForEvents];
}

/**
 * Delegate method for event delivery by the run loop.
 */
- (void)receivedEvent: (void*)data
                 type: (RunLoopEventType)type
                extra: (void*)extra
              forMode: (NSString*)mode
{
  int fd = (int)(intptr_t)data;
  if(fileDesc != fd)
    {
      //Not good
      return;
    }
  callbackInProgress = YES;
  switch (type)
    {
      case ET_RDESC:
        NSDebugMLog(@"Handling readable on watch");
        dbus_watch_handle(watch, DBUS_WATCH_READABLE);
        break;
      case ET_WDESC:
        NSDebugMLog(@"Handling writable on watch");
        dbus_watch_handle(watch, DBUS_WATCH_WRITABLE);
        break;
      default:
        break;
    }
  callbackInProgress = NO;
}

- (void)dealloc
{
  [super dealloc];
}
@end

@implementation DKRunLoopContext

- (id) _initWithConnection: (DBusConnection*)conn
{
  if (nil == (self = [super init]))
  {
    return nil;
  }
  connection = conn;

  // TODO: Profile wether 10 is a reasonable default capacity.
  timers = NSCreateMapTable(NSNonOwnedPointerMapKeyCallBacks,
    NSObjectMapValueCallBacks,
    10);
  watchers = NSCreateMapTable(NSNonOwnedPointerMapKeyCallBacks,
    NSObjectMapValueCallBacks,
    10);
  lock = [[NSLock alloc] init];
  return self;
}


/*
 * TODO: We need to handle different runLoops and runLoopModes.
 */
- (NSRunLoop*)runLoop
{
  if (nil == runLoop)
  {
    return [NSRunLoop currentRunLoop];
  }
  else
  {
    return runLoop;
  }
}

- (NSString*)runLoopMode
{
  if (nil == runLoopMode)
  {
    return NSDefaultRunLoopMode;
  }
  else
  {
    return runLoopMode;
  }
}

/**
 * Reschedule all timers and watchers in the current run loop. This will
 * potentially add the timers and watchers to more than one run loop.
 */
- (void)reschedule
{
  NSMapEnumerator watchEnum = NSEnumerateMapTable(watchers);
  NSMapEnumerator timerEnum = NSEnumerateMapTable(timers);
  NSTimer *aTimer = nil;
  DKWatcher *aWatcher = nil;
  NSRunLoop *rl = nil;
  NSString *rlMode = nil;
  void *watch = NULL;
  void *timeout = NULL;
  [lock lock];
  rlMode = [self runLoopMode];
  rl = [self runLoop];
  while (NSNextMapEnumeratorPair(&watchEnum, &timeout, (void**)&aWatcher))
  {
    [aWatcher reschedule];
  }

  while (NSNextMapEnumeratorPair(&timerEnum, &watch, (void**)&aTimer))
  {
    if ([aTimer isValid])
    {
      [rl addTimer: aTimer
           forMode: rlMode];
    }
  }
  [lock unlock];

  NSEndMapTableEnumeration(&watchEnum);
  NSEndMapTableEnumeration(&timerEnum);
}

- (void)dealloc
{
  NSFreeMapTable(watchers);
  NSFreeMapTable(timers);
  [lock release];
  [runLoopMode release];
  [super dealloc];
}

/**
 * Lets libdbus add a timeout.
 */
- (BOOL)addTimeout: (DBusTimeout*)timeout
      withInterval: (int)milliSeconds
{
  NSTimer *timer = nil;
  NSTimeInterval interval = (milliSeconds / 1000.0);
  NSAssert(timeout, @"Missing timeout data during D-Bus event handling.");
  // Just return if we already have a timer for this timeout:
  if (NSMapGet(timers,timeout))
  {
    return YES;
  }

  //Create the timer, saving the DBusTimeout pointer for later use.
  timer = [NSTimer timerWithTimeInterval: MAX(interval, 0.1)
                                  target: self
                                selector: @selector(handleTimeout:)
                                userInfo: [NSValue valueWithPointer: timeout]
                                 repeats: YES];
  if (timer == nil)
  {
    return NO;
  }
  else
  {
    NSMapInsert(timers,timeout,timer);
    [[self runLoop] addTimer: timer
                     forMode: [self runLoopMode]];
    return YES;
  }
}

/**
 * Lets libdbus remove a timeout it doesn't need anymore.
 */
- (void)removeTimeout: (DBusTimeout*)timeout
{
  NSTimer *timer = nil;
  NSAssert(timeout, @"Missing timeout data during D-Bus event handling.");
  timer = NSMapGet(timers,timeout);
  if (nil != timer)
  {
    [timer invalidate];
    NSMapRemove(timers,timeout);
  }
}

/**
 * Callback method for timers.
 */
- (void)handleTimeout: (NSTimer*)timer
{
  DBusTimeout *timeout = (DBusTimeout*)[(NSValue*)[timer userInfo] pointerValue];
  NSAssert(timeout, @"Missing timeout data during D-Bus event handling.");
  NSDebugMLog(@"Handling timeout");
  dbus_timeout_handle(timeout);
  /*
   * Note: dbus_timeout_handle() returns FALSE on OOM, but the documentation
   * specifies we just ignore that and retry the next time the timeout fires.
   */
}

/**
 * Called by libdbus to drain the message queue.
 */
- (void)dispatchForConnection: (NSValue*)value
{
  DBusConnection *conn = (DBusConnection*)[value pointerValue];
  DBusDispatchStatus status;
  // If called with nil, we dispatch for the default connection:
  if ((value != nil) && (conn != connection))
  {
    // This should not happen and could be a sign of some corruption.
    NSWarnMLog(@"Called to dispatch for non-local connection durng D-Bus event handling.");
    return;
  }

  do
  {
    // We drain all messages instead of waiting for the next run loop iteration:
    status = dbus_connection_dispatch(connection);
  } while (DBUS_DISPATCH_DATA_REMAINS == status);
}

/**
 * Adds a file descriptor that libdbus wants to monitor.
 */
- (BOOL)addWatch: (DBusWatch*)watch
{
  NSInteger fd = -1;
  DKWatcher *watcher = nil;
  NSAssert(watch, @"Missing watch data during D-Bus event handling.");

# if defined(__MINGW__)
  // As per D-Bus documentation, WinSock is used on Windows platforms.
  fd = dbus_watch_get_socket(watch);
# else
  fd = dbus_watch_get_unix_fd(watch);
# endif

  if (-1 == fd)
  {
    return NO;
  }
  else
  {
    watcher = [[DKWatcher alloc] initWithWatch: watch
                                    andContext: self
                                         forFd: fd];
    if (nil == watcher)
    {
      return NO;
    }
    NSMapInsert(watchers, watch, watcher);
    // The map table has retained the watcher, we can release it:
    [watcher release];
  }
  return YES;
}

/**
 * Remove a file descriptor from the list of those monitored.
 */
- (void)removeWatch: (DBusWatch*)watch
{

  DKWatcher *watcher = nil;
  NSAssert(watch, @"Missing watch data during D-Bus event handling.");
  watcher = NSMapGet(watchers,watch);
  if (nil != watcher)
  {
    [watcher unmonitorForEvents];
    NSMapRemove(watchers, watch);
  }
}
@end


#define CTX(x) DKRunLoopContext *ctx = (DKRunLoopContext*)x;\
  do { NSCAssert(x, @"Missing context data during D-Bus event handling.");} while (0)


static dbus_bool_t
DKTimeoutAdd(DBusTimeout *timeout, void *data)
{
  CTX(data);
  NSCAssert(timeout, @"Missing timeout data during D-Bus event handling.");
  NSDebugMLog(@"Timout added");
  if (NO == (BOOL)dbus_timeout_get_enabled(timeout))
  {
    return TRUE;
  }
  return (dbus_bool_t)[ctx addTimeout: timeout
                         withInterval: dbus_timeout_get_interval(timeout)];
}

static void
DKTimeoutRemove(DBusTimeout *timeout, void *data)
{
  CTX(data);
  NSCAssert(timeout, @"Missing timeout data during D-Bus event handling.");
  NSDebugMLog(@"Timeout removed");
  [ctx removeTimeout: timeout];
}

static void
DKTimeoutToggled(DBusTimeout *timeout, void *data)
{
  /*
   * Note: This is the easy solution, not sure whether we can be smarter about
   * this.
   */
  NSDebugMLog(@"Timeout toggled");
  DKTimeoutRemove(timeout, data);
  DKTimeoutAdd(timeout, data);
}

static dbus_bool_t
DKWatchAdd(DBusWatch *watch, void *data)
{
  CTX(data);
  NSCAssert(watch, @"Missing watch data during D-Bus event handling.");
  NSDebugMLog(@"Watch added");
  if (!dbus_watch_get_enabled(watch))
  {
    return YES;
  }
  return (dbus_bool_t)[ctx addWatch: watch];
}

static void
DKWatchRemove(DBusWatch *watch, void *data)
{
  CTX(data);
  NSCAssert(watch, @"Missing watch data during D-Bus event handling.");
  NSDebugMLog(@"Removed watch");
  [ctx removeWatch: watch];
}

static void
DKWatchToggled(DBusWatch *watch, void *data)
{
  /*
   * Note: This is the easy solution, not sure whether we can be smarter about
   * this.
   */
  NSDebugMLog(@"Watch toggled");
  DKWatchRemove(watch, data);
  DKWatchAdd(watch, data);
}

static void
DKRelease(void *data)
{
  NSDebugMLog(@"D-Bus calls release on something!");
  [(id)data release];
}

static void
DKWakeUp(void *data)
{
  CTX(data);
  NSDebugMLog(@"Starting runLoop on D-Bus request");
  // If we are woken up, we surely need to dispatch new messages:
  [[ctx runLoop] performSelector: @selector(dispatchForConnection:)
                          target: ctx
                        argument: nil
                           order: 0
                           modes: [NSArray arrayWithObject: [ctx runLoopMode]]];
}

static void
DKUpdateDispatchStatus(DBusConnection *conn,
  DBusDispatchStatus status,
  void *data)
{
  NSValue *connectionPointer;
  CTX(data);
  NSCAssert(conn, @"Missing connection data during D-Bus event handling");
  NSDebugMLog(@"Dispatch status changed to %d", status);
  switch (status)
  {
    case DBUS_DISPATCH_COMPLETE:
      NSDebugMLog(@"Dispatch complete");
      return;
    case DBUS_DISPATCH_NEED_MEMORY:
      NSDebugMLog(@"Insufficient memory for dispatch, will try again later");
      return;
    case DBUS_DISPATCH_DATA_REMAINS:
      NSDebugMLog(@"Will schedule handling of messages.");
  }
  connectionPointer = [NSValue valueWithPointer: conn];
  [[ctx runLoop] performSelector: @selector(dispatchForConnection:)
                          target: ctx
                        argument: connectionPointer
                           order: 0
                           modes: [NSArray arrayWithObject: [ctx runLoopMode]]];
}
