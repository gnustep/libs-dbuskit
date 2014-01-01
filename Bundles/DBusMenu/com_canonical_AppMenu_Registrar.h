#import <Foundation/Foundation.h>

/*
 * Objective-C protocol declaration for the D-Bus com.canonical.AppMenu.Registrar interface.
 */
@protocol com_canonical_AppMenu_Registrar

- (NSArray*)GetMenuForWindow: (NSNumber*)windowId;

- (void)RegisterWindow: (NSNumber*)windowId : (DKProxy*)menuObjectPath;

- (void)UnregisterWindow: (NSNumber*)windowId;

@end
