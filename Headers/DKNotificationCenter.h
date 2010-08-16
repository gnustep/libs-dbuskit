/** Interface for DKNotificationCenter to handle D-Bus signals.
   Copyright (C) 2010 Free Software Foundation, Inc.

   Written by:  Niels Grewe <niels.grewe@halbordnung.de>
   Created: August 2010

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

#import <Foundation/NSObject.h>
#import <DBusKit/DKPort.h>
@class DKEndpoint, DKProxy, NSDictionary, NSHashTable, NSRecursiveLock,
  NSMapTable, NSMutableDictionary, NSNotification, NSString;

/**
 * The DKNotificationCenter class allows Objective-C objects to watch for
 * notifications from other D-Bus objects ('signals' in the D-Bus dialect) or to
 * post notifications to D-Bus themselves. You can use this class just as you
 * would use an NSNotificationCenter. Notification names will be mapped to
 * signals as follows: If the introspection data for theD-Bus signal carries an
 * <code>org.gnustep.openstep.notification</code> annotation ,the value of this
 * annotation will be used as the name of the notification. Otherwise, the
 * notification name will be
 * <code>DKSignal_&lt;InterfaceName&gt;_&lt;SignalName&gt;</code>.
 *
 * Additionally, D-Bus provides a rather sophisticated matching mechanism to
 * catch only signal emissions with a specific signature. This mechanism is
 * available to applications through the
 * -addObserver:selector:signal:interface:sender:destination: method and its
 * more specific variants. Unfortunately, at this time, you need to specify
 * identical match rules when removing the observer again.
 *
 * Every notification from D-Bus carries a reference to a proxy for the object
 * emitting the signal and also guarantees that the following keys are present
 * in the dictionary:
 * <deflist>
 * <term>member</term><desc>The name of the signal being emitted (e.g.
 * "NameOwnerChanged"</desc>
 * <term>interface</term><desc>The name of the interface to which the signal
 * belongs. (e.g. "org.freedesktop.DBus").</desc>
 * <term>sender</term><desc>The service emitting the signal (e.g.
 * "org.freedesktop.DBus"). This will always be the unique name of the service,
 * even if you registered the signal for another name.</desc>
 * <term>path</term><desc>The path to the object emitting the signal (e.g
 * "/org/freedesktop/DBus").</desc>
 * <term>destination</term><desc>The intended receiver of the signal, might be
 * empty if the signal was broadcast, which is usually the case.</desc>
 * </deflist>
 * Additionally the userInfo dictionary will contain keys for every argument
 * specified in the signal, named "arg<em>N</em>". The dictionary might also
 * contain further keys if <code>org.gnustep.openstep.notification.key</code>
 * annotations were available.
 */
@interface DKNotificationCenter: NSObject
{
  @private
  /**
   * The endpoint object used by the notification center to communicate with
   * D-Bus.
   */
  DKEndpoint *endpoint;


  /**
   * Set of all rules the notification center is going to match.
   */
  NSHashTable *observables;

  /**
   * The signalInfo dictionary holds DKSignal objects indexed by their interface
   * and signal names. Proxies that discover signals during introspection will
   * register them here.
   */
  NSMutableDictionary *signalInfo;

  /**
   * The notificationNames dictionary holds mappings between notification names
   * and D-Bus signals. They will either be obtained by explicit registration
   * (with -registerNotificationName:asSignal:inInterface:) or from an
   * "org.gnustep.openstep.notification" annotation in the introspection data of
   * the signal.
   */
  NSMutableDictionary *notificationNames;

  /**
   * The inverse mapping for the notificationNames dictionary, allowing lookup
   * of names by signal.
   */
  NSMapTable *notificationNamesBySignal;

  /**
   * The lock protecting the tables.
   */
   NSRecursiveLock *lock;
}

/**
 * Returns a notification center for the session message bus.
 */
+ (id)sessionBusCenter;

/**
 * Returns a notification center for the system message bus.
 */
+ (id)systemBusCenter;

/**
 * Returns a notification center for the specified bus type.
 */
+ (id)centerForBusType: (DKDBusBusType)type;

/**
 * Watches the bus for signals matching <var>notificationName</var> from
 * <var>sender</var>. If one of them is <code>nil</code>, the value will not be
 * used to restrict the notifications delivered to the observer. Notifications
 * are delivered by calling <var>notifySelector</var> on <var>observer</var> as
 * a receiver. Neither can be <code>nil</code> and <var>notifySelector</var>
 * takes exactly one argument (the notification).
 */
- (void)addObserver: (id)observer
           selector: (SEL)notifySelector
               name: (NSString*)notificationName
	     object: (DKProxy*)sender;

/**
 * Similar to -addObserver:selector:name:object: but allows to specify both
 * sender and destination of the notification.
 */
- (void)addObserver: (id)observer
           selector: (SEL)notifySelector
               name: (NSString*)notificationName
	     sender: (DKProxy*)sender
        destination: (DKProxy*)destination;

/**
 * Similar to -addObserver:selector:name:sender:destination: but allows finer
 * grained control over what signals to match. (E.g. it would be possible to
 * request all notifications matching a particular interface only.).
 */
