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
#import "DKProxy+Private.h"
#import "DKEndpoint.h"

#import <Foundation/NSArray.h>
#import <Foundation/NSConnection.h>
#import <Foundation/NSDate.h>
#import <Foundation/NSDebug.h>
#import <Foundation/NSInvocation.h>
#import <Foundation/NSLock.h>
#import <Foundation/NSPort.h>
#import <Foundation/NSPortCoder.h>
#import <Foundation/NSPortMessage.h>
#import <Foundation/NSRunLoop.h>

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

@interface DKPort (DKPortPrivate)
/**
 * Performs checks to ensure that the corresponding D-Bus service and object
 * path exist and sends a message to the delegate NSConnection object containing
 * an encoded DKProxy.
 */
- (BOOL) _returnProxyForPath: (NSString*)path
         utilizingComponents: (NSArray*)components
                    fromPort: (NSPort*)receivePort;

- (id)initForBusType: (DKDBusBusType)type;
@end


@implementation DKPort

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

- (id) initWithRemote: (NSString*)aRemote
           atEndpoint: (DKEndpoint*)anEndpoint
{
  if (nil == (self = [super init]))
  {
    return nil;
  }

  if (nil == anEndpoint)
  {
    // Default to an endpoint to the session bus if none is given.
    anEndpoint = [[DKEndpoint alloc] initWithWellKnownBus: DBUS_BUS_SESSION];
    ASSIGN(endpoint, anEndpoint);
    [anEndpoint release];
  }
  else
  {
    ASSIGN(endpoint, anEndpoint);
  }
  ASSIGNCOPY(remote, aRemote);
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
  DKEndpoint *ep = [[[DKEndpoint alloc] initWithWellKnownBus: type] autorelease];
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
 * This is the main method used to dispatch stuff from the DO system to D-Bus.
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
  *fds=0;
  *count=0;
}

/**
 * Required for NSPort compatibility.
 */
- (NSUInteger)reservedSpaceLength
{
  return 0;
}

- (void) dealloc
{
  [endpoint release];
  [remote release];
  [super dealloc];
}

- (DKProxy*)_proxyAtPath: (NSString*)path
{

  /* Check whether the remote service exists. */
  if (NO == [self hasValidRemote])
  {
    return nil;
  }

  // TODO: Check whether the path is valid.
  return [[[DKProxy alloc] initWithEndpoint: endpoint
                                andService: remote
                                   andPath: path] autorelease];

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

   proxy = [self _proxyAtPath: path];
   if (nil == proxy)
   {
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
@end
