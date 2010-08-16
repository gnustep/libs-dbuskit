/** DKNotificationCenter class to handle D-Bus signals.
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

#import "DBusKit/DKNotificationCenter.h"
#import "DBusKit/DKPort.h"
#import "DKArgument.h"
#import "DKInterface.h"
#import "DKSignal.h"
#import "DKProxy+Private.h"

#import "DKEndpoint.h"

#import <Foundation/NSDebug.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSException.h>
#import <Foundation/NSHashTable.h>
#import <Foundation/NSLock.h>
#import <Foundation/NSMapTable.h>
#import <Foundation/NSMethodSignature.h>
#import <Foundation/NSNotification.h>
#import <Foundation/NSNull.h>
#import <Foundation/NSRunLoop.h>
#import <Foundation/NSSet.h>
#import <Foundation/NSString.h>

#import <GNUstepBase/NSDebug+GNUstepBase.h>

#include <stdint.h>
#include <stdarg.h>
#include <dbus/dbus.h>

@class DKObservation;

/**
 * DKObservable encapsulates information about a specific signal configuration
 * that is being observed by an object. It contains a match rule for userInfo
 * dictionaries created from signals and managed the observers for the signal.
 */
@interface DKObservable: NSObject
{
  /**
   * The rules that D-Bus is using to determine which signals to pass to
   * use.
   */
  NSMutableDictionary *rules;
  /**
   * Set of all observation activities for the observable;
   */
  NSHashTable *observations;

  /**
   * Specifies whether the observable is watching for changes in the owner of a
   * name. This is required to prevent an infinite loop, because observables
   * might be created when removing an observation activity.
   */
  BOOL isWatchingNameChanges;
  /**
   * The bus-type that should be used when making queries to the D-Bus object.
   */
   DKDBusBusType type;
}
- (void)addObservation: (DKObservation*)observation;
@end

/**
 * DKObservation modells the fact that an <ivar>observer</ivar> is watching for
 * a specific <ivar>observable</ivar> and wants to be notified by calling the
 * <ivar>selector</ivar> specified.
 */
@interface DKObservation: NSObject
{
  /**
   * The object that wants to watch the signal.
   * Note: In a GC environment, this ivar will not point to the object itself,
   * which hides it from the garbage collector.
   */
  id observer;

  /**
   * The selector specifying the selector to call back to.
   */
  SEL selector;
}

/**
 * Creates an observation for the given observable.
 */
- (id)initWithObserver: (id)observer
              selector: (SEL)selector;

/**
 * Schedules the delivery of the notification on the current run loop.
 */
- (void)notifyWithNotification: (NSNotification*)notification;

/**
 * Returns the observer which will be notified by this notification.
 */
- (id)observer;
@end

@implementation DKObservable

- (id)initWithBusType: (DKDBusBusType)aType;
{
  NSPointerFunctionsOptions weakObjectOptions = (NSPointerFunctionsObjectPersonality | NSPointerFunctionsZeroingWeakMemory);
  if (nil == (self = [super init]))
  {
    return nil;
  }
  // We always observe signals:
  type = aType;
  rules = [[NSMutableDictionary alloc] initWithObjectsAndKeys: @"signal", @"type", nil];
  observations = [[NSHashTable alloc] initWithOptions: weakObjectOptions
                                             capacity: 5];
  return self;
}

/**
 * Adds a DKObservation (i.e. observer/selector-pair.) to the observable.
 * Whenever a signal matching the observable is received, the corresponding
 * notification will be delivered to the observation.
 */
- (void)addObservation: (DKObservation*)observation
{
  DKObservation *oldObservation = nil;
  if (nil == observation)
  {
    return;
  }
  oldObservation = [observations member: observation];
  if (nil == oldObservation)
  {
    [observations addObject: observation];
  }
}

/**
 * Removes the observation from the table.
 */
- (void)removeObservation: (DKObservation*)observation
{
  DKObservation *oldObservation = [observations member: observation];
  if (nil != oldObservation)
  {
    [observations removeObject: oldObservation];
  }
}

/**
 * Removes all observations for the given observer.
 */
- (void)removeObservationsForObserver: (id)observer
{
  NSHashEnumerator theEnum = NSEnumerateHashTable(observations);
  // Construct a table to hold the observables to remove because we can't modify
  // the table while enumerating.
  NSHashTable *removeTable = [NSHashTable hashTableWithWeakObjects];
  DKObservation *thisObservation = nil;
  while (nil != (thisObservation = NSNextHashEnumeratorItem(&theEnum)))
  {
    if (observer == [thisObservation observer])
    {
      NSHashInsert(removeTable,thisObservation);
    }
  }
  NSEndHashTableEnumeration(&theEnum);
  [observations minusHashTable: removeTable];
}

/**
 * Deliver <var>notification</var> to all registered observers.
 */
- (void)notifyWithNotification: (NSNotification*)notification
{
  NSHashEnumerator obsEnum = NSEnumerateHashTable(observations);
  DKObservation *thisObservation = nil;
  while (nil != (thisObservation = NSNextHashEnumeratorItem(&obsEnum)))
  {
    [thisObservation notifyWithNotification: notification];
  }
  NSEndHashTableEnumeration(&obsEnum);
}

/**
 * Sets a key in the rule dictionary.
 */
