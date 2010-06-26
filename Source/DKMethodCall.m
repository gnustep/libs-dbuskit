/** Implementation of the DKMethodCall class for calling D-Bus methods.

   Copyright (C) 2010 Free Software Foundation, Inc.

   Written by:  Niels Grewe <niels.grewe@halbordnung.de>
   Created: June 2010

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

#import "DKMethodCall.h"
#import "DBusKit/DKProxy.h"
#import "DKEndpoint.h"
#import "DKMethod.h"

#import <Foundation/NSDate.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSException.h>
#import <Foundation/NSInvocation.h>
#import <Foundation/NSRunLoop.h>
#import <Foundation/NSString.h>

#import <GNUstepBase/NSDebug+GNUstepBase.h>
@interface DKProxy (DKProxyPrivate)
- (NSString*)_path;
- (NSString*)_service;
- (DKEndpoint*)_endpoint;
@end

@interface DKMethodCall (Private)
- (BOOL) serialize;
@end

@implementation DKMethodCall
- (id) initWithProxy: (DKProxy*)aProxy
              method: (DKMethod*)aMethod
          invocation: (NSInvocation*)anInvocation
              boxing: (BOOL)boxingRequested
{
  DBusMessage *theMessage = NULL;
  DKEndpoint *theEndpoint = [aProxy _endpoint];
  const char* dest = [[aProxy _service] UTF8String];
  const char* path = [[aProxy _path] UTF8String];
  const char* interface = [[aMethod interface] UTF8String];
  const char* methodName = [[aMethod name] UTF8String];

  if (((nil == aProxy) || (nil == aMethod)) || (nil == anInvocation))
  {
    [self release];
    return nil;
  }
  theMessage = dbus_message_new_method_call(dest,
    path,
    interface,
    methodName);
  if (NULL == theMessage)
  {
    [self release];
    return nil;
  }

  /*
   * Initialize the superclass. Since we need the DBusPendingCall, we cannot use
   * the resource preallocation feature. The superclass takes owenership of the
   * DBusMessage.
   */
  if (nil == (self = [super initWithDBusMessage: theMessage
                                    forEndpoint: theEndpoint
                           preallocateResources: NO]))
  {
    dbus_message_unref(theMessage);
    return nil;
  }

  dbus_message_unref(theMessage);

  ASSIGN(invocation,anInvocation);
  ASSIGN(method,aMethod);
  doBox = boxingRequested;
  if (NO == [self serialize])
  {
    [self release];
    return nil;
  }
  return self;
}

- (BOOL)serialize
{
  BOOL didSucceed = YES;
  DBusMessageIter iter;

  dbus_message_iter_init_append(msg, &iter);
  NS_DURING
  {
    [method marshallFromInvocation: invocation
                      intoIterator: &iter
                       messageType: DBUS_MESSAGE_TYPE_METHOD_CALL
                            boxing: doBox];
  }
  NS_HANDLER
  {
    NSWarnMLog(@"Could not marshall arguments into D-Bus message. Exception raised: %@",
      localException);
    didSucceed = NO;
  }
  NS_ENDHANDLER
  return didSucceed;
}
- (BOOL)hasObjectReturn
{
  return  (0 == strcmp(@encode(id), [[invocation methodSignature] methodReturnType]));
}

