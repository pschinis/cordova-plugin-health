#import "Cordova/CDV.h"
#import <HealthKit/HealthKit.h>

@interface HealthKit :CDVPlugin

+ (HKHealthStore *)sharedHealthStore;

+ (void)queryObservedSamples:(NSMutableArray *)observedSampleTypes currentResults:(NSMutableDictionary *)currentResults onComplete:(void(^)(NSMutableDictionary *results))onComplete onError:(void(^)(NSString *errorMsg))onError;

+ (void)querySampleTypeCoreWithStartDate:(NSDate *)startDate endDate:(NSDate *)endDate sampleTypeString:(NSString *)sampleTypeString unitString:(NSString *)unitString limit:(NSUInteger)limit ascending:(BOOL)ascending returnSources:(BOOL)returnSources filterOutUserInput:(BOOL)filterOutUserInput onError:(void(^)(NSError *error))onError onSuccess:(void(^)(NSArray *results))onSuccess;

+ (void)querySampleTypeAggregatedCore:(NSDate *)startDate endDate:(NSDate *)endDate sampleTypeString:(NSString *)sampleTypeString unitString:(NSString *)unitString aggregation:(NSString *)aggregation extraPredicate:(NSPredicate *)extraPredicate filterOutUserInput:(BOOL)filterOutUserInput onSuccess:(void (^)(NSArray *))onSuccess onError:(void (^)(NSString *))onError;

+ (void)findWorkoutsWithOnError:(void(^)(NSError *error))onError onSuccess:(void(^)(NSArray *results))onSuccess;

+ (void)sendObservedChanges:(int)minDelay completionHandler:(void(^)(void))completionHandler errorHandler:(void(^)(NSString *errorMsg))errorHandler;

/**
 * Tell delegate whether or not health data is available
 *
 * @param command *CDVInvokedUrlCommand
 */
- (void) available:(CDVInvokedUrlCommand*)command;

/**
 * Check the authorization status for a specified permission
 *
 * @param command *CDVInvokedUrlCommand
 */
- (void) checkAuthStatus:(CDVInvokedUrlCommand*)command;

/**
 * Request authorization for read and/or write permissions
 *
 * @param command *CDVInvokedUrlCommand
 */
- (void) requestAuthorization:(CDVInvokedUrlCommand*)command;

/**
 * Read gender data
 *
 * @param command *CDVInvokedUrlCommand
 */
- (void) readGender:(CDVInvokedUrlCommand*)command;

/**
 * Read blood type data
 *
 * @param command *CDVInvokedUrlCommand
 */
- (void) readBloodType:(CDVInvokedUrlCommand*)command;

/**
 * Read date of birth data
 *
 * @param command *CDVInvokedUrlCommand
 */
- (void) readDateOfBirth:(CDVInvokedUrlCommand*)command;

/**
 * Read Fitzpatrick Skin Type Data
 *
 * @param command *CDVInvokedUrlCommand
 */
- (void) readFitzpatrickSkinType:(CDVInvokedUrlCommand*)command;

/**
 * Save weight data
 *
 * @param command *CDVInvokedUrlCommand
 */
- (void) saveWeight:(CDVInvokedUrlCommand*)command;

/**
 * Read weight data
 *
 * @param command *CDVInvokedUrlCommand
 */
- (void) readWeight:(CDVInvokedUrlCommand*)command;

/**
 * Save height data
 *
 * @param command *CDVInvokedUrlCommand
 */
- (void) saveHeight:(CDVInvokedUrlCommand*)command;

/**
 * Read height data
 *
 * @param command *CDVInvokedUrlCommand
 */
- (void) readHeight:(CDVInvokedUrlCommand*)command;

/**
 * Save workout data
 *
 * @param command *CDVInvokedUrlCommand
 */
- (void) saveWorkout:(CDVInvokedUrlCommand*)command;

/**
 * Find workout data
 *
 * @param command *CDVInvokedUrlCommand
 */
- (void) findWorkouts:(CDVInvokedUrlCommand*)command;

/**
 * Monitor a specified sample type
 *
 * @param command *CDVInvokedUrlCommand
 */
- (void) monitorSampleType:(CDVInvokedUrlCommand*)command;

/**
 * Get the sum of a specified quantity type
 *
 * @param command *CDVInvokedUrlCommand
 */
- (void) sumQuantityType:(CDVInvokedUrlCommand*)command;

/**
 * Query a specified sample type
 *
 * @param command *CDVInvokedUrlCommand
 */
- (void) querySampleType:(CDVInvokedUrlCommand*)command;

/**
 * Query a specified sample type using an aggregation
 *
 * @param command *CDVInvokedUrlCommand
 */
- (void) querySampleTypeAggregated:(CDVInvokedUrlCommand*)command;

/**
 * Save sample data
 *
 * @param command *CDVInvokedUrlCommand
 */
- (void) saveSample:(CDVInvokedUrlCommand*)command;

/**
 * Save correlation data
 *
 * @param command *CDVInvokedUrlCommand
 */
- (void) saveCorrelation:(CDVInvokedUrlCommand*)command;

/**
 * Query a specified correlation type
 *
 * @param command *CDVInvokedUrlCommand
 */
- (void) queryCorrelationType:(CDVInvokedUrlCommand*)command;

/**
 * Delete matching samples from the HealthKit store
 *
 * @param command *CDVInvokedUrlCommand
 */
- (void) deleteSamples:(CDVInvokedUrlCommand*)command;
- (void) deleteObjectById:(CDVInvokedUrlCommand *)command;
/**
 * Observe changes on a given sample type
 *
 * @param command *CDVInvokedUrlCommand
 */
- (void)observeChanges:(CDVInvokedUrlCommand*)command;

- (void)sendObservedChanges:(CDVInvokedUrlCommand*)command;

@end