- (void)setRule: (NSString*)value
         forKey: (NSString*)key
{
  if (nil == key)
  {
    return;
  }
  if (nil != value)
  {
    [rules setObject: value
              forKey: key];
  }
  else
  {
    [rules removeObjectForKey: key];
  }
}

/**
 * Retrieves a specific rule.
 */
- (id)ruleForKey: (NSString*)key
{
  return [rules objectForKey: key];
}

/**
 * Adds a filter rule for a D-Bus interface (e.g.
 * <code>org.freedesktop.DBus</code>.
 */
- (void)filterInterface: (NSString*)interface
{
  [self setRule: interface
         forKey: @"interface"];
}

/**
 * Adds a filter rule of a D-Bus signal name (e.g.
 * <code>NameOwnerChanged</code>.
 */
- (void)filterSignalName: (NSString*)signalName
{
  [self setRule: signalName
         forKey: @"member"];
}

/**
 * Adds a filter rule matching <var>signal</var>.
 */
- (void)filterSignal: (DKSignal*)signal
{
  [self filterSignalName: [signal name]];
  [self filterInterface: [[signal parent] name]];
}

/**
 * Adds a filter rule for the string argument at <var>index</var>. The
 * observable will only match if <var>match</var> is equal to the value of the
 * argument.
 */
-  (void)filterValue: (NSString*)match
  forArgumentAtIndex: (NSUInteger)index
{
  if (index < 64)
  {
    if ((nil == match) || [match isEqual: [NSNull null]])
    {
      match = @"";
    }
    [self setRule: match
           forKey: [NSString stringWithFormat: @"arg%lu", index]];
  }
}


/**
 * Called by the notification center when the unique name of the sender changes.
 */
- (void)nameChanged: (NSNotification*)notification
{
  NSString *newName = [[notification userInfo] objectForKey: @"arg2"];

  if (0 != [newName length])
  {
    [self setRule: newName
           forKey: @"sender"];
  }
}

/**
 * Adds a filter rule matching on the <var>proxy</var> object emitting the
 * signal.
 */
- (void)filterSender: (DKProxy*)proxy
{
  if (nil == proxy)
  {
    return;
  }
  // We need to put the unique name here to avoid reentrancy when handling
  // signals.
  [self setRule: [proxy _uniqueName]
         forKey: @"sender"];
  [self setRule: [proxy _path]
         forKey: @"path"];

  // To keep the name up to date we watch for NameOwnerChanged with the name
  // specified. (But don't do this for the bus object).
  if ([@"org.freedesktop.DBus" isEqualToString: [proxy _service]])
  {
    return;
  }
  [[DKNotificationCenter centerForBusType: type] addObserver: self
                                                    selector: @selector(nameChanged:)
                                                      signal: @"NameOwnerChanged"
                                                   interface: @"org.freedesktop.DBus"
                                                      sender: [DKDBus busWithBusType: type]
                                                 destination: nil
                                                      filter: [proxy _service]
                                                     atIndex: 0];
  isWatchingNameChanges = YES;
}

/**
 * Adds a filter rule for the destination <var>proxy</var> the signal is
 * intended for.
 */
- (void)filterDestination: (DKProxy*)proxy
{
  NSString *uniqueName = [proxy _uniqueName];
  [self setRule: uniqueName
         forKey: @"destination"];
}

/**
 * Generates a string suitable for use as a match rule in dbus_bus_add_match().
 */
- (NSString*)ruleString
{
  NSEnumerator *keyEnum = [rules keyEnumerator];
  NSString *key = nil;
  NSMutableString *string = [NSMutableString string];
  NSUInteger count = 0;
  while (nil != (key = [keyEnum nextObject]))
  {
    NSString *value = [[rules objectForKey: key] stringByReplacingOccurrencesOfString: @"'"
                                                                           withString: @"\\'"];
    if (count != 0)
    {
      [string appendString: @","];
    }
    [string appendFormat: @"%@='%@'", key, value];
    count++;
  }
  return string;
}

/**
 * The observable is hashed by its <ivar>rules</ivar> dictionary.
 */
- (NSUInteger)hash
{
  return [rules hash];
}

/**
 * Return the rules dictionary for the observable.
 */
- (NSDictionary*)rules
{
  return [[rules copy] autorelease];
}

/**
 * Two observables are considered equal if they have the same set of
 * <ivar>rules</ivar>.
 */
- (BOOL)isEqual: (DKObservable*)other
{
  return [rules isEqualToDictionary: [other rules]];
}

/**
 * Returns a reference to the hash table of all observations in progress for
 * this observable.
 */
- (NSHashTable*)observations
{
  return observations;
}

- (NSUInteger)observationCount
{
  return NSCountHashTable(observations);
}
/**
 * Determine whether a given notification's userInfo dictionary will be matched
 * by the receiver.
 */
- (BOOL)matchesUserInfo: (NSDictionary*)dict
{
  NSEnumerator *keyEnum = [rules keyEnumerator];
  NSString *thisKey = nil;
  while (nil != (thisKey = [keyEnum nextObject]))
  {
    NSString *thisRule = [rules objectForKey: thisKey];
    if ([@"type" isEqualToString: thisKey])
    {
      // We ignore the type, it's alway 'signal'.
      continue;
    }

    if (nil != thisRule)
    {
      id thisValue = [dict objectForKey: thisKey];

      // For proxies we want to match the object paths:
      if ([thisValue conformsToProtocol: @protocol(DKObjectPathNode)])
      {
	thisValue = [(DKProxy*)thisValue _path];
      }

      // We only match string values.
      if (NO == [thisValue isKindOfClass: [NSString class]])
      {
	return NO;
      }

      // Complete matches only
      if (NO == [thisRule isEqualToString: (NSString*)thisValue])
      {
	return NO;
      }
    }
  }
  return YES;
}