- (void)handleReplyFromPendingCall: (DBusPendingCall*)pending
                             async: (BOOL)didAsyncOperation
{
  DBusMessage *reply = dbus_pending_call_steal_reply(pending);
  int msgType;
  DBusError error;
  NSException *errorException = nil;
  DBusMessageIter iter;
  // This is the future we are going to use for asynchronous resolution.
  id future = nil;

  // Bad things would happen if we tried this
  NSAssert(!(didAsyncOperation && (NO == [self hasObjectReturn])),
    @"Filling asynchronous return values for non-objects is impossible.");

  if (NULL == reply)
  {
    [NSException raise: @"DKDBusMethodReplyException"
                format: @"Could not obtain reply for pending D-Bus method call."];
  }

  msgType = dbus_message_get_type(reply);

  // Only accept error messages or method replies:
  if (NO == ((msgType == DBUS_MESSAGE_TYPE_METHOD_RETURN)
    || (msgType == DBUS_MESSAGE_TYPE_ERROR)))
  {
    [NSException raise: @"DKDBusMethodReplyException"
                format: @"Invalid message type (%ld) in D-Bus reply", msgType];
  }

  // Handle the error case:
  if (msgType == DBUS_MESSAGE_TYPE_ERROR)
  {
    NSString *errorName = nil;
    NSString *errorMessage = nil;
    NSDictionary *infoDict = nil;

    dbus_set_error_from_message(&error, reply);
    if (dbus_error_is_set(&error))
    {
      NSString *exceptionName = @"DKDBusMethodReplyException";
      NSString *exceptionReason = @"An remote object returned an error upon a method call.";
      errorName = [NSString stringWithUTF8String: error.name];
      errorMessage = [NSString stringWithUTF8String: error.message];

      // Check whether the error actually comes from another object exported by
      // DBusKit. If so, we can set the exception name to something the user
      // expects.
      if (([errorName hasPrefix: @"org.gnustep.objc.exception."])
	&& ([errorName length] > 28))
      {
	exceptionName = [errorName substringFromIndex: 27];
	exceptionReason = errorMessage;
      }
      infoDict = [[NSDictionary alloc] initWithObjectsAndKeys:
        errorMessage, errorName,
	invocation, @"invocation", nil];
      errorException = [NSException exceptionWithName: exceptionName
                                                reason: exceptionReason
                                              userInfo: infoDict];
      [infoDict release];
    }
    else
    {
      errorException = [NSException exceptionWithName: @"DKDBusMethodReplyException"
                                               reason: @"Undefined error in D-Bus method reply"
                                             userInfo: nil];
    }
      if (didAsyncOperation)
      {
	// TODO: Pass the exception to the future. It will raise once user code
	// tries to reference the object.
	return;
      }
      else
      {
	[errorException raise];
      }
    }


  // Implicit else if (type == DBUS_MESSAGE_TYPE_METHOD_RETURN)

  if (YES == didAsyncOperation)
  {
    // Extract the future from the invocation, we need it for later use:
    [invocation getReturnValue: &future];
  }


  // We need to catch possible exceptions in order to pass them to the future if
  // we are operating asynchronously.
  NS_DURING
  {
    NSAssert(dbus_message_iter_init(reply, &iter),
      @"Out of memory when creating D-Bus message iterator.");
    [method unmarshallFromIterator: &iter
                    intoInvocation: invocation
                       messageType: DBUS_MESSAGE_TYPE_METHOD_RETURN
                            boxing: doBox];
  }
  NS_HANDLER
  {
    errorException = localException;
  }
  NS_ENDHANDLER

  if (YES == didAsyncOperation)
  {
    id realObject = nil;
    if (nil != errorException)
    {
      //TODO: Pass the exception to the future.
    }

    // Extract the real returned object from the invocation:
    [invocation getReturnValue: &realObject];

    // TODO: Pass the object to the future. Message sends to the future will no
    // longer block.
  }
  else
  {
    if (nil != errorException)
    {
      [errorException raise];
    }

  }
}

- (void)sendAsynchronouslyExpectingReplyUntil: (NSTimeInterval)interval
{
  //TODO: Implement asynchronous behaviour.
}

- (void)sendSynchronouslyAndWaitUntil: (NSTimeInterval)interval
{
  DBusPendingCall *pending;
  // -1 means default timeout
  uint32_t timeout = -1;
  BOOL couldSend = NO;
  // TODO: Once we allow the runloop to be changed, we need to do locking here.
  NSRunLoop *runLoop = [endpoint runLoop];
  NSString *runLoopMode = [endpoint runLoopMode];

  if (0 != interval)
  {
    // NSTimeInterval specifies seconds, we need milli-seconds
    timeout = (uint32_t)(interval * 1000.0);
  }
  couldSend = (BOOL)dbus_connection_send_with_reply([endpoint DBusConnection],
    msg,
    &pending,
    timeout);
  if (NO == couldSend)
  {
    [NSException raise: @"DKDBusOutOfMemoryException"
                format: @"Out of memory when sending D-Bus message."];

  }
  if (NULL == pending)
  {
    [NSException raise: @"DKDBusDisconnectedException"
                format: @"Disconnected from D-Bus when sending message."];

  }
  /*
   * TODO: We might need to flush the connection:
   * [endpoint flush];
   */

  do
  {
    // Run the runloop until we get our result back
    [runLoop runMode: runLoopMode
          beforeDate: [NSDate dateWithTimeIntervalSinceNow: 0.1]];
  } while (NO == (BOOL)dbus_pending_call_get_completed(pending));

  //Now we are sure that we don't need the message any more.
  dbus_message_unref(msg);
  msg = NULL;

  //TODO: Once we allow the runLoop to be changed, we need to unlock here.
  NS_DURING
  {
    [self handleReplyFromPendingCall: pending
                               async: NO];
  }
  NS_HANDLER
  {
    // Throw away the pending call
    dbus_pending_call_unref(pending);
    pending = NULL;
    [localException raise];
  }
  NS_ENDHANDLER
  dbus_pending_call_unref(pending);
  pending = NULL;
}
@end
