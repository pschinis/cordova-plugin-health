// AppDelegate+HealthKit.m
#import "AppDelegate+HealthKit.h"
#import "HealthKit.h"
#import <objc/runtime.h>
#import <WebKit/WebKit.h>

@implementation AppDelegate (HealthKit)

void HKMethodSwizzle(Class c, SEL originalSelector) {
    NSString *selectorString = NSStringFromSelector(originalSelector);
    SEL newSelector = NSSelectorFromString([@"healthkit_" stringByAppendingString:selectorString]);
    SEL noopSelector = NSSelectorFromString([@"noop_" stringByAppendingString:selectorString]);
    Method originalMethod, newMethod, noop;
    originalMethod = class_getInstanceMethod(c, originalSelector);
    newMethod = class_getInstanceMethod(c, newSelector);
    noop = class_getInstanceMethod(c, noopSelector);
    if (class_addMethod(c, originalSelector, method_getImplementation(newMethod), method_getTypeEncoding(newMethod))) {
        class_replaceMethod(c, newSelector, method_getImplementation(originalMethod) ?: method_getImplementation(noop), method_getTypeEncoding(originalMethod));
    } else {
        method_exchangeImplementations(originalMethod, newMethod);
    }
}

+ (void)load {
    HKMethodSwizzle([self class], @selector(application:didFinishLaunchingWithOptions:));
}

- (BOOL)healthkit_application:(UIApplication*)application didFinishLaunchingWithOptions:(NSDictionary*)launchOptions {
    [self healthkit_application:application didFinishLaunchingWithOptions:launchOptions];
    
    HKSampleType *sampleType = [HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierStepCount];
    
    HKObserverQuery *query =
    [[HKObserverQuery alloc]
     initWithSampleType:sampleType
     predicate:nil
     updateHandler:^(HKObserverQuery *query,
                     HKObserverQueryCompletionHandler completionHandler,
                     NSError *error) {

        if (error) {
            NSLog(@"An error occured while setting up the stepCount observer. In your app, try to handle this gracefully. Error: %@", error);
            return;
        }

        [HealthKit sendObservedChanges:NO completionHandler:completionHandler errorHandler:^(NSString *errorMsg) {
            NSLog(@"An error occured while sending HealthKit data. Error: %@", errorMsg);
        }];
        
    }];

    [[HealthKit sharedHealthStore] executeQuery:query];
    
    return YES;
}

- (BOOL)noop_application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary*)launchOptions {
    return NO;
}

@end
