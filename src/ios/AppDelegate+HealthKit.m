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
    
    HKSampleType *stepType = [HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierStepCount];
    NSArray *typesToObserve = @[[HKObjectType workoutType],[HKObjectType correlationTypeForIdentifier:HKCorrelationTypeIdentifierFood],[HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierBodyMass],stepType];
    NSPredicate *sourcePredicate = [HKQuery predicateForObjectsFromSource:[HKSource defaultSource]];

    
    for (HKObjectType *sampleType in typesToObserve) {
            HKObserverQuery *query = [[HKObserverQuery alloc]
                initWithSampleType:sampleType
                predicate:[NSCompoundPredicate notPredicateWithSubpredicate:sourcePredicate]
                updateHandler:^(HKObserverQuery *query,
                                HKObserverQueryCompletionHandler completionHandler,
                                NSError *error) {
                    int minDelay = (sampleType == stepType) ? 15*60 : 30;

                    if (error) {
                        NSLog(@"An error occured while setting up the stepCount observer. In your app, try to handle this gracefully. Error: %@", error);
                        return;
                    }

                    [HealthKit sendObservedChanges:minDelay completionHandler:completionHandler errorHandler:^(NSString *errorMsg) {
                        NSLog(@"An error occured while sending HealthKit data. Error: %@", errorMsg);
                    }];
            }];

            [[HealthKit sharedHealthStore] executeQuery:query];
    }


    
    
    return YES;
}

- (BOOL)noop_application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary*)launchOptions {
    return NO;
}

@end
