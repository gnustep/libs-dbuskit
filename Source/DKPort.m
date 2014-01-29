/** Implementation of the DKPort class for NSConnection integration.
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
   */

#import "DBusKit/DKPort.h"
#import "DBusKit/DKNotificationCenter.h"
#import "DKProxy+Private.h"
#import "DKPort+Private.h"
#import "DKOutgoingProxy.h"
#import "DKEndpoint.h"
#import "DKEndpointManager.h"

#import <Foundation/NSArray.h>
#import <Foundation/NSConnection.h>
#import <Foundation/NSDate.h>
#import <Foundation/NSDebug.h>
#import <Foundation/NSException.h>
#import <Foundation/NSInvocation.h>
#import <Foundation/NSLock.h>
#import <Foundation/NSMapTable.h>
#import <Foundation/NSNotification.h>
#import <Foundation/NSPort.h>
#import <Foundation/NSPortCoder.h>
#import <Foundation/NSPortMessage.h>
#import <Foundation/NSRunLoop.h>
#import <Foundation/NSValue.h>

#include <dbus/dbus.h>


/*
 * Enumeration of GNUstep DO message IDs, will need to be kept in sync with
 * GNUstepBase/DistributedObjects.h.
 */
enum {
 METHOD_REQUEST = 0,
 METHOD_REPLY,
 ROOTPROXY_REQUEST,
 ROOTPROXY_REPLY,
 CONNECTION_SHUTDOWN,
 METHODTYPE_REQUEST,
 METHODTYPE_REPLY,
 PROXY_RELEASE,
 PROXY_RETAIN,
 RETAIN_REPLY,
 // Custom types needed by D-Bus
 PROXY_AT_PATH_REQUEST = 254,
 PROXY_AT_PATH_REPLY = 255
};

@protocol DBus
- (NSArray*)ListNames;
- (NSArray*)ListActivatableNames;
@end

/*
 * We need to access the private -[NSPortCoder _components] method.
 */
@interface NSPortCoder (UnhideComponents)
- (NSArray*)_components;
@end

@interface DKPort (DKPortInternal)
/**
 * Performs checks to ensure that the corresponding D-Bus service and object
 * path exist and sends a message to the delegate NSConnection object containing
 * an encoded DKProxy.
 */
- (BOOL) _returnProxyForPath: (NSString*)path
         utilizingComponents: (NSArray*)components
                    fromPort: (NSPort*)receivePort;

/**
 * Called by the notification center when the remote is removed from the bus.
 */
- (void)_remoteDisappeared: (NSNotification*)notification;

/**
 * Called by the notification center when the port was disconnected from the
 * bus.
 */
- (void)_disconnected: (NSNotification*)notification;

/**
 * Creates the map table from object paths to proxies.
 */
- (void)_createObjectPathMap;

- (id)initForBusType: (DKDBusBusType)type;
@end

static DBusObjectPathVTable _DKDefaultObjectPathVTable;
/**
 * We share local port objects so that we get a consistent
 * view of the object hierarchy, but this means we have to
 * protect their creation with a lock.
 */
static NSLock *sharedPortLock;
static DKPort *sharedSessionPort;
static DKPort *sharedSystemPort;


@implementation DKPort

+ (void)initialize
{
  if ([self isEqual: [DKPort class]])
  {
    // We do not need the unregistration callback
    _DKDefaultObjectPathVTable.unregister_function = NULL;
    _DKDefaultObjectPathVTable.message_function = _DKObjectPathHandleMessage;
    sharedPortLock = [NSLock new];
  }
}

+ (DBusObjectPathVTable)_DBusDefaultObjectPathVTable
{
  return _DKDefaultObjectPathVTable;
}

+ (NSPort*)port
{
  return [self sessionBusPort];
}

+ (id)portForBusType: (DKDBusBusType)type
{
  return [[[self alloc] initForBusType: type] autorelease];
}

+ (id)sessionBusPort
{
  return [self portForBusType: DKDBusSessionBus];
}

+ (id)systemBusPort
{
  return [self portForBusType: DKDBusSystemBus];
}

