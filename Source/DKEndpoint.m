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
#import "DKEndpointManager.h"

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
}

- (id)_initWithConnection: (DBusConnection*)connection;
- (NSRunLoop*)runLoop;
- (NSString*)runLoopMode;
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

- (id) initWithConnection: (DBusConnection*)conn
                     info: (NSDictionary*)infoDict
{
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
    [self release];
    return nil;
  }

    ASSIGN(info, infoDict);
  return self;
}

- (DBusConnection*)connection
{
  return connection;
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
     newEndpoint = [[DKEndpointManager sharedEndpointManager] endpointForWellKnownBus: [(NSNumber*)data intValue]];
   }
   else
   {
     data = [info objectForKey: @"address"];
     newEndpoint = [[DKEndpointManager sharedEndpointManager] endpointForConnectionTo: (NSString*)data];
   }
   [self release];
   // We need to retain the endpoint because we got an autorelease one back:
   return [newEndpoint retain];
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
    [[DKEndpointManager sharedEndpointManager] removeEndpointForDBusConnection: connection];
    dbus_connection_unref(connection);
    connection = NULL;
    [ctx release];
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


/* Hashing and equality is easy: */

- (BOOL)isEqual: (DKEndpoint*)other
{
  // This should usually be the case, if everything works as expected:
  if (self == other)
  {
    return YES;
  }
  // Since libdbus will return unique connection objects, we simply test for
  // pointer equality.
  return (connection == [other DBusConnection]);
}

- (NSUInteger)hash
{
  // Again, the connection pointer uniquely represents the endpoint.
  return (NSUInteger)(uintptr_t)connection;
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
  /*
   * We might be deallocated due to a connection failure. In that case, we
   * cannot ask libdbus what kind of event we were watching for. Hence, we
   * remove ourselves from the loop for all event types.
   */
  [[ctx runLoop] removeEvent: (void*)(intptr_t)fileDesc
                        type: ET_RDESC
                     forMode: [ctx runLoopMode]
                         all: NO];
  [[ctx runLoop] removeEvent: (void*)(intptr_t)fileDesc
                        type: ET_WDESC
                     forMode: [ctx runLoopMode]
                         all: NO];
  [super dealloc];
}
@end

static DKEndpointManager *theManager;
static IMP performOnWorkerThread;

#define performOnWorkerThreadSelector @selector(boolReturnForPerformingSelector:target:data:waitForReturn:)

#define doPerformOnWorkerThread(target,selector,data,doWait) \
  performOnWorkerThread(theManager, performOnWorkerThreadSelector, selector, target, data, doWait)

#define ctxPerformOnWorkerThread(selector,data) doPerformOnWorkerThread(ctx,selector,data, NO)
#define syncCtxPerformOnWorkerThread(selector,data) (BOOL)(uintptr_t)doPerformOnWorkerThread(ctx,selector,data, YES)
@implementation DKRunLoopContext
+ (void)initialize
{
  if ([DKRunLoopContext class] == self)
  {
    theManager = [DKEndpointManager sharedEndpointManager];
    performOnWorkerThread = [theManager methodForSelector: performOnWorkerThreadSelector];
  }
}
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


- (void)dealloc
{
  NSFreeMapTable(watchers);
  NSFreeMapTable(timers);
  [runLoopMode release];
  [super dealloc];
}

/**
 * Lets libdbus add a timeout.
 */
- (BOOL)addTimeout: (DBusTimeout*)timeout
{
  NSTimer *timer = nil;
  int milliSeconds = dbus_timeout_get_interval(timeout);
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
    [theManager registerTimer: timer
                  fromContext: self];
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
    [theManager unregisterTimer: timer];
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
- (BOOL)dispatchForConnection: (DBusConnection*)conn
{
  // If called with nil, we dispatch for the default connection:
  if ((conn != NULL) && (conn != connection))
  {
    // This should not happen and could be a sign of some corruption.
    NSWarnMLog(@"Called to dispatch for non-local connection durng D-Bus event handling.");
    return NO;
  }

  while (DBUS_DISPATCH_DATA_REMAINS == dbus_connection_get_dispatch_status(connection))
  {
    // We drain all messages instead of waiting for the next run loop iteration:
    dbus_connection_dispatch(connection);
  };
  return YES;
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
    [theManager registerWatcher: watcher];
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
    [theManager unregisterWatcher: watcher];
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
  return (dbus_bool_t)syncCtxPerformOnWorkerThread(@selector(addTimeout:),timeout);
}

static void
DKTimeoutRemove(DBusTimeout *timeout, void *data)
{
  CTX(data);
  NSCAssert(timeout, @"Missing timeout data during D-Bus event handling.");
  NSDebugMLog(@"Timeout removed");
  ctxPerformOnWorkerThread(@selector(removeTimeout:),timeout);
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
  // DKTimeoutRemove immediately returns, but the ringbuffer perserves the
  // ordering
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
  return (dbus_bool_t)syncCtxPerformOnWorkerThread(@selector(addWatch:),watch);
}

static void
DKWatchRemove(DBusWatch *watch, void *data)
{
  CTX(data);
  NSCAssert(watch, @"Missing watch data during D-Bus event handling.");
  NSDebugMLog(@"Removed watch");
  ctxPerformOnWorkerThread(@selector(removeWatch:),watch);
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
  ctxPerformOnWorkerThread(@selector(dispatchForConnection:),NULL);
}

static void
DKUpdateDispatchStatus(DBusConnection *conn,
  DBusDispatchStatus status,
  void *data)
{
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
  /* FIXME: libdbus has issues unless we synchronise on connection dispatch. */
  if (syncCtxPerformOnWorkerThread(@selector(dispatchForConnection:), conn))
  {
    return;
  };
}
