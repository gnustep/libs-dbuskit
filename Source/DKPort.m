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
#import "DKEndpoint.h"

#import <Foundation/NSArray.h>
#import <Foundation/NSDate.h>
#import <Foundation/NSInvocation.h>
#import <Foundation/NSPort.h>
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

static Class DKPortAbstractClass;
static Class DKPortConcreteClass;

@implementation DKPort
+ (void)initialize
{
  /*
   * Preload the class pointers to avoid expensive class message sends on every
   * +port call.
   */
  Class abstractClass = [DKPort class];
  if (self == abstractClass)
  {
    DKPortAbstractClass = abstractClass;
    DKPortConcreteClass = [DKSessionBusPort class];
  }
}

+ (NSPort*)port
{
  if (self == DKPortAbstractClass)
  {
    return [[[DKPortConcreteClass alloc] init] autorelease];
  }
  else
  {
    return [[[self alloc] init] autorelease];
  }
}

- (id) initWithRemote: (NSString*)aRemote
           atEndpoint: (DKEndpoint*)anEndpoint
{
  // We can just modify the isa pointer because the abstract and concrete
  // classes share the same ivar layout.
  if (DKPortAbstractClass == isa)
  {
    isa = DKPortConcreteClass;
    // Call again with the proper implementation:
    return [self initWithRemote: aRemote];
  }

  // Proper implementation: Only reached if this is a concrete class.
  if (nil == (self = [super init]))
  {
    return nil;
  }
  ASSIGNCOPY(remote, aRemote);
  ASSIGN(endpoint, anEndpoint);
  return self;
}

- (id) initWithRemote: (NSString*)aRemote
{
  return [self initWithRemote: aRemote
                   atEndpoint: nil];
}

- (id) init
{
  return [self initWithRemote: nil];
}


/**
 * This is the main method used to dispatch stuff from the DO system to D-Bus.
 */
- (BOOL)sendBeforeDate: (NSDate *)limitDate
                 msgid: (NSUInteger)msgid
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
      NSLog(@"Got rootproxy request for remote %@", remote);
      break;
    case METHODTYPE_REQUEST:
      /* TODO:
       *  1. Check whether the remote side exists
       *  2. Decode D-Bus interface from the components
       *  3. Send D-Bus request for introspection data (possibly trigger
       *     generation of the cache)
       *  4. Schedule generation of reply for NSConnection to consume.
       */
       NSLog(@"Got methodtype request");
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
      NSLog(@"Got CONNECTION_SHUTDOWN");
      break;
    case PROXY_RETAIN:
      NSLog(@"Got PROXY_RETAIN");
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
      NSLog(@"Got reply type %ld", msgid);
      break;
    case PROXY_AT_PATH_REQUEST:
      /*
       * TODO:
       * 1. Check whether the remote side exists.
       * 2. Discover the object path.
       * 3. Create proxy
       */
       NSLog(@"Special proxy request");
      break;
    case PROXY_AT_PATH_REPLY:
       /*
        * TODO:
	* 1. Do something
	*/
        NSLog(@"Special proxy reply");
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
  NSLog(@"RunLoop events: Ignoring event of type %ld", type);
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

@end

@implementation DKSessionBusPort
- (id)initWithRemote: (NSString*)aRemote
{
  DKEndpoint *ep = [[DKEndpoint alloc] initWithWellKnownBus: DBUS_BUS_SESSION];
  if (nil == (self = [self initWithRemote: aRemote
                               atEndpoint: ep]))
  {
    [ep release];
    return nil;
  }
  [ep release];
  return self;
}
@end


@implementation DKSystemBusPort
- (id)initWithRemote: (NSString*)aRemote
{
  DKEndpoint *ep = [[DKEndpoint alloc] initWithWellKnownBus: DBUS_BUS_SYSTEM];
  if (nil == (self = [self initWithRemote: aRemote
                               atEndpoint: ep]))
  {
    [ep release];
    return nil;
  }
  [ep release];
  return self;
}
@end