- (void)dealloc
{
  if (isWatchingNameChanges)
  {
    [[DKNotificationCenter centerForBusType: type] removeObserver: self];
  }
  [rules release];
  [observations release];
  [super dealloc];
}
@end

@implementation DKObservation

- (id)initWithObserver: (id)anObserver
              selector: (SEL)aSelector
{
  if (nil == (self = [super init]))
  {
    return nil;
  }
  observer = GS_GC_HIDE(anObserver);
  selector = aSelector;

  // Make sure the necessary components are there and that the selector takes a
  // sane number of arguments.
  if (((anObserver == nil) || (selector == 0))
    || (3 != [[anObserver methodSignatureForSelector: selector] numberOfArguments]))
  {
    [self release];
    return nil;
  }
  return self;
}

- (id)observer
{
  return GS_GC_UNHIDE(observer);
}

- (SEL)selector
{
  return selector;
}

- (NSUInteger)hash
{
  return ((NSUInteger)(uintptr_t)observer ^ (uintptr_t)selector);
}

- (BOOL)isEqual: (DKObservation*)other
{
  BOOL sameObserver = (observer == [other observer]);
  BOOL sameSelector = sel_isEqual(selector, [other selector]);
  return (sameObserver && sameSelector);
}

- (void)notifyWithNotification: (NSNotification*)notification
{
  // We are still in the code path coming from libdbus' message handling
  // callback and need to avoid the reentrancy. We do this by scheduling
  // delivery of the notification on the run loop.
  [[NSRunLoop currentRunLoop] performSelector: selector
                                      target: GS_GC_UNHIDE(observer)
				    argument: notification
				       order: UINT_MAX
				       modes: [NSArray arrayWithObject: NSDefaultRunLoopMode]];
}

- (void)dealloc
{
  [super dealloc];
}
@end


static DKNotificationCenter *systemCenter;
static DKNotificationCenter *sessionCenter;

/**
 * The result handling function called by libdbus. It is important to keep in
 * mind that we cannot do any D-Bus related stuff in the code path originating
 * from this function, because libdbus doesn't handle reentrancy very
 * gracefully.
 */
static DBusHandlerResult
DKHandleSignal(DBusConnection *connection, DBusMessage *msg, void *userData);

@interface DKNotificationCenter (DKNotificationCenterPrivate)
- (id)initWithBusType: (DKDBusBusType)type;

- (DKSignal*)_signalForNotificationName: (NSString*)name;

- (void)_letObserver: (id)observer
   observeObservable: (DKObservable*)observable
        withSelector: (SEL)selector;

- (void)_removeObserver: (id)observer
          forObservable: (DKObservable*)observable;

- (DKObservable*)_observableForSignalName: (NSString*)signalName
                                interface: (NSString*)interfaceName
                                   sender: (DKProxy*)sender
                              destination: (DKProxy*)destination
                                   filter: (NSString*)filter
	                          atIndex: (NSUInteger)index;

- (void)_installHandler;

- (void)_removeHandler;
@end

@implementation DKNotificationCenter
+ (void)initialize
{
  if ([DKNotificationCenter class] == self)
  {
    systemCenter = [[DKNotificationCenter alloc] initWithBusType: DKDBusSystemBus];
    sessionCenter = [[DKNotificationCenter alloc] initWithBusType: DKDBusSessionBus];
  }
}

+ (id)allocWithZone: (NSZone*)zone
{
  if ((nil == systemCenter) || (nil == sessionCenter))
  {
    return [super allocWithZone: zone];
  }
  return nil;
}

+ (id)sessionBusCenter
{
  return [self centerForBusType: DKDBusSessionBus];
}

+ (id)systemBusCenter
{
  return [self centerForBusType: DKDBusSystemBus];
}

+ (id)centerForBusType: (DKDBusBusType)type
{
  DKNotificationCenter *center = nil;
  switch (type)
  {
    case DKDBusSystemBus:
      if (systemCenter == nil)
      {
	systemCenter = [[DKNotificationCenter alloc] initWithBusType: type];
      }
      center = systemCenter;
      break;
    case DKDBusSessionBus:
      if (sessionCenter == nil)
      {
	sessionCenter = [[DKNotificationCenter alloc] initWithBusType: type];
      }
      center = sessionCenter;
      break;
    default:
      break;
  }
  return center;
}

- (id)initWithBusType: (DKDBusBusType)type
{
  if (nil == (self = [super init]))
  {
    return nil;
  }
  endpoint = [[DKEndpoint alloc] initWithWellKnownBus: (DBusBusType)type];

  if (nil == endpoint)
  {
    [self release];
    return nil;
  }

  lock = [[NSRecursiveLock alloc] init];
  signalInfo = [[NSMutableDictionary alloc] init];
  notificationNames = [[NSMutableDictionary alloc] init];
  notificationNamesBySignal = [[NSMapTable alloc]initWithKeyOptions: NSPointerFunctionsObjectPersonality
                                                       valueOptions: NSPointerFunctionsObjectPersonality
                                                           capacity: 5];
  observables = NSCreateHashTable(NSObjectHashCallBacks, 5);

  return self;
}