+ (void)enableWorkerThread
{
  [[DKEndpointManager sharedEndpointManager] enableThread];
}

- (void)_registerNotifications
{
  DKDBusBusType busType = [endpoint DBusBusType];
  DKNotificationCenter *center = [DKNotificationCenter centerForBusType: busType];
  /*
   * If the port is non-local (i.e. has a specified name), we set up the
   * notification center to inform us when the remote disappears. The whole
   * process would be pointless for ports to the org.freedesktop.DBus service,
   * so we avoid observing its name.
   */
  if ((0 != [remote length])
    && (NO == [@"org.freedesktop.DBus" isEqualToString: remote]))
  {
    /*
     * Setup observation rule: arg0 carries the name, arg2 the new owner, which
     * is empty if the name disappeared.
     */
    NSDictionary *filters = [NSDictionary dictionaryWithObjectsAndKeys:
     remote, [NSNumber numberWithUnsignedInteger: 0],
     @"", [NSNumber numberWithUnsignedInteger: 2], nil];
    [center addObserver: self
               selector: @selector(_remoteDisappeared:)
                 signal: @"NameOwnerChanged"
              interface: @"org.freedesktop.DBus"
                 sender: [DKDBus busWithBusType: busType]
            destination: nil
                filters: filters];
  }
  /*
   * For all ports, we want to watch for the Disconnected signal on the
   * o.fd.DBus.Local interface. This is a pseudo-signal that will be generated
   * in-process when libdbus looses the connection to the dbus-daemon.
   */
  [center addObserver: self
             selector: @selector(_disconnected:)
	       signal: @"Disconnected"
	    interface: [NSString stringWithUTF8String: DBUS_INTERFACE_LOCAL]
	       sender: nil
	  destination: nil];
}

- (id) initWithRemote: (NSString*)aRemote
           atEndpoint: (DKEndpoint*)anEndpoint
{
  BOOL createSharedPort = NO;
  if (0 == [aRemote length])
    {
      if ((nil == anEndpoint)
        || (DKDBusSessionBus == [anEndpoint DBusBusType]))
        {
          if (sharedSessionPort == nil)
            {
               [sharedPortLock lock];
               if (sharedSessionPort == nil)
                 {
                   createSharedPort = YES;
                 }
               else
                 {
                    [sharedPortLock unlock];
                 }
            }
          if (NO == createSharedPort)
            {
              NSDebugMLog(@"Reusing shared session port");
              [self release];
              return [sharedSessionPort retain];
            }
        }
      else if (DKDBusSystemBus == [anEndpoint DBusBusType])
        {
          if (sharedSystemPort == nil)
            {
               [sharedPortLock lock];
               if (sharedSystemPort == nil)
                 {
                   createSharedPort = YES;
                 }
               else
                 {
                   [sharedPortLock unlock];
                 }
            }
          if (NO == createSharedPort)
            {
              NSDebugMLog(@"Reusing shared system port");
              [self release];
              return [sharedSystemPort retain];
            }
        }
    }

  if (nil == (self = [super init]))
  {
    if (createSharedPort)
      {
        [sharedPortLock unlock];
      }
    return nil;
  }

  if (nil == anEndpoint)
  {
    // Default to an endpoint to the session bus if none is given.
    anEndpoint = [[DKEndpointManager sharedEndpointManager] endpointForWellKnownBus: DBUS_BUS_SESSION];
  }

  ASSIGN(endpoint, anEndpoint);
  ASSIGNCOPY(remote, aRemote);

  /*
   * With an empty remote, we might possibly be a local port. So we create the
   * lock that is used to lazily create the object path map-table.
   */
  if (0 == [remote length])
  {
    objectPathLock = [NSLock new];
  }

  [self _registerNotifications];
  if (createSharedPort)
    {
      DKDBusBusType ty = [endpoint DBusBusType];
      if (DKDBusSessionBus == ty)
	{
          NSDebugMLog(@"Creating shared session port");
	  ASSIGN(sharedSessionPort, self);
	}
      else if (DKDBusSystemBus == ty)
	{
          NSDebugMLog(@"Creating shared system port");
	  ASSIGN(sharedSystemPort, self);
	}
      [sharedPortLock unlock];
    }

  return self;
}

