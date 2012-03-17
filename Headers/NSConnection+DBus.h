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


#import <Foundation/NSConnection.h>

@class DKProxy, NSString;
@interface NSConnection (DBus)

/**
 * Returns a proxy to D-Bus object located at the specified D-Bus object path.
 * Will return <code>nil</code> if used for native DO connections.
 */
- (DKProxy*)proxyAtPath: (NSString*)path;


/**
 * Vends the named <var>object</var> at the specified D-Bus object
 * <var>path</var>. Users should note that the registered names of a D-Bus port
 * do not act as namespaces for object paths. It is thus advisable not to use
 * the root path "/" to export objects.
 *
 * For native DO connections this method is only effective if the
 * <var>path</var> is "/", in which case it is equivalent to calling
 * -rootObject:.
 */
- (void)setObject: (id)object
           atPath: (NSString*)path;
@end