// -addObserver:... methods on different granularities
- (void)addObserver: (id)observer
           selector: (SEL)notifySelector
               name: (NSString*)notificationName
	     sender: (DKProxy*)sender
	destination: (DKProxy*)destination
{
  DKSignal *signal = [self _signalForNotificationName: notificationName];
  if ((nil != notificationName) && (nil == signal))
  {
    //TODO: fail silently or raise an exception?
    NSWarnMLog(@"Cannot observe notification %@ (no corresponding D-Bus signal).",
      notificationName);
    return;
  }

  [self addObserver: observer
           selector: notifySelector
             signal: [signal name]
          interface: [[signal parent] name]
             sender: sender
        destination: destination
  filtersAndIndices: nil, 0, nil];
}

- (void)addObserver: (id)observer
           selector: (SEL)notifySelector
               name: (NSString*)notificationName
	     object: (DKProxy*)sender
{
  DKSignal *signal = [self _signalForNotificationName: notificationName];
  if ((nil != notificationName) && (nil == signal))
  {
    //TODO: fail silently or raise an exception?
    NSWarnMLog(@"Cannot observe notification %@ (no corresponding D-Bus signal).",
      notificationName);
    return;
  }

  [self addObserver: observer
           selector: notifySelector
             signal: [signal name]
          interface: [[signal parent] name]
             sender: sender
        destination: nil
  filtersAndIndices: nil, 0, nil];
}

-  (void)addObserver: (id)observer
            selector: (SEL)notifySelector
              signal: (NSString*)signalName
           interface: (NSString*)interfaceName
              sender: (DKProxy*)sender
         destination: (DKProxy*)destination
{
  [self addObserver: observer
           selector: notifySelector
             signal: signalName
          interface: interfaceName
             sender: sender
        destination: destination
  filtersAndIndices: nil, 0, nil];
}

-  (void)addObserver: (id)observer
            selector: (SEL)notifySelector
              signal: (NSString*)signalName
           interface: (NSString*)interfaceName
              sender: (DKProxy*)sender
         destination: (DKProxy*)destination
              filter: (NSString*)filter
	     atIndex: (NSUInteger)index
{
  [self addObserver: observer
           selector: notifySelector
             signal: signalName
          interface: interfaceName
             sender: sender
        destination: destination
  filtersAndIndices: filter, index, nil];
}

-  (void)addObserver: (id)observer
            selector: (SEL)notifySelector
              signal: (NSString*)signalName
           interface: (NSString*)interfaceName
              sender: (DKProxy*)sender
         destination: (DKProxy*)destination
   filtersAndIndices: (NSString*)firstFilter, NSUInteger nullIndex, ...
{
  va_list filters;
  uintptr_t filterOrIndex = 0;
  NSUInteger count = 1;
  NSString *thisFilter = nil;

  DKObservable *observable = [self _observableForSignalName: signalName
                                                  interface: interfaceName
                                                     sender: sender
                                                destination: destination
						     filter: firstFilter
                                                    atIndex: nullIndex];
  va_start(filters, nullIndex);
  while (0 != (filterOrIndex = va_arg(filters, uintptr_t)))
  {
    if (0 == count)
    {
      thisFilter = (NSString*)filterOrIndex;
      count++;
    }
    else if (1 == count)
    {
      [observable filterValue: thisFilter
           forArgumentAtIndex: (NSUInteger)filterOrIndex];
      count = 0;
    }
  }
  va_end(filters);

  [self _letObserver: observer
   observeObservable: observable
        withSelector: notifySelector];
}

// Observation removal methods on different levels of granularity:

- (void)removeObserver: (id)observer
{
  // Specify a match-all observable to catch all instances of the observer.
  [self _removeObserver: observer
          forObservable: [[[DKObservable alloc] init] autorelease]];
}

- (void)removeObserver: (id)observer
                  name: (NSString*)notificationName
                sender: (DKProxy*)sender
           destination: (DKProxy*)destination
{
  DKSignal *signal = [self _signalForNotificationName: notificationName];
  if ((nil != notificationName) && (nil == signal))
  {
    //TODO: fail silently or raise an exception?
    NSWarnMLog(@"Cannot remove notification %@ (no corresponding D-Bus signal).",
      notificationName);
    return;
  }
  [self removeObserver: observer
                signal: [signal name]
             interface: [[signal parent] name]
                sender: sender
           destination: destination
     filtersAndIndices: nil, 0, nil];
}

- (void)removeObserver: (id)observer
                  name: (NSString*)notificationName
                object: (DKProxy*)sender
{
  DKSignal *signal = [self _signalForNotificationName: notificationName];
  if ((nil != notificationName) && (nil == signal))
  {
    //TODO: fail silently or raise an exception?
    NSWarnMLog(@"Cannot remove notification %@ (no corresponding D-Bus signal).",
      notificationName);
    return;
  }
  [self removeObserver: observer
                signal: [signal name]
             interface: [[signal parent] name]
                sender: sender
           destination: nil
     filtersAndIndices: nil, 0, nil];
}