- (id) initWithRemote: (NSString*)aRemote
{
  return [self initWithRemote: aRemote
                   atEndpoint: nil];
}

- (id) initWithRemote: (NSString*)aRemote
                onBus: (DKDBusBusType)type
{
  DKEndpoint *ep = [[DKEndpointManager sharedEndpointManager] endpointForWellKnownBus: type];
  return [self initWithRemote: aRemote
                   atEndpoint: ep];
}

- (id) initForBusType: (DKDBusBusType)type
{
  return [self initWithRemote: nil
                        onBus: type];
}

- (id) init
{
  return [self initWithRemote: nil];
}

/**
 * Determines whether the service that the ports connects to is valid.
 */
- (BOOL) hasValidRemoteOnBus: (id<DBus>)bus
{
  if ([remote isEqualToString: @"org.freedesktop.DBus"])
  {
    // It is save to assume that the bus object is available.
    return YES;
  }

  if ([[bus ListNames] containsObject: remote])
  {
    return YES;
  }

  if ([[bus ListActivatableNames] containsObject: remote])
  {
    return YES;
  }
  else
  {
    NSWarnMLog(@"D-Bus service %@ is neither available nor activatable",
      remote);
    return NO;
  }
}


- (BOOL) hasValidRemote
{
  return [self hasValidRemoteOnBus: (id<DBus>)[DKDBus busWithBusType: [endpoint DBusBusType]]];
}


/**
 * Returns the present endpoint.
 */
- (DKEndpoint*)endpoint
{
  return endpoint;
}

/**
 * Returns the name of the remote.
 */
- (NSString*)serviceName
{
  return remote;
}


/**
 * Two ports are considered equal if they connect to the same service behind the
 * same endpoint.
 */
- (BOOL)isEqual: (DKPort*)other
{
  if (self == other)
  {
    return YES;
  }
  /*
   * Check whether the class of other is also DKPort. Only then we stand any
   * chance of being equal to it. Otherwise, we might crash because most NSPort
   * subclasses won't respond to -endpoint.
   */
  if (NO  == [other isKindOfClass: [DKPort class]])
  {
    return NO;
  }
  return ([endpoint isEqual: [other endpoint]]
    && [remote isEqual: [other serviceName]]);
}

- (NSUInteger)hash
{
  // Bitwise XOR the hashes of the two values we are using for equality tests:
  return ([endpoint hash] ^ [remote hash]);
}

/**
 * This is the main method used to dispatch stuff from the DO system to D-Bus.
 * Primarily we want to respond to ROOTPROXY_REQUEST, because everyting else
 * will be handled from DKProxy.
 */
- (BOOL)sendBeforeDate: (NSDate *)limitDate
                 msgid: (NSInteger)msgid
            components: (NSMutableArray *)components
	          from: (NSPort *)recievePort
              reserved: (NSUInteger)reserverdHeaderSpace
{

  /*
   * NOTE: I'm not sure whether every detail of D-Bus IPC should be processed
   * here. It might be easier to have the proxy take care of things like message
   * dispatch, etc.
   */

  switch (msgid)
  {
    case ROOTPROXY_REQUEST:
      /* TODO:
       * 1. Check whether the remote side exists by sending a ping
       * 2. Schedule generation of reply for NSConnection to consume
       */
      NSDebugMLog(@"Got rootproxy request for remote %@", remote);
      return [self _returnProxyForPath: @"/"
                   utilizingComponents: components
                              fromPort: recievePort];
    case METHODTYPE_REQUEST:
      /* TODO:
       *  1. Check whether the remote side exists
       *  2. Decode D-Bus interface from the components
       *  3. Send D-Bus request for introspection data (possibly trigger
       *     generation of the cache)
       *  4. Schedule generation of reply for NSConnection to consume.
       */
       NSDebugMLog(@"Got methodtype request");
       break;
    case METHOD_REQUEST:
      /*
       * TODO:
       * 1. Check whether the remote side exists
       * 2. Decode components (Where will the unboxing take place?)
       * 3. Generate and send the D-Bus message
       * 4. If this is not one-way, schedule waiting for the reply.
       */
    case CONNECTION_SHUTDOWN:
      /*
       * TODO: Cleanup
       */
      NSDebugMLog(@"Got CONNECTION_SHUTDOWN");
      break;
    case PROXY_RETAIN:
      NSDebugMLog(@"Got PROXY_RETAIN");
      break;
    case METHOD_REPLY:
    /*
     * TODO:
     * 1. Decode components (how will we box them?)
     * 2.
     */
    case ROOTPROXY_REPLY:
    case METHODTYPE_REPLY:
    case PROXY_RELEASE:
    case RETAIN_REPLY:
      NSDebugMLog(@"Got reply type %ld", msgid);
      break;
    case PROXY_AT_PATH_REQUEST:
      /*
       * TODO:
       * 1. Check whether the remote side exists.
       * 2. Discover the object path.
       * 3. Create proxy
       */
       NSDebugMLog(@"Special proxy request");
      break;
    case PROXY_AT_PATH_REPLY:
       /*
        * TODO:
	* 1. Do something
	*/
        NSDebugMLog(@"Special proxy reply");
      break;
    default:
      break;
  }
  return NO;
}


