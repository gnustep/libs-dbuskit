/** Category on NSConnection to facilitate D-Bus integration
   Copyright (C) 2010 Free Software Foundation, Inc.

   Written by:  Niels Grewe <niels.grewe@halbordnung.de>
   Created: July 2010

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

#import "DBusKit/NSConnection+DBus.h"
#import "DBusKit/DKPort.h"
#import "DBusKit/DKProxy.h"

#import <Foundation/NSConnection.h>
#import <Foundation/NSString.h>

#import <GNUstepBase/NSDebug+GNUstepBase.h>


@interface DKPort (DKPortPrivate)
- (DKProxy*)_proxyAtPath: (NSString*)path;
@end

@implementation NSConnection (DBus)


- (DKProxy*)proxyAtPath: (NSString*)path
{
  id sp = [self sendPort];
  if (NO == [sp isKindOfClass: [DKPort class]])
  {
    NSWarnMLog(@"Not attempting to find proxy at path '%@' for non D-Bus port", path);
    return nil;
  }
  return [(DKPort*)sp _proxyAtPath: path];
}

@end