- (void)removeObserver: (id)observer
                signal: (NSString*)signalName
             interface: (NSString*)interfaceName
                sender: (DKProxy*)sender
           destination: (DKProxy*)destination
{
  [self removeObserver: observer
                signal: signalName
             interface: interfaceName
                sender: sender
           destination: destination
     filtersAndIndices: nil, 0, nil];
}

- (void)removeObserver: (id)observer
                signal: (NSString*)signalName
             interface: (NSString*)interfaceName
                sender: (DKProxy*)sender
           destination: (DKProxy*)destination
	        filter: (NSString*)filter
    	       atIndex: (NSUInteger)index
{
  [self removeObserver: observer
                signal: signalName
             interface: interfaceName
                sender: sender
           destination: destination
     filtersAndIndices: filter, index, nil];
}

- (void)removeObserver: (id)observer
                signal: (NSString*)signalName
             interface: (NSString*)interfaceName
                object: (DKProxy*)sender
{
  [self removeObserver: observer
                signal: signalName
             interface: interfaceName
                sender: sender
           destination: nil
     filtersAndIndices: nil, 0, nil];
}

-  (void)removeObserver: (id)observer
                 signal: (NSString*)signalName
              interface: (NSString*)interfaceName
                 sender: (DKProxy*)sender
            destination: (DKProxy*)destination
      filtersAndIndices: (NSString*)firstFilter, NSUInteger nullIndex, ...
{
  va_list filters;
  uintptr_t filterOrIndex = 0;
  NSUInteger count = 1;
  NSString *thisFilter = nil;

  DKObservable *observable = [self _observableForSignalName: signalName
                                                  interface: interfaceName
                                                     sender: sender
                                                destination: destination
						     filter: firstFilter
                                                    atIndex: nullIndex];
  va_start(filters, nullIndex);
  while (0 != (filterOrIndex = va_arg(filters, uintptr_t)))
  {
    if (0 == count)
    {
      thisFilter = (NSString*)filterOrIndex;
      count++;
    }
    else if (1 == count)
    {
      [observable filterValue: thisFilter
           forArgumentAtIndex: (NSUInteger)filterOrIndex];
      count = 0;
    }
  }
  va_end(filters);

  [self _removeObserver: observer
          forObservable: observable];
}

// Observation management methods doing the actual work:

/**
 * Create an observable matching the information specified.
 */
- (DKObservable*)_observableForSignalName: (NSString*)signalName
                                interface: (NSString*)interfaceName
                                   sender: (DKProxy*)sender
                              destination: (DKProxy*)destination
                                   filter: (NSString*)filter
	                          atIndex: (NSUInteger)index
{
  DKObservable *observable = [[[DKObservable alloc] initWithBusType: [endpoint DBusBusType]] autorelease];
  [observable filterSignalName: signalName];
  [observable filterInterface: interfaceName];
  [observable filterSender: sender];
  [observable filterDestination: destination];
  if (filter != nil)
  {
    [observable filterValue: filter
         forArgumentAtIndex: index];
  }
  return observable;
}

/**
 * Return an array of all observables that will match for <var>userInfo</var>.
 */
- (NSArray*)_observablesMatchingUserInfo: (NSDictionary*)userInfo
{
  NSHashEnumerator obsEnum;
  DKObservable *thisObservable = nil;
  NSMutableArray *array = nil;
  [lock lock];
  NS_DURING
  {
    obsEnum = NSEnumerateHashTable(observables);
    while (nil != (thisObservable = NSNextHashEnumeratorItem(&obsEnum)))
    {
      if ([thisObservable matchesUserInfo: userInfo])
      {
	if (nil == array)
	{
	  array = [NSMutableArray array];
	}
	[array addObject: thisObservable];
      }
    }
  }
  NS_HANDLER
  {
    NSEndHashTableEnumeration(&obsEnum);
    [lock unlock];
    [localException raise];
  }
  NS_ENDHANDLER

  NSEndHashTableEnumeration(&obsEnum);
  [lock unlock];
  return array;
}

/**
 * Installs the necessary entries for observables and observations in the
 * respective tables and adds the D-Bus match rule if necessary.
 */
- (void)_letObserver: (id)observer
   observeObservable: (DKObservable*)observable
        withSelector: (SEL)selector
{
  DKObservation *observation = [[DKObservation alloc] initWithObserver: observer
                                                              selector: selector];
  DKObservable *oldObservable = nil;
  BOOL firstObservation = NO;
  DBusError err;
  dbus_error_init(&err);
  [lock lock];
  NS_DURING
  {
    firstObservation = (0 == NSCountHashTable(observables));
    if (firstObservation)
    {
      [self _installHandler];
    }

    oldObservable = NSHashInsertIfAbsent(observables, (const void*)observable);

    if (nil != oldObservable)
    {
      // Use the prexisting observable if possible:
      observable = oldObservable;
    }
    else
    {
      dbus_bus_add_match([endpoint DBusConnection],
        [[observable ruleString] UTF8String],
        &err);

      if (dbus_error_is_set(&err))
      {
        NSHashRemove(observables, observable);
	[NSException raise: @"DKSignalMatchException"
                    format: @"Error when trying to add match for signal: %s. (%s)",
         err.name, err.message];
      }
    }
      [observable addObservation: observation];
  }
  NS_HANDLER
  {
    if (firstObservation)
    {
      [self _removeHandler];
    }
    [lock unlock];
    [observation release];
    [localException raise];
  }
  NS_ENDHANDLER

  // The observation has been retained by the observable, we can release our
  // reference to it.
  [observation release];

  [lock unlock];
}

