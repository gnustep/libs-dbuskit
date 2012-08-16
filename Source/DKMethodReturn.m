/** Implementation for the DKMethodReturn class which sends
    replies for methods called by remote objects.

   Copyright (C) 2012 Free Software Foundation, Inc.

   Written by:  Niels Grewe <niels.grewe@halbordnung.de>
   Created: May 2012

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

#import "DKMethod.h"
#import "DKMethodReturn.h"
#import "DKObjectPathNode.h"
#import "DKProxy+Private.h"
#import "DKPort+Private.h"
#import "DKEndpointManager.h"
#import <Foundation/NSException.h>
#import <Foundation/NSInvocation.h>
#import <GNUstepBase/NSDebug+GNUstepBase.h>

#include <dbus/dbus.h>
@implementation DKMethodReturn

- (void)deserializeArguments
{

  DBusMessageIter iter;
  dbus_message_iter_init_append(original, &iter);
  NSDebugMLog(@"Deserializing arguments from method call");
  NS_DURING
  {
    [method unmarshallFromIterator: &iter
                    intoInvocation: invocation
                       messageType: DBUS_MESSAGE_TYPE_METHOD_CALL];
  }
  NS_HANDLER
  {
    NSWarnMLog(@"Could not unmarshall arguments from D-Bus message. Exception raised: %@", localException);
    [localException raise];
  }
  NS_ENDHANDLER
}

- (id) initAsReplyToDBusMessage: (DBusMessage*)aMsg
                       forProxy: (id<DKExportableObjectPathNode>)aProxy
                         method: (DKMethod*)aMethod
                     invocation: (NSInvocation*)anInvocation
		   sendOutright: (BOOL)sendNow
{
  DBusMessage *theReply = NULL;
  DKEndpoint *ep = [[aProxy proxyParent] _endpoint];
  // Sanity check:
  if ((NULL == aMsg) || (nil == aMethod) || (nil == anInvocation) || (nil == ep))
  {
    [self release];
    return nil;
  }
  theReply = dbus_message_new_method_return(aMsg);
  if (nil == (self = [super initWithDBusMessage: dbus_message_new_method_return(aMsg)
                                    forEndpoint: ep
                           preallocateResources: YES]))
  {
    dbus_message_unref(theReply);
    return nil;
  }
  // The superclass takes ownership of the reply, relinquish the retain count we
  // inherited from libdbus
  dbus_message_unref(theReply);
  original = aMsg;
  dbus_message_ref(original);
  ASSIGN(method,aMethod);
  ASSIGN(invocation,anInvocation);
  // Unmarshall the arguments from the method call.
  NS_DURING
  {
    [self deserializeArguments];
  }
  NS_HANDLER
  {
    [self release];
    return nil;
  }
  NS_ENDHANDLER
  if (NO == sendNow)
  {
    [invocation retainArguments];
  }
  return self;
}

- (id) initAsReplyToDBusMessage: (DBusMessage*)aMsg
                       forProxy: (id<DKExportableObjectPathNode>)aProxy
                         method: (DKMethod*)aMethod
                     invocation: (NSInvocation*)anInvocation
{
  return [self initAsReplyToDBusMessage: aMsg
                               forProxy: aProxy
                                 method: aMethod
                             invocation: anInvocation
                           sendOutright: NO];
}


- (void)serialize
{
  DBusMessageIter iter;

  dbus_message_iter_init_append(msg, &iter);
  NSDebugMLog(@"Serializing return value into reply");
  NS_DURING
  {
    [method marshallFromInvocation: invocation
                      intoIterator: &iter
                       messageType: DBUS_MESSAGE_TYPE_METHOD_RETURN];
  }
  NS_HANDLER
  {
    NSWarnMLog(@"Could not marshall return value into D-Bus message. Exception raised: %@", localException);
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
  NS_DURING
  {
    [invocation invoke];
    [self serialize];
  }
  NS_HANDLER
  {
    DBusMessage *error = dbus_message_new_error(original,
      [[localException name] UTF8String],
      [[localException reason] UTF8String]);
    // In the case of error, we send the error instead of the message.
    dbus_message_unref(msg);
    msg = error;
  }
  NS_ENDHANDLER
  // DBusKit rule #1 is that all interaction with libdbus happens from one
  // thread, so we go via the endpoint manager to schedule sending the reply or
  // error out. The superclass logic is sufficient for us in this case.
  [[DKEndpointManager sharedEndpointManager] boolReturnForPerformingSelector: @selector(send:)
    target: self
    data: NULL
    waitForReturn: NO];
}


+ (void)replyToDBusMessage: (DBusMessage*)aMsg
                  forProxy: (id<DKExportableObjectPathNode>)aProxy
		    method: (DKMethod*)aMethod
		invocation: (NSInvocation*)anInvocation
{
  DKMethodReturn *reply = [[self alloc] initAsReplyToDBusMessage: aMsg
                                                        forProxy: aProxy
                                                          method: aMethod
                                                      invocation: anInvocation
                                                    sendOutright: YES];
  if (nil == reply)
  {
    NSWarnMLog(@"Could not construct reply to message for %@", [aMethod name]);
  }
  [reply sendAsynchronously];
  [reply release];
}


- (void)dealloc
{
  [invocation release];
  [method release];
  dbus_message_unref(original);
  original = NULL;
  [super dealloc];
}
@end
