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
#import <Foundation/NSNull.h>
#import <Foundation/NSSet.h>
#import <Foundation/NSString.h>

#import <GNUstepBase/NSDebug+GNUstepBase.h>

#include <stdint.h>
#include <stdarg.h>
#include <dbus/dbus.h>

@class DKObservation;

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
   * The bus-type that should be used when making queries to the D-Bus object.
   */
   DKDBusBusType type;
}
- (void)addObservation: (DKObservation*)observation;
@end

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

  /**
   * Pointer to the method implementation for the callback.
   */
  IMP method;

  /**
   * A pointer back to the information about the observed signal.
   */
  DKObservable *observed;
}

- (id)initWithObservable: (DKObservable*)observable
                observer: (id)observer
                selector: (SEL)selector;
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

- (void)addObservation: (DKObservation*)observation
{
  DKObservation *oldObservation = [observations member: observation];
  if (nil == oldObservation)
  {
    [observations addObject: observation];
  }
}

- (void)removeObservation: (DKObservation*)observation
{
  DKObservation *oldObservation = [observations member: observation];
  if (nil != oldObservation)
  {
    [observations removeObject: oldObservation];
  }
}

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

- (id)ruleForKey: (NSString*)key
{
  return [rules objectForKey: key];
}

- (void)filterInterface: (NSString*)interface
{
  [self setRule: interface
         forKey: @"interface"];
}

- (void)filterSignalName: (NSString*)signalName
{
  [self setRule: signalName
         forKey: @"member"];
}

- (void)filterSignal: (DKSignal*)signal
{
  [self filterSignalName: [signal name]];
  [self filterInterface: [[signal parent] name]];
}

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

- (void)filterSender: (DKProxy*)proxy
{
  [self setRule: [proxy _service]
         forKey: @"sender"];
  [self setRule: [proxy _path]
         forKey: @"path"];
}


- (void)filterDestination: (DKProxy*)proxy
{
  NSString *uniqueName = [proxy _uniqueName];
  [self setRule: uniqueName
         forKey: @"destination"];
}

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

- (NSUInteger)hash
{
  return [rules hash];
}

- (NSDictionary*)rules
{
  return [[rules copy] autorelease];
}
- (BOOL)isEqual: (DKObservable*)other
{
  return [rules isEqualToDictionary: [other rules]];
}