/**
 * Removes the observer/observable combination from all tables it appears in.
 * Also removes match rules and handlers if necessary.
 */
- (void)_removeObserver: (id)observer
          forObservable: (DKObservable*)observable
{
  NSHashEnumerator observableEnum;
  NSHashEnumerator cleanupEnum;
  NSHashTable *cleanupTable = [NSHashTable hashTableWithWeakObjects];
  NSUInteger initialCount = 0;
  if (nil == observable)
  {
    return;
  }
  [lock lock];
  initialCount = NSCountHashTable(observables);
  /*
   * First stage of cleanup: Remove references to the observation from the
   * observables that will be matched by the one specified.
   */
  NS_DURING
  {
    DKObservable *thisObservable = nil;
    SEL matchSel = @selector(matchesUserInfo:);
    IMP matchesUserInfo = [observable methodForSelector: matchSel];
    SEL ruleSel = @selector(rules);
    IMP getRules = [observable methodForSelector: ruleSel];
    observableEnum = NSEnumerateHashTable(observables);

    while (nil != (thisObservable = NSNextHashEnumeratorItem(&observableEnum)))
    {
      NSDictionary *rules = getRules(thisObservable, ruleSel);
      if ((BOOL)(uintptr_t)matchesUserInfo(observable, matchSel, rules))
      {
        [thisObservable removeObservationsForObserver: observer];
	// If we removed the last observation, add the observable to the cleanup
	// table because we cannot modify the table we are enumerating.
	if (0 == [thisObservable observationCount])
	{
	  NSHashInsertIfAbsent(cleanupTable, thisObservable);
	}
      }
    }
  }
  NS_HANDLER
  {
    NSEndHashTableEnumeration(&observableEnum);
    [lock unlock];
    [localException raise];
  }
  NS_ENDHANDLER
  NSEndHashTableEnumeration(&observableEnum);

  /*
   * Second stage of cleanup: If we left an empty observable, remove it and the
   * corresponding match rule.
   */
  NS_DURING
  {
    DKObservable *thisObservable = nil;
    cleanupEnum = NSEnumerateHashTable(cleanupTable);
    while(nil != (thisObservable = NSNextHashEnumeratorItem(&cleanupEnum)))
    {
      DBusError err;
      dbus_error_init(&err);
      NSHashRemove(observables, thisObservable);
      // remove the match rule from D-Bus.
      dbus_bus_remove_match([endpoint DBusConnection],
        [[thisObservable ruleString] UTF8String],
        &err);

      if (dbus_error_is_set(&err))
      {
        [NSException raise: @"DKSignalMatchException"
                    format: @"Error when trying to remove match for signal: %s. (%s)",
          err.name, err.message];
      }
    }
  }
  NS_HANDLER
  {
    NSEndHashTableEnumeration(&cleanupEnum);
    [lock unlock];
    [localException raise];
  }
  NS_ENDHANDLER
  NSEndHashTableEnumeration(&cleanupEnum);
  /*
   * Third stage of cleanup: If we have no observables left, also remove the
   * D-Bus message handler until we have further signals to watch.
   */
  if (0 == NSCountHashTable(observables) && (0 != initialCount))
  {
    [self _removeHandler];
  }
  [lock unlock];
}


// Notification posting methods:
- (void)postNotification: (NSNotification*)notification
{

}
- (void)postNotificationName: (NSString*)name
                      object: (id)sender
{
}

- (void)postSignalName: (NSString*)signalName
             interface: (NSString*)interfaceName
                object: (id)sender
{
}

- (void)postNotificationName: (NSString*)name
                      object: (id)sender
                    userInfo: (NSDictionary*)info
{
}

- (void)postSignalName: (NSString*)signalName
             interface: (NSString*)interfaceName
                object: (id)sender
              userInfo: (NSDictionary*)info
{

}


/**
 * Tries to find a preexisting signal specification and creates a stub signal if
 * none exists.
 */
- (DKSignal*)_signalWithName: (NSString*)name
                 inInterface: (NSString*)interfaceName
{
  DKInterface *theInterface = nil;
  DKSignal *signal = nil;
  [lock lock];
  theInterface = [signalInfo objectForKey: interfaceName];

  // Add the interface if necessary:
  if (theInterface == nil)
  {
    DKInterface *stubIf = [[DKInterface alloc] initWithName: interfaceName
                                                     parent: nil];
    [signalInfo setObject: stubIf
                   forKey: interfaceName];
    theInterface = stubIf;
    [stubIf release];
  }

  if (nil != (signal = [[theInterface signals] objectForKey: name]))
  {
    [lock unlock];
    //Don't generate new stubs for signals we already have.
    return signal;
  }
  signal = [[[DKSignal alloc] initWithName: name
                                    parent: theInterface] autorelease];
  [signal setAnnotationValue: @"YES"
                      forKey: @"org.gnustep.dbuskit.signal.stub"];

  [theInterface addSignal: signal];
  [lock unlock];
  return signal;
}

/**
 * Retrieves the signal for the notification. If the signal did not yet exist,
 * it might be created as a stub signal.
 */
