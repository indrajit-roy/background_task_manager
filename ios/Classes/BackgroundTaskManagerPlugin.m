#import "BackgroundTaskManagerPlugin.h"
#if __has_include(<background_task_manager/background_task_manager-Swift.h>)
#import <background_task_manager/background_task_manager-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "background_task_manager-Swift.h"
#endif

@implementation BackgroundTaskManagerPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftBackgroundTaskManagerPlugin registerWithRegistrar:registrar];
}
@end