- (NSHashTable*)observations
{
  return observations;
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
    if (([@"sender" isEqualToString: thisKey]) && (nil != thisRule))
    {
      /*
       * The sender in the userInfo will be a unique name, but the match name
       * might have been another name registered for the service. We thus need
       * to get the owner of the name from the bus.
       */
      thisRule = [[DKDBus busWithBusType: type] GetNameOwner: thisRule];
    }

    if (nil != thisRule)
    {
      id thisValue = [dict objectForKey: thisKey];

      // For proxies we want to match the object paths:
      if ([thisValue isKindOfClass: [DKProxy class]])
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
  [rules release];
  [observations release];
  [super dealloc];
}
@end

@implementation DKObservation

- (id)initWithObservable: (DKObservable*)anObservable
                observer: (id)anObserver
                selector: (SEL)aSelector
{
  if (nil == (self = [super init]))
  {
    return nil;
  }
  ASSIGN(observed, anObservable);
  observer = GS_GC_HIDE(anObserver);
  selector = aSelector;
  //TODO: IMP caching.
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

- (DKObservable*)observed
{
  return observed;
}

- (NSUInteger)hash
{
  return (((NSUInteger)(uintptr_t)observer ^ (NSUInteger)selector) ^ [observed hash]);
}

- (BOOL)isEqual: (DKObservation*)other
{
  BOOL sameObserver = (observer == [other observer]);
  BOOL sameSelector = sel_isEqual(selector, [other selector]);
  BOOL sameObserved = [observed isEqual: [other observed]];
  return ((sameObserver && sameSelector) && sameObserved);
}

- (void)dealloc
{
  [observed release];
  [super dealloc];
}
@end


static DKNotificationCenter *systemCenter;
static DKNotificationCenter *sessionCenter;

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

  lock = [[NSLock alloc] init];
  signalInfo = [[NSMutableDictionary alloc] init];
  notificationNames = [[NSMutableDictionary alloc] init];

  observables = NSCreateHashTable(NSObjectHashCallBacks, 5);
  observers = [[NSMapTable alloc] initWithKeyOptions: (NSPointerFunctionsObjectPersonality | NSPointerFunctionsZeroingWeakMemory)
                                        valueOptions: NSPointerFunctionsObjectPersonality
				            capacity: 5];

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
  DKObservable *observable = nil;
  if ((nil != notificationName) && (nil == signal))
  {
    //TODO: fail silently or raise an exception?
    NSWarnMLog(@"Cannot observe notification %@ (no corresponding D-Bus signal).",
      notificationName);
    return;
  }

  observable = [self _observableForSignalName: [signal name]
                                    interface: [[signal parent] name]
                                       sender: sender
                                  destination: destination
				       filter: nil
				      atIndex: 0];
  [self _letObserver: observer
   observeObservable: observable
        withSelector: notifySelector];
}

- (void)addObserver: (id)observer
           selector: (SEL)notifySelector
               name: (NSString*)notificationName
	     object: (DKProxy*)sender
{
  [self addObserver: observer
           selector: notifySelector
               name: notificationName
             sender: sender
        destination: nil];
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
  DKObservable *observable = [self _observableForSignalName: signalName
                                                  interface: interfaceName
                                                     sender: sender
                                                destination: destination
                                                     filter: filter
						    atIndex: index];
  [self _letObserver: observer
   observeObservable: observable
        withSelector: notifySelector];
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
             filter: nil
             atIndex: 0];
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
  NSHashTable *observationTable = nil;
  NSHashTable *enumTable = nil;
  NSHashEnumerator obsEnum;
  DKObservation *thisObservation = nil;
  [lock lock];

  observationTable = (NSHashTable*)NSMapGet(observers, (void*)observer);
  if (nil == observationTable)
  {
    [lock unlock];
    return;
  }
  // We copy the table be cause we will modify it subsequently:
  enumTable = NSCopyHashTableWithZone(observationTable, NULL);
  [lock unlock];
  obsEnum = NSEnumerateHashTable(enumTable);
  while (nil != (thisObservation = NSNextHashEnumeratorItem(&obsEnum)))
  {
    [self _removeObserver: observer
            forObservable: [thisObservation observed]];
    // On removal of the last observation, _removeObserver:forObservable: will
    // remove the entry from the observers table.
  }
  NSEndHashTableEnumeration(&obsEnum);
  NSFreeHashTable(enumTable);
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
           destination: destination];
}

- (void)removeObserver: (id)observer
                  name: (NSString*)notificationName
                object: (DKProxy*)sender
{
  [self removeObserver: observer
                  name: notificationName
                sender: sender
           destination: nil];
}

- (void)removeObserver: (id)observer
                signal: (NSString*)signalName
             interface: (NSString*)interfaceName
                sender: (DKProxy*)sender
           destination: (DKProxy*)destination
{
  DKObservable *observable = [self _observableForSignalName: signalName
                                                  interface: interfaceName
                                                     sender: sender
                                                destination: destination
						     filter: nil
						    atIndex: 0];
  [self _removeObserver: observer
          forObservable: observable];
}

- (void)removeObserver: (id)observer
                signal: (NSString*)signalName
             interface: (NSString*)interfaceName
                sender: (DKProxy*)sender
           destination: (DKProxy*)destination
	        filter: (NSString*)filter
    	       atIndex: (NSUInteger)index
{
  DKObservable *observable = [self _observableForSignalName: signalName
                                                  interface: interfaceName
                                                     sender: sender
                                                destination: destination
						     filter: filter
						    atIndex: index];
  [self _removeObserver: observer
          forObservable: observable];
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
           destination: nil];
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

