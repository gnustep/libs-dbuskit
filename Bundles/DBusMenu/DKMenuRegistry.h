/** A registry object for exporting the main menu to D-Bus
   Copyright (C) 2013 Free Software Foundation, Inc.

   Written by:  Niels Grewe <niels.grewe@halbordnung.de>
   Created: December 2013

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

   <title>DKMenuRegistry reference</title>
   */

#import <Foundation/NSObject.h>

@class DKProxy, DKMenuProxy, NSMenu, NSMutableIndexSet, NSWindow;
@protocol com_canonical_AppMenu_Registrar;

/**
 * This class is designed to be used in GNUstep themes to allow 
 * them to export the application's main menu to D-Bus so that
 * it can be accessed by a global menu server. The menu server 
 * has to implement the com.canonical.AppMenu.Registrar interface
 * and needs to be accessed via the methods defined in 
 * com.canonical.dbusmenu.
 *
 * Conventionally you would integrate into a theme as follows:
 *
 * 1. Try to load the DBusMenu bundle, and keep in mind that some
 *    users won't have it installed.
 * 2. Instantiate the shared menu registry using +sharedRegistry.
 *    This method will return nil if no menu server is available.
 * 3. Make sure that the NSWindows95InterfaceStyle is set for the menu.
 *    Otherwise you will not receive the necessary calls to update the
 *    remote menu.
 * 4. Forward calls to -[GSTheme setMenu:forWindow:] to the registry.
 *    This will make sure that the representation shown in the menu server
 *    corresponds to the local one.
 *
 * Caveat emptor: Using the remote menu will not work for custom NSViews 
 * embedded in a menu item.
 */
@interface DKMenuRegistry : NSObject
{
  id<NSObject,com_canonical_AppMenu_Registrar> registrar;
  DKMenuProxy *menuProxy;
  DKProxy *busProxy;
  NSMutableIndexSet *windowNumbers;
}

/**
 * Obtain a reference to the shared menu registry. Returns nil
 * when an object implementing the app menu registrar protocol
 * is not available on the session bus.
 */
+ (id)sharedRegistry;

/**
 * This method is designed to be called from
 * [GSTheme setMenu:forWindow:]
 */
- (void)setMenu: (NSMenu*)menu forWindow: (NSWindow*)window;
@end