-  (void)addObserver: (id)observer
            selector: (SEL)notifySelector
	      signal: (NSString*)signalName
           interface: (NSString*)interfaceName
              sender: (DKProxy*)sender
         destination: (DKProxy*)destination;

/**
 * Similar to -addObserver:selector:signal:interface:sender:destination: but
 * additionally allows matching a single argument. Due to D-Bus constraints,
 * <var>index</var> must be less than 64. The signal will only be matched if the
 * value of the argument at <var>index</var> <em>is equal</em> to
 * the value of <var>filter</var>. Additionally, this matching is limited to
 * string arguments.
 */
-  (void)addObserver: (id)observer
            selector: (SEL)notifySelector
              signal: (NSString*)signalName
           interface: (NSString*)interfaceName
              sender: (DKProxy*)sender
         destination: (DKProxy*)destination
              filter: (NSString*)filter
             atIndex: (NSUInteger) index;

/**
 * Similar to
 * -addObserver:selector:signal:interface:sender:destination:filter:atIndex: but
 * allows matching more than one signal. The argument list needs to be
 * terminated by <code>nil</code>. If you want to match the first argument,
 * specify that particular match as the first one and set <var>firstIndex</var>
 * to <code>0</code>.
 */
-  (void)addObserver: (id)observer
            selector: (SEL)notifySelector
              signal: (NSString*)signalName
           interface: (NSString*)interfaceName
              sender: (DKProxy*)sender
         destination: (DKProxy*)destination
   filtersAndIndices: (NSString*)firstFilter, NSUInteger firstindex, ...;

/**
 * Removes all observation activities involving the <var>observer</var>.
 */
- (void)removeObserver: (id)observer;

/**
 * Removes all observation activities matching the arguments specified.
 * The match is inclusive. Every observation for a more specific rule will also
 * be removed.
 */
- (void)removeObserver: (id)observer
                  name: (NSString*)notificationName
                object: (DKProxy*)sender;

/**
 * Removes all observation activities matching the arguments specified.
 * The match is inclusive. Every observation for a more specific rule will also
 * be removed.
 */
- (void)removeObserver: (id)observer
                  name: (NSString*)notificationName
   	        sender: (DKProxy*)sender
           destination: (DKProxy*)destination;

/**
 * Removes all observation activities matching the arguments specified.
 * The match is inclusive. Every observation for a more specific rule will also
 * be removed.
 */
- (void)removeObserver: (id)observer
                signal: (NSString*)signalName
             interface: (NSString*)interfaceName
                object: (DKProxy*)sender;

/**
 * Removes all observation activities matching the arguments specified.
 * The match is inclusive. Every observation for a more specific rule will also
 * be removed.
 */
- (void)removeObserver: (id)observer
                signal: (NSString*)signalName
             interface: (NSString*)interfaceName
   	        sender: (DKProxy*)sender
           destination: (DKProxy*)destination;

/**
 * Removes all observation activities matching the arguments specified.
 * The match is inclusive. Every observation for a more specific rule will also
 * be removed.
 */
-  (void)removeObserver: (id)observer
                 signal: (NSString*)signalName
              interface: (NSString*)interfaceName
                 sender: (DKProxy*)sender
            destination: (DKProxy*)destination
                 filter: (NSString*)filter
                atIndex: (NSUInteger) index;

/**
 * Removes all observation activities matching the arguments specified.
 * The match is inclusive. Every observation for a more specific rule will also
 * be removed.
 */
-  (void)removeObserver: (id)observer
                 signal: (NSString*)signalName
              interface: (NSString*)interfaceName
                 sender: (DKProxy*)sender
            destination: (DKProxy*)destination
      filtersAndIndices: (NSString*)firstFilter, NSUInteger firstindex, ...;


/** NOTE: Not yet implemented. */
- (void)postNotification: (NSNotification*)notification;

/** NOTE: Not yet implemented. */
- (void)postNotificationName: (NSString*)name
                      object: (id)sender;

/** NOTE: Not yet implemented. */
- (void)postSignalName: (NSString*)signalName
             interface: (NSString*)interfaceName
                object: (id)sender;

/** NOTE: Not yet implemented. */
- (void)postNotificationName: (NSString*)name
                      object: (id)sender
                    userInfo: (NSDictionary*)info;

/** NOTE: Not yet implemented. */
- (void)postSignalName: (NSString*)signalName
             interface: (NSString*)interfaceName
                object: (id)sender
              userInfo: (NSDictionary*)info;

/**
 * This method allows notification names to be registered for specific signals.
 * E.g.:
 * <example>
 * [[DKNotificationCenter sessionBusCenter] registerNotificationName: @"DKNameChanged"
 *                                                          asSignal: @"NameOwnerChanged"
 *                                                       inInterface: @"org.freedesktop.DBus"];
 * </example>
 * would deliver all "<code>NameOwnerChanged</code>" emissions as notifications
 * named "<code>DKNameChanged</code>". The method returns <code>NO</code> if the
 * notification name has already been registered.
 */
- (BOOL)registerNotificationName: (NSString*)notificationName
                        asSignal: (NSString*)signalName
                     inInterface: (NSString*)interface;
@end
