/** Implementation of the DKPortNameServer for integrating D-Bus name lookup in
    NSConnection.
   Copyright (C) 2011 Free Software Foundation, Inc.

   Written by:  Niels Grewe <niels.grewe@halbordnung.de>
   Created: February 2011

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
#import "DBusKit/DKPortNameServer.h"

#import "DKEndpointManager.h"

#import <Foundation/NSDictionary.h>
#import <Foundation/NSHashTable.h>
#import <Foundation/NSString.h>
#import <Foundation/NSException.h>

#include <stdint.h>
#include <dbus/dbus.h>

@interface DKPortNameServer (Private)

- (id) initWithBusType: (DKDBusBusType)type;
@end

static DKPortNameServer *systemBusNameServer;
static DKPortNameServer *sessionBusNameServer;

@implementation DKPortNameServer

+ (void)initialize
{
  if (self == [DKPortNameServer class])
  {
    DKEndpointManager *manager = [DKEndpointManager sharedEndpointManager];
    [manager enterInitialize];
    systemBusNameServer = [[DKPortNameServer alloc] initWithBusType: DKDBusSystemBus];
    sessionBusNameServer = [[DKPortNameServer alloc] initWithBusType: DKDBusSessionBus];
    [manager leaveInitialize];
  }
}

+ (id)sharedSystemBusPortNameServer
{
  return systemBusNameServer;
}


+ (id)sharedSessionBusPortNameServer
{
  return sessionBusNameServer;
}

+ (id)sharedPortNameServerForBusType: (DKDBusBusType)type
{
  if (DKDBusSessionBus == type)
  {
    return sessionBusNameServer;
  }
  else if (DKDBusSystemBus == type)
  {
    return systemBusNameServer;
  }
  return nil;
}

+ (id)allocWithZone: (NSZone*)zone
{
  if ((nil == systemBusNameServer) || (nil == sessionBusNameServer))
  {
    return [super allocWithZone: zone];
  }
  return nil;
}

- (id) initWithBusType: (DKDBusBusType)type
{
  if (nil == (self = [super init]))
  {
    return nil;
  }

  if (((nil == systemBusNameServer) && (DKDBusSystemBus != type))
    || ((nil == sessionBusNameServer) && (DKDBusSessionBus != type))
    || ((nil != systemBusNameServer) && (nil != sessionBusNameServer)))
  {
    [self release];
    return nil;
  }

  busType = type;
  queuedNames  = NSCreateHashTable(NSObjectHashCallBacks, 3);
  activeNames = NSCreateHashTable(NSObjectHashCallBacks, 3);


  return self;
}


- (DKPort*)portForName: (NSString*)name
{
  DKPort *thisPort = [[[DKPort alloc] initWithRemote: name
                                               onBus: busType] autorelease];
  return thisPort;
}

- (DKPortNameRegistrationStatus)registerPort: (DKPort*)port
                                        name: (NSString*)name
{
  return [self registerPort: port
                       name: name
                      flags: 0];
}
- (DKPortNameRegistrationStatus)registerPort: (DKPort*)port
                                        name: (NSString*)name
                                       flags: (DKPortNameFlags)flags
{
  [NSException raise: NSGenericException
              format: @"Not implemented"];
  return DKPortNameExists;
}

- (void)removePortForName: (NSString*)name
{

}

- (NSUInteger) retainCount
{
    return UINT_MAX;
}

- (oneway void) release
{
    //Ignore, it's a singleton;
}
- (id) autorelease
{
    return self;
}
- (id) retain
{
    return self;
}

- (void)dealloc
{
  NSFreeHashTable(queuedNames);
  NSFreeHashTable(activeNames);
  [super dealloc];
}
@end
