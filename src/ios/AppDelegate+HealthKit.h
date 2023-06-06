// AppDelegate+HealthKit.h
#import "AppDelegate.h"
#import <HealthKit/HealthKit.h>

@interface AppDelegate (HealthKit)

@property (nonatomic, strong) HKHealthStore *healthStore;

@end