- (void)_letObserver: (id)observer
   observeObservable: (DKObservable*)observable
        withSelector: (SEL)selector
{
  DKObservation *observation = [[DKObservation alloc] initWithObservable: observable
                                                                observer: observer
                                                                selector: selector];
  DKObservable *oldObservable = nil;
  NSHashTable *observationTable = nil;
  BOOL firstObservation = NO;
  DBusError err;
  dbus_error_init(&err);
  dbus_bus_add_match([endpoint DBusConnection],
    [[observable ruleString] UTF8String],
    &err);

  if (dbus_error_is_set(&err))
  {
    [observation release];
    [NSException raise: @"DKSignalMatchException"
                format: @"Error when trying to add match for signal: %s. (%s)",
      err.name, err.message];
  }
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

  NS_DURING
  {
    observationTable = NSMapGet(observers, (void*)observer);

    /*
     * If a hash table for observations by this object doesn't exist, create one:
     */
    if (nil == observationTable)
    {
      observationTable = NSCreateHashTable(NSObjectHashCallBacks ,5);
      NS_DURING
      {
        NSMapInsert(observers, observer, observationTable);
      }
      NS_HANDLER
      {
        NSFreeHashTable(observationTable);
        [localException raise];
      }
      NS_ENDHANDLER
      NSFreeHashTable(observationTable);
    }
    NSHashInsertIfAbsent(observationTable, observation);
  }
  NS_HANDLER
  {
    //Roll back:
    [observable removeObservation: observation];
    if (firstObservation)
    {
      NSHashRemove(observables, observable);
      [self _removeHandler];
    }
    [lock unlock];
    [localException raise];
  }
  NS_ENDHANDLER
  [lock unlock];
}

- (void)_removeObserver: (id)observer
          forObservable: (DKObservable*)observable
{
  NSHashTable *observationsInObserver = nil; // = A
  DKObservable *theObservable = nil;
  NSHashTable *observationsInObservable = nil; // = B
  NSHashTable *intersectTable = nil; // = C
  BOOL lastObservationInObservable = NO;
  DBusError err;

  [lock lock];

  /*
   * First stage of cleanup: Remove references to the observation from the
   * per-observer (A) and per-observable (B) tables.
   */
  NS_DURING
  {
    observationsInObserver = NSMapGet(observers, observer);
    theObservable = NSHashGet(observables, observable);
    if ((nil == theObservable) || (nil == observationsInObserver))
    {
      // This observable does not seem to be monitored, just returned.
      [lock unlock];
      return;
    }


    observationsInObservable = [theObservable observations];
    intersectTable = NSCopyHashTableWithZone(observationsInObservable, NULL);

    // Compute the intersection of A and B. (C = {x|(x in A) and (x in B)})
    [intersectTable intersectHashTable: observationsInObserver];

    // Subtract the members of C from A and from B respectively.
    [observationsInObserver minusHashTable: intersectTable];
    [observationsInObservable minusHashTable: intersectTable];

    // Dispose of the hash table.
    NSFreeHashTable(intersectTable);
    intersectTable = nil;
  }
  NS_HANDLER
  {
    if (nil != intersectTable)
    {
      NSFreeHashTable(intersectTable);
    }
    [lock unlock];
    [localException raise];
  }
  NS_ENDHANDLER

  /*
   * Second stage of cleanup: If we left one of the tables empty, remove it and
   * its key from the observables and observers tables.
   */
  NS_DURING
  {
    lastObservationInObservable = (0 == NSCountHashTable(observationsInObservable));
    if (lastObservationInObservable)
    {
      NSHashRemove(observables, theObservable);
    }

    if (0 == NSCountHashTable(observationsInObserver))
    {
      NSMapRemove(observers, observer);
    }
  }
  NS_HANDLER
  {
    [lock unlock];
    [localException raise];
  }
  NS_ENDHANDLER

  /*
   * Third stage of cleanup: If we removed all observations for the observable,
   * also remove the match rule.
   */
  if (lastObservationInObservable)
  {
    dbus_error_init(&err);

      // remove the match rule from D-Bus.
      dbus_bus_remove_match([endpoint DBusConnection],
        [[observable ruleString] UTF8String],
        &err);

      if (dbus_error_is_set(&err))
      {
        [lock unlock];
        [NSException raise: @"DKSignalMatchException"
                    format: @"Error when trying to remove match for signal: %s. (%s)",
          err.name, err.message];
      }
  }

  /*
   * Fourth stage of cleanup: If we have no observables left, also remove the
   * D-Bus message handler until we have further signals to watch.
   */
  if (0 == NSCountHashTable(observables))
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

- (DKSignal*)_signalForNotificationName: (NSString*)name
{
  DKSignal *signal = [notificationNames objectForKey: name];
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
      return nil;
    }
    ifName = [stripped substringToIndex: (sepRange.location - 1)];
    signalName = [stripped substringFromIndex: (sepRange.location + 1)];
    return [self _signalWithName: signalName
                     inInterface: ifName];
  }
  return nil;
}

