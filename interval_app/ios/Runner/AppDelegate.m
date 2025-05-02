#import <Flutter/Flutter.h>
#import <UIKit/UIKit.h>
#import "GeneratedPluginRegistrant.h"

@interface AppDelegate : FlutterAppDelegate
@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
  [GeneratedPluginRegistrant registerWithRegistry:self];
  return [super application:application didFinishLaunchingWithOptions:launchOptions];
}

@end