/**
 * Required for NSPort compatibility.
 */
- (void) receivedEvent: (void*)data
                  type: (RunLoopEventType)type
	         extra: (void*)extra
               forMode: (NSString*)mode
{
  NSDebugMLog(@"RunLoop events: Ignoring event of type %llu", (unsigned long long)type);
}

/**
 * Required for NSPort compatibility. Will make NSRunLoop leave us alone because
 * we don't have any file descriptors to watch.
 */
- (void) getFds: (int*)fds count: (int*)count
{
  if (NULL != fds)
  {
    *fds=0;
  }
  if (NULL != count)
  {
    *count=0;
  }
}

/**
 * Required for NSPort compatibility.
 */
- (NSUInteger)reservedSpaceLength
{
  return 0;
}

- (void)_cleanupExportedObjects
{
  [objectPathLock lock];
  [objectPathMap removeAllObjects];
  if (nil != proxyMap)
  {
    NSResetMapTable(proxyMap);
  }
  [objectPathLock unlock];
}

- (void)invalidate
{
  [[DKNotificationCenter centerForBusType: [endpoint DBusBusType]] removeObserver: self];
  [self _cleanupExportedObjects];
  // The implementation in NSPort sends out the appropriate notification.
  [super invalidate];
}

- (void)dealloc
{
  [self _unregisterAllObjects];
  [[DKNotificationCenter centerForBusType: [endpoint DBusBusType]] removeObserver: self];
  [endpoint release];
  [remote release];
  [objectPathLock lock];
  [objectPathMap release];
  [proxyMap release];
  [objectPathLock unlock];
  [objectPathLock release];
  [super dealloc];
}


- (void)_remoteDisappeared: (NSNotification*)n
{
  NSDictionary *userInfo = [n userInfo];
  NSString *name = [userInfo objectForKey: @"arg0"];
  NSString *newOwner = [userInfo objectForKey: @"arg2"];

  // Bail out if we got rubbish data from the notification:
  if ((NO == [@"" isEqualToString: newOwner])
    || (NO == [remote isEqualToString: name]))
  {
    return;
  }
  [self invalidate];
}

- (void)_disconnected: (NSNotification*)n
{
  [self invalidate];
}
/**
 * Performs checks to ensure that the corresponding D-Bus service and object
 * path exist and sends a message to the delegate NSConnection object containing
 * an encoded DKProxy.
 */