- (DKSignal*)_signalForNotificationName: (NSString*)name
{
  DKSignal *signal = nil;
  [lock lock];
  signal = [notificationNames objectForKey: name];
  if (nil != signal)
  {
    return signal;
  }
  else if (([name hasPrefix: @"DKSignal_"]) && ([name length] >= 9))
  {
    NSString *stripped = [name substringFromIndex: 9];
    NSUInteger len = [stripped length];
    NSRange sepRange = [stripped rangeOfString: @"_"];
    NSString *ifName = nil;
    NSString *signalName = nil;
    // Don't continue if the separator was not found or appeared at the begining
    // or end of the string:
    if ((NSNotFound == sepRange.location)
      || (len == (sepRange.location + 1))
      || (0 == sepRange.location))
    {
      [lock unlock];
      return nil;
    }
    ifName = [stripped substringToIndex: (sepRange.location - 1)];
    signalName = [stripped substringFromIndex: (sepRange.location + 1)];
    [lock unlock];
    return [self _signalWithName: signalName
                     inInterface: ifName];
  }
  [lock unlock];
  return nil;
}

/**
 * Retrieves the notification name for the signal. This is either the name
 * specified in an annotation or the default name.
 */
- (NSString*)_notificationNameForSignal: (DKSignal*)signal
{
  NSString *name = nil;
  [lock lock];
  name = NSMapGet(notificationNamesBySignal, signal);
  if (nil != name)
  {
    [lock unlock];
    return name;
  }
  [lock unlock];
  return [NSString stringWithFormat: @"DKSignal_%@_%@",
    [[signal parent] name], [signal name]];
}

/**
 * Registers the <var>signal</var> under the <var>notificationName</var>.
 */
- (BOOL)_registerNotificationName: (NSString*)notificationName
                         asSignal: (DKSignal*)signal
{
  if ((nil == notificationName) || (nil == signal));
  {
    return NO;
  }
  [lock lock];
  NS_DURING
  {
    if (nil == [notificationNames objectForKey: notificationName])
    {
      [notificationNames setObject: signal
                            forKey: notificationName];

      NSDebugMLog(@"Registered signal '%@' (from interface '%@') with notification name '%@'.",
        [signal name],
        [[signal parent] name],
        notificationName);
      NS_DURING
      {
        NSMapInsertIfAbsent(notificationNamesBySignal, signal, notificationName);
      }
      NS_HANDLER
      {
	//Roll-back:
	[notificationNames removeObjectForKey: notificationName];
	[localException raise];
      }
      NS_ENDHANDLER
      [lock unlock];
      return YES;
    }
    else
    {
      NSDebugMLog(@"Cannot register signal '%@' (from interface '%@') with notification name '%@' (already registered).",
        [signal name],
        [[signal parent] name],
        notificationName);
    }
  }
  NS_HANDLER
  {
    [lock unlock];
    [localException raise];
  }
  NS_ENDHANDLER
  [lock unlock];
  return NO;
}

- (BOOL)registerNotificationName: (NSString*)notificationName
                        asSignal: (NSString*)signalName
                     inInterface: (NSString*)interface
{
  DKSignal *signal = nil;
  BOOL success = NO;
  if (notificationName == nil)
  {
    return NO;
  }
  [lock lock];
  signal = [[[signalInfo objectForKey: interface] signals] objectForKey: signalName];
  if (nil == signal)
  {
    signal = [self _signalWithName: signalName
                       inInterface: interface];
  }
  if (nil == signal)
  {
    return NO;
  }
  success = [self _registerNotificationName: notificationName
                                   asSignal: signal];
  [lock unlock];
  return success;
}

/**
 * Register a signal with its default name.
 */
- (void)_registerSignal: (DKSignal*)aSignal
{
  NSString *interfaceName = [[aSignal parent] name];
  NSString *signalName = [aSignal name];
  NSString *notificationName = [aSignal notificationName];
  DKInterface *theInterface = nil;
  DKSignal *theSignal = nil;
  [lock lock];
  theInterface = [signalInfo objectForKey: interfaceName];

  // Add the interface if necessary:
  if (theInterface == nil)
  {
    DKInterface *stubIf = [[DKInterface alloc] initWithName: interfaceName
                                                     parent: nil];
    [signalInfo setObject: stubIf
                   forKey: interfaceName];
    theInterface = stubIf;
    [stubIf release];
  }

  // Get the signal:
  theSignal = [[theInterface signals] objectForKey: signalName];

  // Check whether the notification center itself did add a stub for this signal.
  if ([theSignal isStub])
  {
    [theInterface removeSignalNamed: signalName];
    theSignal = nil;
  }

  // Add the signal if necessary
  if (nil == theSignal)
  {
    theSignal = [aSignal copy];
    [theInterface addSignal: theSignal];
    [theSignal setParent: theInterface];
    if (nil != notificationName)
    {
      [self _registerNotificationName: notificationName
                             asSignal: theSignal];
    }
    NSDebugMLog(@"Registered signal '%@' (interface: '%@') in notification center.",
      [theSignal name],
      [theInterface name]);
    [theSignal release];
  }

  [lock unlock];
}

/**
 * Installs a handler on the D-Bus connection to catch signals once there are
 * active observation activities.
 */
- (void)_installHandler
{
  NSDebugMLog(@"Started monitoring for D-Bus signals.");
  dbus_connection_add_filter([endpoint DBusConnection],
    DKHandleSignal,
    (void*)self,
    NULL); // the notification center is static, we'd never actually free it
}

