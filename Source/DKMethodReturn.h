/** Interface for the DKMethodReturn and DKErrorEmission classes which send
    replies for methods called by remote objects.

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

@class DKMethod, NSException, NSInvocation;
@protocol DKExportableObjectPathNode;

/**
 * The DKMethodReturn object can be used to return values for method calls from
 * a remote object.
 */
@interface DKMethodReturn: DKMessage
{
  /**
   * An invocation on a local object whose return value is supposed to be send
   * to the caller.
   */
  NSInvocation *invocation;

  /**
   * The method type according to which the invocation should be marshalled.
   */
  DKMethod *method;

  /**
   * The D-Bus message we are replying to. We need to reference it in case the
   * invocation generates an exception.
   */
   DBusMessage *original;
}

/**
 * Convenience method to construct and send a reply to a method call right away.
 * This method will invoke the invocation to generate the return value.
 */
+ (void)replyToDBusMessage: (DBusMessage*)aMsg
                  forProxy: (id<DKExportableObjectPathNode>)aProxy
                    method: (DKMethod*)aMethod
                invocation: (NSInvocation*)anInvocation;
/**
 * Initializes the method return in order to send it to the caller specified by
 * the incoming message via the endpoint to which the outgoing proxy is
 * connected. This will not send out the reply.
 */
- (id) initAsReplyToDBusMessage: (DBusMessage*)aMsg
                       forProxy: (id<DKExportableObjectPathNode>)aProxy
                         method: (DKMethod*)aMethod
                     invocation: (NSInvocation*)anInvocation;


/**
 * Invokes the invocation and sends out the reply. Since DKMethodReturn
 * lets libdbus preallocate the resources needed for sending the reply, this
 * method is guranteed to succeed.
 */
- (void)sendAsynchronously;
@end