- (BOOL) _returnProxyForPath: (NSString*)path
         utilizingComponents: (NSArray*)components
                    fromPort: (NSPort*)receivePort
{

  int sequence = -1;
  NSPortCoder *seqCoder = nil;
  NSPortCoder *proxyCoder = nil;
  DKProxy *proxy = nil;
  NSPortMessage *pm = nil;

  if (NO == [self hasValidRemote])
  {
    return NO;
  }

  /* Decode the sequence number, we need it to send the correct reply. */
  seqCoder = [[NSPortCoder alloc] initWithReceivePort: receivePort
                                             sendPort: self
                                           components: components];

   [seqCoder decodeValueOfObjCType: @encode(int) at: &sequence];
   NSDebugMLog(@"Sequence number for proxy request: %d", sequence);
   [seqCoder release];

   /* Create and encode the proxy. */

   proxyCoder = [[NSPortCoder alloc] initWithReceivePort: receivePort
                                                sendPort: self
                                              components: nil];



   proxy = [DKProxy proxyWithPort: self
                             path: path];
   if (nil == proxy)
   {
     NSDebugMLog(@"Got nil proxy for %@ (path: %@).", self, path);
     [proxyCoder release];
     return NO;
   }

   [proxyCoder encodeValueOfObjCType: @encode(int) at: &sequence];
   [proxyCoder encodeObject: proxy];

   /* Wrap it in an NSPortMessage */

   pm = [[NSPortMessage alloc] initWithSendPort: self
                                    receivePort: receivePort
                                     components: [proxyCoder _components]];

  [pm setMsgid: ROOTPROXY_REPLY];

  /* Let the connection handle it */

  [[receivePort delegate] handlePortMessage: pm];

  /* Cleanup */

  [pm release];
  [proxyCoder release];
  return YES;
}


/*
 * Methods for local service ports.
 */


- (void)_createObjectPathMap
{
  if (nil != objectPathMap)
  {
    return;
  }

  [objectPathLock lock];

  if (nil != objectPathMap)
  {
    [objectPathLock unlock];
    return;
  }

  NS_DURING
  {
    objectPathMap = [NSMutableDictionary new];
    proxyMap = NSCreateMapTable(NSNonRetainedObjectMapKeyCallBacks,
    NSObjectMapValueCallBacks,
    10);
  }
  NS_HANDLER
  {
    [objectPathLock unlock];
    [localException raise];
  }
  NS_ENDHANDLER
  [objectPathLock unlock];
}

- (void)_DBusUnregisterProxyAtPath: (const char*)thePath
{
  dbus_connection_unregister_object_path([endpoint DBusConnection],
    thePath);
}

- (void)_unregisterAllObjects
{
  NSEnumerator *keyEnum = [[objectPathMap allKeys] objectEnumerator];
  NSString *path = nil;
  while (nil != (path = [keyEnum nextObject]))
  {
    [self _DBusUnregisterProxyAtPath: [path UTF8String]];
  }
  [self _cleanupExportedObjects];

}
- (void)_DBusRegisterProxy: (id<DKExportableObjectPathNode>)proxy
             asReplacement: (BOOL)isReplacement
{
  const char *path = [[proxy _path] UTF8String];
  DBusError err;
  DBusObjectPathVTable vTable;
  dbus_error_init(&err);
  if (isReplacement)
  {
    // Unregistration only using the path
    [self _DBusUnregisterProxyAtPath: path];
  }
  vTable = [proxy vTable];
  dbus_connection_try_register_object_path([endpoint DBusConnection],
    path,
    &vTable,
    (void*)proxy,
    &err);
  if (dbus_error_is_set(&err))
  {
    NSString *exceptionName = @"DKDBusUnknownException";
    NSString *message = [NSString stringWithUTF8String: err.message] ;
    if (dbus_error_has_name(&err, DBUS_ERROR_NO_MEMORY))
    {
      exceptionName = @"DKDBusOutOfMemoryException";
    }
    else if (dbus_error_has_name(&err, DBUS_ERROR_OBJECT_PATH_IN_USE))
    {
      exceptionName = @"DKDBusObjectPathAlreadyInUseException";
    }
    dbus_error_free(&err);
    [NSException raise: exceptionName
                format: @"%@", message];
  }
}

- (void)_DBusUnregisterProxy: (id<DKExportableObjectPathNode>)proxy
{
  [self _DBusUnregisterProxyAtPath: [[proxy _path] UTF8String]];
}

