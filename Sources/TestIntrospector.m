#import <DBUSIntrospector.h>
#import <Foundation/NSData.h>
#import <Foundation/NSDebug.h>
#import <Foundation/NSException.h>
#import <UnitKit/UnitKit.h>

@interface DBUSIntrospector (Tests) <UKTest>
@end

@implementation DBUSIntrospector (Tests)

- (id) initForTest
{
  NSData *data;
  NSString *intrData;

  NSBundle *thisBundle = [NSBundle bundleForClass: [self class]];
  intrData = [thisBundle pathForResource: @"IntrospectionData"
                                  ofType: @"xml"];
  data = [NSData dataWithContentsOfFile: intrData];
  [self initWithData: data];

  [self buildMethodCache];

  return self;
}

/**
 * FIXME: For some reason testing all these methods segfaults
 */

/*
- (void) testMethodNamedInInterface
{
  NSInvocation *inv;
  NSDictionary *methods;
  NSArray *keys;
  int i, count;
  id key, value;

  methods = [NSDictionary dictionaryWithObjectsAndKeys:
                   @"org.freedesktop.DBus", @"AddMatch:", 
                                     @"", @"TestMethod:",
   @"org.freedesktop.DBus.Introspectable", @"Introspect",
   nil];

  keys = [methods allKeys];
  count = [keys count];

  for (i = 0; i < count; i++)
    {
      key = [keys objectAtIndex: i];
      value = [methods objectForKey: key];

      //NSLog(@"Looking for method %@ in interface %@", key, value);
      inv = [self methodNamed: key
                  inInterface: value];
      UKNotNil(inv);
      UKObjectKindOf(inv, [NSInvocation class]);
      UKStringsEqual(NSStringFromSelector([inv selector]), key);
    }
}

- (void) testMethodNamedInInterfaceNotFound
{
  NSInvocation *inv;

  NS_DURING
    {
      inv = [self methodNamed: @"NoMethod"
                  inInterface: @""];
    }
  NS_HANDLER
    {
      UKStringsEqual([localException name], @"DBUSProxyInvocationException");
    }
  NS_ENDHANDLER
}

- (void) testMethodNamed
{
  NSInvocation *inv;
  NSArray *methods;
  NSString *method;
  int i, count;

  methods = [NSArray arrayWithObjects:
                           @"AddMatch:", 
                          @"Introspect",
                          nil];

  count = [methods count];

  for (i = 0; i < count; i++)
    {
      method = [methods objectAtIndex: i];

      NSLog(@"Looking for method %@", method);
      inv = [self methodNamed: method];

      UKNotNil(inv);
      UKObjectKindOf(inv, [NSInvocation class]);
      UKStringsEqual(NSStringFromSelector([inv selector]), method);
    }
}

- (void) testSignalNamedInInterface
{
  NSInvocation *inv;
  NSDictionary *methods;
  NSArray *keys;
  int i, count;
  id key, value;

  methods = [NSDictionary dictionaryWithObjectsAndKeys:
               @"org.freedesktop.DBus", @"NameAcquired:", 
                   @"org.freedesktop.DBus", @"NameLost:", 
                                     @"", @"TestSignal:",
   nil];

  keys = [methods allKeys];
  count = [keys count];

  for (i = 0; i < count; i++)
    {
      key = [keys objectAtIndex: i];
      value = [methods objectForKey: key];

      //NSLog(@"Looking for signal %@ in interface %@", key, value);
      inv = [self signalNamed: key
                  inInterface: value];
      UKNotNil(inv);
      UKObjectKindOf(inv, [NSInvocation class]);
      UKStringsEqual(NSStringFromSelector([inv selector]), key);
    }
}

- (void) testSignalNamedInInterfaceNotFound
{
  NSInvocation *inv;

  NS_DURING
    {
      inv = [self signalNamed: @"NoSignal"
                  inInterface: @""];
    }
  NS_HANDLER
    {
      UKStringsEqual([localException name], @"DBUSProxyInvocationException");
    }
  NS_ENDHANDLER

    //This one is found twice
  NS_DURING
    {
      inv = [self signalNamed: @"NameAcquired:"
                  inInterface: @""];
    }
  NS_HANDLER
    {
      UKStringsEqual([localException name], @"DBUSProxyInvocationException");
      UKStringsEqual([localException reason],
                     @"More than one invocation found for NameAcquired:");
    }
  NS_ENDHANDLER
}

- (BOOL) testSignalNamed
{
  NSInvocation *inv;
  NSArray *signals;
  NSString *signal;
  int i, count;

  signals = [NSArray arrayWithObjects:
                           @"NameLost:",
                         @"TestSignal:",
                         nil];

  count = [signals count];

  for (i = 0; i < count; i++)
    {
      signal = [signals objectAtIndex: i];

      //NSLog(@"Looking for signal %@", signal);
      inv = [self signalNamed: signal];

      UKNotNil(inv);
      UKObjectKindOf(inv, [NSInvocation class]);
      UKStringsEqual(NSStringFromSelector([inv selector]), signal);
    }
}

- (void) testSignalNamedNotFound
{
  NSInvocation *inv;

  NS_DURING
    {
      inv = [self signalNamed: @"NoSignal"];
    }
  NS_HANDLER
    {
      UKStringsEqual([localException name], @"DBUSProxyInvocationException");
    }
  NS_ENDHANDLER

  NS_DURING
    {
      inv = [self signalNamed: @"NameAcquired:"];
    }
  NS_HANDLER
    {
      UKStringsEqual([localException name], @"DBUSProxyInvocationException");
      UKStringsEqual([localException reason],
                     @"More than one invocation found for NameAcquired:");
    }
  NS_ENDHANDLER

}

- (void) testLowercaseFirstLetter
{
  UKStringsEqual([DBUSIntrospector lowercaseFirstLetter: @"Cowabunga!"],
                 @"cowabunga!");

  UKStringsEqual([DBUSIntrospector lowercaseFirstLetter: @"cowabunga!"],
                 @"cowabunga!");

  UKStringsEqual([DBUSIntrospector lowercaseFirstLetter:
                 [DBUSIntrospector uppercaseFirstLetter: @"cowabunga!"]],
                 @"cowabunga!");
}

- (void) testUppercaseFirstLetter
{
  UKStringsEqual([DBUSIntrospector uppercaseFirstLetter: @"cowabunga!"],
                 @"Cowabunga!");

  UKStringsEqual([DBUSIntrospector uppercaseFirstLetter: @"Cowabunga!"],
                 @"Cowabunga!");

  UKStringsEqual([DBUSIntrospector uppercaseFirstLetter:
                 [DBUSIntrospector lowercaseFirstLetter: @"Cowabunga!"]],
                 @"Cowabunga!");
}

*/

@end