/**
 * Removes the handler from the D-Bus connection once all observation activities
 * have ceased.
 */
- (void)_removeHandler
{
  NSDebugMLog(@"Stopped monitoring for D-Bus signals.");
  dbus_connection_remove_filter([endpoint DBusConnection],
    DKHandleSignal,
    (void*)self);
}

/**
 * Handles a message caught by the handler. If the signal is not yet known to
 * the center, this will generate arguments from the D-Bus signature. This
 * method also deserializes the message into an userInfo dictionary for use in
 * the notification. This is necessary to determine whether the message matches
 * one or more of the registered observables. If so, a notification will be
 * generated and dispatched to all observers.
 */
- (BOOL)_handleMessage: (DBusMessage*)msg
{
  const char *cSignal = dbus_message_get_member(msg);
  NSString *signal = nil;
  const char *cInterface = dbus_message_get_interface(msg);
  NSString *interface = nil;
  const char *cSender = dbus_message_get_sender(msg);
  NSString *sender = nil;
  const char *cPath = dbus_message_get_path(msg);
  NSString *path = nil;
  const char *cDestination = dbus_message_get_destination(msg);
  NSString *destination = nil;
  const char *signature = dbus_message_get_signature(msg);

  if (NULL != cSignal)
  {
    signal = [NSString stringWithUTF8String: cSignal];
  }
  if (NULL != cInterface)
  {
    interface = [NSString stringWithUTF8String: cInterface];
  }
  if (NULL != cSender)
  {
    sender = [NSString stringWithUTF8String: cSender];
  }
  if (NULL != cPath)
  {
    path = [NSString stringWithUTF8String: cPath];
  }
  if (NULL != cDestination)
  {
    destination = [NSString stringWithUTF8String: cDestination];
  }

  [lock lock];
  NS_DURING
  {
    DBusMessageIter iter;
    NSMutableDictionary *userInfo = nil;
    NSArray *matchingObservables = nil;
    NSNotification *notification = nil;

    /*
     * Copying the signal allows us to set the sender as its parent (circumventing
     * the interface at this time. This is needed because the arguments might need
     * to construct object paths and such. We also need to reference the
     * original signal because we need it to look up the notification name.
     */
    DKSignal *origSignal = [self _signalWithName: signal
                                     inInterface: interface];
    DKSignal *theSignal = [[origSignal copy] autorelease];

    /* Construct a proxy for the object emitting the signal: */
    DKProxy *senderProxy = [DKProxy proxyWithEndpoint: endpoint
                                           andService: sender
                                              andPath: path];
    [theSignal setParent: senderProxy];

    userInfo = [[NSMutableDictionary alloc] initWithObjectsAndKeys: signal, @"member",
      interface, @"interface",
      sender, @"sender",
      path, @"path",
      destination, @"destination",
      nil];

    if (([theSignal isStub]) && (NULL != signature))
    {
      if ('\0' != signature[0])
      {
        DBusSignatureIter iter;
        NSMutableArray *args = [NSMutableArray array];
        dbus_signature_iter_init(&iter, signature);
        do
        {
          char *sig = dbus_signature_iter_get_signature(&iter);
  	  DKArgument *arg = [[DKArgument alloc] initWithDBusSignature: sig
	                                                         name: nil
	                                                       parent: theSignal];
	  [args addObject: arg];
        } while (dbus_signature_iter_next(&iter));
        [theSignal setArguments: args];
      }
    }

    dbus_message_iter_init(msg, &iter);
    [userInfo addEntriesFromDictionary: [theSignal userInfoFromIterator: &iter]];

    matchingObservables = [self _observablesMatchingUserInfo: userInfo];
    if (nil == matchingObservables)
    {
      NSDebugMLog(@"Signal %@ is not being observed by the notification center.", signal);
      [lock unlock];
      return NO;
    }
    notification = [NSNotification notificationWithName: [self _notificationNameForSignal: origSignal]
                                                 object: senderProxy
					       userInfo: userInfo];
    [matchingObservables makeObjectsPerformSelector: @selector(notifyWithNotification:)
                                         withObject: notification];
  }
  NS_HANDLER
  {
    [lock unlock];
    [localException raise];
  }
  NS_ENDHANDLER
  [lock unlock];
  return YES;
}

- (void)dealloc
{
  [endpoint release];
  [signalInfo release];
  [notificationNames release];
  NSFreeMapTable(notificationNamesBySignal);
  NSFreeHashTable(observables);
  [lock release];
  [super dealloc];
}

// Singelton pattern:

- (NSUInteger)retainCount
{
  return UINT_MAX;
}

- (id)retain
{
  return self;
}

- (id)autorelease
{
  return self;
}

- (void)release
{
  // No-Op.
}
@end

static DBusHandlerResult
DKHandleSignal (DBusConnection *connection, DBusMessage *msg, void *center)
{
  BOOL centerDidHandle = NO;
  if (DBUS_MESSAGE_TYPE_SIGNAL != dbus_message_get_type(msg))
  {
    return DBUS_HANDLER_RESULT_NOT_YET_HANDLED;
  }
  centerDidHandle = [(DKNotificationCenter*)center _handleMessage: msg];
  if (centerDidHandle)
  {
    return DBUS_HANDLER_RESULT_HANDLED;
  }
  return DBUS_HANDLER_RESULT_NOT_YET_HANDLED;
}
