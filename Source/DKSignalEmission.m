/** Implementation for the DKSignalEmission class which sends
    sends signals from local proxies.

   Copyright (C) 2014 Free Software Foundation, Inc.

   Written by:  Niels Grewe <niels.grewe@halbordnung.de>
   Created: January 2014

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

#import "DKSignal.h"
#import "DKSignalEmission.h"
#import "DKObjectPathNode.h"
#import "DKProxy+Private.h"
#import "DKPort+Private.h"
#import "DKEndpointManager.h"
#import <Foundation/NSException.h>
#import <Foundation/NSInvocation.h>
#import <GNUstepBase/NSDebug+GNUstepBase.h>

#include <dbus/dbus.h>

@interface DKSignalEmission (Private)
- (void)serializeArgumentsFromUserInfo: (NSDictionary*)dict
                            intoSignal: (DKSignal*)signal;
@end

@implementation DKSignalEmission


+ (void)emitSignal: (DKSignal*)signal
               for: (id<DKExportableObjectPathNode>)proxy
          userInfo: (NSDictionary*)dict
{
  DKSignalEmission *emissio =
    [[DKSignalEmission alloc] initWithProxy: proxy
                                    signal: signal
                                  userInfo: dict];
  NS_DURING
    {
      [emissio sendAsynchronously];
    }
  NS_HANDLER
    {
      [emissio release];
      [localException raise];
    }
  NS_ENDHANDLER
  [emissio release];
}
- (id) initWithProxy: (id<DKExportableObjectPathNode>)aProxy
             signal: (DKSignal*)aSignal
           userInfo: (NSDictionary*)dict
{
  DBusMessage *theSignal = NULL;
  DKEndpoint *ep = [[aProxy proxyParent] _endpoint];
  // Sanity check:
  if ((nil == aSignal) || (nil == aProxy) || (nil == ep))
  {
    [self release];
    return nil;
  }
  const char *path = [[aProxy _path] UTF8String];
  const char *interface = [[aSignal interface] UTF8String];
  const char *member = [[aSignal name] UTF8String];
  theSignal = dbus_message_new_signal(path, interface, member);
  if (NULL == theSignal)
  {
    NSDebugMLog(@"libdbus wouldn't create signal %s.%s for %s",
      interface, member, path);
    [self release];
    return nil;
  }
  if (nil == (self = [super initWithDBusMessage: theSignal
                                    forEndpoint: ep
                           preallocateResources: YES]))
  {
    dbus_message_unref(theSignal);
    return nil;
  }
  // The superclass takes ownership of the message, 
  // relinquish the retain count we inherited from libdbus
  dbus_message_unref(theSignal);
  // Marshall the user info into the message.
  NS_DURING
  {
    [self serializeArgumentsFromUserInfo: dict
                              intoSignal: aSignal];
  }
  NS_HANDLER
  {
    [self release];
    return nil;
  }
  NS_ENDHANDLER
  return self;
}



- (void)serializeArgumentsFromUserInfo: (NSDictionary*)dict
                            intoSignal: (DKSignal*)signal
{
  DBusMessageIter iter;

  dbus_message_iter_init_append(msg, &iter);
  NSDebugMLog(@"Serializing user info contents into signal");
  NS_DURING
  {
    [signal marshallUserInfo: dict
                 intoIterator: &iter];
  }
  NS_HANDLER
  {
    NSWarnMLog(@"Could not notifcation into D-Bus signal. Exception raised: %@", localException);
    [localException raise];
  }
  NS_ENDHANDLER
}

/**
 * -send: is being called by the endpoint manager only.
 */
- (BOOL)send: (id)ignored
{
  [self send];
  return YES;
}

- (void)sendAsynchronously
{
  // DBusKit rule #1 is that all interaction with libdbus happens from one
  // thread, so we go via the endpoint manager to schedule sending the reply or
  // error out. The superclass logic is sufficient for us in this case.
  [[DKEndpointManager sharedEndpointManager] boolReturnForPerformingSelector: @selector(send:)
    target: self
    data: NULL
    waitForReturn: NO];
}

@end