- (void)_fillInMissingNodes: (NSArray*)nodes
            forObjectAtLeaf: (id)object
{
  NSUInteger count = [nodes count];
  id<DKExportableObjectPathNode> lastNode = nil;
  id<DKExportableObjectPathNode> thisNode = nil;
  NSUInteger i;
  for (i = 0; i < count; i++)
  {
    id<DKExportableObjectPathNode> proxy = nil;
    NSString *component = [nodes objectAtIndex: i];
    lastNode = thisNode;
    thisNode = [[lastNode _children] objectForKey: component];

    if (nil == thisNode)
    {
      if (0 == i)
      {
	// At index 0 we have the root object path node
	component = @"/";
	lastNode = [[[DKRootObjectPathNode alloc] initWithPort: self] autorelease];
	rootNode = lastNode;
	proxy = lastNode;
        NSDebugMLog(@"Adding root object path node: %@", proxy);
      }

      if ((i + 1) == count)
      {
	proxy = [DKOutgoingProxy proxyWithName: component
	                                parent: lastNode
	                                object: object];
        NSDebugMLog(@"Adding proxy %@ at path %@", proxy, [proxy _path]);
	NSMapInsert(proxyMap, object, proxy);
      }
      else if (nil == proxy)
      {
	proxy = [[DKObjectPathNode alloc] initWithName: component
                                                parent: lastNode];
        NSDebugMLog(@"Inserting intermediate object path node at %@.", [proxy _path]);
      }
      thisNode = proxy;
      // Special case for the root, so it doesn't end up being its own child.
      if (proxy != lastNode)
      {
	[lastNode _addChildNode: proxy];
      }
      [objectPathMap setObject: proxy
                        forKey: [proxy _path]];

      NS_DURING
      {
        [self _DBusRegisterProxy: proxy asReplacement: NO];
      }
      NS_HANDLER
      {
	//Undo the local part of the unsuccessful registration
	[lastNode _removeChildNode: proxy];
	[objectPathMap removeObjectForKey: [proxy _path]];
	if (0 == [[objectPathMap allKeysForObject: proxy] count])
	{
	  NSMapRemove(proxyMap, object);
	}
	[localException raise];
      }
      NS_ENDHANDLER
    }
  }
}

- (void)_replaceProxy: (id<DKExportableObjectPathNode>)oldProxy
               atPath: (NSString*)path
            forObject: (id)object
{
  NSDebugMLog(@"Replacing proxy %@ with a new proxy for %@ at %@", oldProxy, object, path);
  NSDictionary *oldChildren = [oldProxy _children];
  id<DKExportableObjectPathNode> oldParent = nil;
  id<DKExportableObjectPathNode> newProxy = nil;
  if ([(id<NSObject>)oldProxy isKindOfClass: [DKObjectPathNode class]])
  {
     oldParent = [(DKObjectPathNode*)oldProxy parent];
  }
  else if ([@"/" isEqual: path])
  {
    // If we are installing a root path object, we use the cached root
    oldParent = rootNode;
  }
  else
  {
    // DKProxy doesn't record parents, only paths. So we need to look it up.
    oldParent = [objectPathMap objectForKey:
    [[oldProxy _path] stringByDeletingLastPathComponent]];
  }
  NSAssert((nil != oldParent), @"Unclean state in object path map.");

  /*
   * If we are removing the object, check whether we need a new placeholder
   * (i.e. when there are children further up the tree).
   */
  if (nil == object)
  {
    // If this is the last reference to the proxy, we remove it from the proxy
    // map.
    if (1 == [[objectPathMap allKeysForObject: oldProxy] count])
    {
      NSMapRemove(proxyMap, object);
    }
    if (0 != [oldChildren count])
    {
       newProxy = [[[DKObjectPathNode alloc] initWithName: [path lastPathComponent]
                                                   parent: oldParent] autorelease];
    }
  }
  else
  {
     newProxy = [DKOutgoingProxy proxyWithName: [path lastPathComponent]
                                        parent: oldParent
                                        object: object];
  }

  if (nil == newProxy)
  {
     [objectPathMap removeObjectForKey: path];
     [self _DBusUnregisterProxy: oldProxy];
  }
  else
  {
    NSEnumerator *nodeEnum = [oldChildren objectEnumerator];
    id<NSObject,DKExportableObjectPathNode> node = nil;
    while (nil != (node = [nodeEnum nextObject]))
    {
      [newProxy _addChildNode: node];
      // Only OPNs need reparenting, proxies are referred to by path
      // (which is maintained through replacements).
      if (YES == [node isKindOfClass: [DKObjectPathNode class]])
      {
	[(DKObjectPathNode*)node setParent: newProxy];
      }
    }
    [objectPathMap setObject: newProxy
                      forKey: path];
    NSMapInsert(proxyMap, object, newProxy);
    [self _DBusRegisterProxy: newProxy asReplacement: YES];
  }
}


