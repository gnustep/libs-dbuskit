/** Interface for DKNonAutoInvalidatingPort used for bus objects.
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

/**
 * This class is used as the port class for proxies to the D-Bus bus objects.
 * They need to be treated differently than user-level ports because they are
 * not allowed to trigger reentrancy into DKDBus via the notification center.
 */
@interface DKNonAutoInvalidatingPort: DKPort

@end
