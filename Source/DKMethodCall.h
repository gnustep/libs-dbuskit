/** Interface for the DKMethodCall class for calling D-Bus methods.

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

#import "DKMessage.h"
#import <Foundation/NSDate.h>
@class DKMethod, DKProxy, NSInvocation;

/**
 * The DKMethodCall can be used to call methods on a remote object.
 */
@interface DKMethodCall: DKMessage
{
  /**
   * The method for which this is a call.
   */
  DKMethod *method;

  /**
   * The DKMethodCall object will read the arguments from the invocation and
   * also store the return value in it.
   */
   NSInvocation *invocation;

  /**
   * The timeout for the call;
   */
   NSInteger timeout;
}

/**
 * Initializes the method call to be sent to the object represented by the
 * proxy. This involves serializing the arguments from the invocation into D-Bus
 * format, but does include sending the message.
 */
- (id) initWithProxy: (DKProxy*)aProxy
              method: (DKMethod*)aMethod
          invocation: (NSInvocation*)anInvocation
             timeout: (NSTimeInterval)interval;

/**
 * Initializes the method call to be sent to the object represented by the
 * proxy. This involves serializing the arguments from the invocation into D-Bus
 * format, but does include sending the message. This method sets up a default
 * timeout.
 */
- (id) initWithProxy: (DKProxy*)aProxy
              method: (DKMethod*)aMethod
          invocation: (NSInvocation*)anInvocation;

/**
 * Sends the method call asynchronously via D-Bus. User code should retrieve
 * the DKPendingCall object corresponding to this method call in order to get
 * the return value.
 * FIXME: Not yet implemented
 */
- (void)sendAsynchronously;

/**
 * Sends the method call via D-Bus and waits until it completes (i.e. the result
 * of the call is deserialized as the return value of the invocation.)
 */
- (void)sendSynchronously;
@end