- (void)_setObject: (id)object
            atPath: (NSString*)path
{
  // Don't bother registering anything at an empty or invalid path.
  if ((0 == [path length]) || ('/' != [path characterAtIndex: 0]))
  {
    [NSException raise: @"DKInvalidArgumentException"
                format: @"Object path '%@' is malformed.", path];
  }

  // Set up the tables as needed.
  if (nil == objectPathMap)
  {
    [self _createObjectPathMap];
  }
  [objectPathLock lock];
  NS_DURING
  {
    id<DKExportableObjectPathNode> oldProxy = [objectPathMap objectForKey: path];
    // Save state from the old proxy if necessary
    if (nil != oldProxy)
    {
      [self _replaceProxy: oldProxy
                   atPath: path
                forObject: object];
    }
    else
    {
      [self _fillInMissingNodes: [path pathComponents]
                forObjectAtLeaf: object];
    }

  }
  NS_HANDLER
  {
    [objectPathLock unlock];
    [localException raise];
  }
  NS_ENDHANDLER
  [objectPathLock unlock];

}

- (DKOutgoingProxy*)_autoregisterObject: (id)object
                             withParent: (DKProxy*)theParent
{
  DKOutgoingProxy *proxy = nil;
  NSString *parentPath = [theParent _path];
  NSString *rootPath = [@"/" isEqual: parentPath] ? @"" : parentPath;
  NSString *newPath = nil;
  if (nil == object)
  {
    return nil;
  }

  [objectPathLock lock];
  NS_DURING
  {
    // If the object was already installed, don't bother installing it again.
    proxy = NSMapGet(proxyMap, object);
    if (nil != proxy)
    {
      [proxy _DBusRetain];
      [objectPathLock unlock];
      return proxy;
    }

    // Else we generate an object path as follows: rootPath + "/" +
    // class_name + "-" + hex_pointer
    newPath = [NSString stringWithFormat: @"%@/%s-%p",
      rootPath,
      class_getName([object class]),
      (void*)object];
    [self _setObject: object
              atPath: newPath];
    proxy = NSMapGet(proxyMap, object);
  }
  NS_HANDLER
  {
    [objectPathLock unlock];
    [localException raise];
  }
  NS_ENDHANDLER
  [objectPathLock unlock];
  [proxy _setDBusIsAutoExported: YES];
  [proxy _DBusRetain];
  return proxy;
}




- (id<DKExportableObjectPathNode>)_objectPathNodeAtPath: (NSString*)path
{
  id<DKExportableObjectPathNode> res = nil;
  [objectPathLock lock];
  NS_DURING
  {
    res = [objectPathMap objectForKey: path];
  }
  NS_HANDLER
  {
    [objectPathLock unlock];
    [localException raise];
  }
  NS_ENDHANDLER
  [objectPathLock unlock];
  return res;
}

- (id<DKExportableObjectPathNode>)_proxyForObject: (id)obj
{
  id<DKExportableObjectPathNode> res = nil;
  [objectPathLock lock];
  NS_DURING
  {
    res = NSMapGet(proxyMap, obj);
  }
  NS_HANDLER
  {
    [objectPathLock unlock];
    [localException raise];
  }
  NS_ENDHANDLER
  [objectPathLock unlock];
  return res;
}

@end


DBusHandlerResult
_DKObjectPathHandleMessage(DBusConnection* connection,
  DBusMessage* message, void* receiver)
{
  return [(id<DKExportableObjectPathNode>)receiver handleDBusMessage: message];
}

