/** Interface for the DKSignalEmission class for sending D-Bus signals.

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

#import "DKMessage.h"
@class DKSignal, NSDictionary;
@protocol DKExportableObjectPathNode;

/**
 * The DKSignalEmission can be used to send signals from a local proxy
 */
@interface DKSignalEmission: DKMessage

/**
 * Creates a signal emission message and sends it right away.
 */
+ (void)emitSignal: (DKSignal*)signal
               for: (id<DKExportableObjectPathNode>)proxy
          userInfo: (NSDictionary*)dict;
/**
 * Designated initialiser that sets up the signal for the specified
 * proxy. This involves serializing the arguments into D-Bus format,
 * but does include sending the message.
 */
- (id) initWithProxy: (id<DKExportableObjectPathNode>)aProxy
              signal: (DKSignal*)aSignal
            userInfo: (NSDictionary*)userInfo;

- (void)sendAsynchronously;
@end