- (BOOL)_registerNotificationName: (NSString*)notificationName
                         asSignal: (DKSignal*)signal
{
  if ((nil == notificationName) || (nil == signal));
  {
    return NO;
  }

  if (nil == [notificationNames objectForKey: notificationName])
  {
    [notificationNames setObject: signal
                          forKey: notificationName];

    NSDebugMLog(@"Registered signal '%@' (from interface '%@') with notification name '%@'.",
      [signal name],
      [[signal parent] name],
      notificationName);
    return YES;
  }
  else
  {
    NSDebugMLog(@"Cannot register signal '%@' (from interface '%@') with notification name '%@' (already registered).",
      [signal name],
      [[signal parent] name],
      notificationName);
  }
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

- (BOOL)_handleMessage: (DBusMessage*)msg
{
  const char *cSignal = dbus_message_get_member(msg);
  NSString *signal = nil;
  const char *cInterface = dbus_message_get_interface(msg);
  NSString *interface = nil;
  const char *cSender = dbus_message_get_member(msg);
  NSString *sender = nil;
  const char *cPath = dbus_message_get_path(msg);
  NSString *path = nil;
  const char *cDestination = dbus_message_get_destination(msg);
  NSString *destination = nil;
  const char *signature = dbus_message_get_signature(msg);
  DBusMessageIter iter;
  NSMutableDictionary *userInfo = nil;
  DKProxy *senderProxy = nil;
  DKSignal *theSignal = nil;

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

  /*
   * Copy the signal allows us to set the sender as its parent (circumventing
   * the interface at this time. This is needed because the arguments might need
   * to construct object paths and such.
   */
  theSignal = [[[self _signalWithName: signal
                          inInterface: interface] copy] autorelease];

  senderProxy = [DKProxy proxyWithEndpoint: endpoint
                                andService: sender
                                   andPath: path];
  [theSignal setParent: senderProxy];

  userInfo = [[NSMutableDictionary alloc] initWithObjectsAndKeys: signal, @"signal",
    interface, @"interface",
    sender, @"sender",
    path, @"path",
    destination, @"destination",
    nil];

  NSLog(@"Handling signal %@ in interface %@ from %@ (%@) to %@. Signature: %s",
    signal,
    interface,
    sender,
    path,
    destination,
    signature);

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
  NSLog(@"UserInfo: %@", userInfo);
  return YES;
}

- (void)dealloc
{
  [endpoint release];
  [signalInfo release];
  [notificationNames release];
  // TODO: Free the dispatch tables!
  [lock release];
  [super dealloc];
}
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
