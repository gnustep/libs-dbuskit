/** Interface for the DKOutgoingProxy class for vending objects to D-Bus.
   Copyright (C) 2012 Free Software Foundation, Inc.

   Written by:  Niels Grewe <niels.grewe@halbordnung.de>
   Created: January 2012

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

#import "DKProxy+Private.h"


/**
 * Instance of the DKOutgoingProxy class are used to broker the exchange between
 * local objects and other clients on D-Bus.
 */
@interface DKOutgoingProxy : DKProxy
{
  @private
  /**
   * The represented object.
   */
  id object;
}
+ (id) proxyWithParent: (DKProxy*)rootProxy
                object: (id)anObject;
@end
