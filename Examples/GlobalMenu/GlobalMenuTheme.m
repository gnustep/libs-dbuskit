#include "GlobalMenuTheme.h"

/*
 * The class used by the DBus menu registry
 */
static Class _menuRegistryClass;

@implementation GlobalMenuTheme
- (Class)_findDBusMenuRegistryClass
{
  NSString	*path;
  NSBundle	*bundle;
  NSArray	*paths;
  NSUInteger	count;

  if (Nil != _menuRegistryClass)
    {
      return _menuRegistryClass;
    }
  paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory,
    NSAllDomainsMask, YES);
  count = [paths count];
  while (count-- > 0)
    {
       path = [paths objectAtIndex: count];
       path = [path stringByAppendingPathComponent: @"Bundles"];
       path = [path stringByAppendingPathComponent: @"DBusMenu"];
       path = [path stringByAppendingPathExtension: @"bundle"];
       bundle = [NSBundle bundleWithPath: path];
       if (bundle != nil)
         {
           if ((_menuRegistryClass = [bundle principalClass]) != Nil)
             {
               break;  
             }
         }
     }
  return _menuRegistryClass;
}

- (id) initWithBundle: (NSBundle *)bundle
{
  if((self = [super initWithBundle: bundle]) != nil)
    {
    }
  menuRegistry = [[self _findDBusMenuRegistryClass] new];
  return self;
}

- (void)setMenu: (NSMenu*)m forWindow: (NSWindow*)w
{
  if (nil != menuRegistry)
    {
      [menuRegistry setMenu: m forWindow: w];
    }
  else
    {
      // Get normal in-window menus when the menu server is unavailable
      [super setMenu: m forWindow: w];
    }
}

@end
