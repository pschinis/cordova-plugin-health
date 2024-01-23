#import "HealthKit.h"
#import "HKHealthStore+AAPLExtensions.h"
#import "WorkoutActivityConversion.h"
#import <WebKit/WebKit.h>


#pragma clang diagnostic push
#pragma ide diagnostic ignored "OCNotLocalizedStringInspection"
#define HKPLUGIN_DEBUG

#pragma mark Property Type Constants
static NSString *const HKPluginError = @"HKPluginError";
static NSString *const HKPluginKeyReadTypes = @"readTypes";
static NSString *const HKPluginKeyWriteTypes = @"writeTypes";
static NSString *const HKPluginKeyType = @"type";
static NSString *const HKPluginKeyStartDate = @"startDate";
static NSString *const HKPluginKeyEndDate = @"endDate";
static NSString *const HKPluginKeySampleType = @"sampleType";
static NSString *const HKPluginKeyAggregation = @"aggregation";
static NSString *const HKPluginKeyUnit = @"unit";
static NSString *const HKPluginKeyUnits = @"units";
static NSString *const HKPluginKeyAmount = @"amount";
static NSString *const HKPluginKeyValue = @"value";
static NSString *const HKPluginKeyCorrelationType = @"correlationType";
static NSString *const HKPluginKeyObjects = @"samples";
static NSString *const HKPluginKeySampleTypes = @"sampleTypes";
static NSString *const HKPluginKeyUpdateUrl = @"updateUrl";
static NSString *const HKPluginKeySourceName = @"sourceName";
static NSString *const HKPluginKeySourceBundleId = @"sourceBundleId";
static NSString *const HKPluginKeyMetadata = @"metadata";
static NSString *const HKPluginKeyUUID = @"UUID";

static NSDictionary *HKSampleTypeToUnit;
static NSDictionary *HKSampleTypeToJSType;
static NSDictionary *HKNutritionTypeToSimplified;

#pragma mark Categories

// NSDictionary check if there is a value for a required key and populate an error if not present
@interface NSDictionary (RequiredKey)
- (BOOL)hasAllRequiredKeys:(NSArray<NSString *> *)keys error:(NSError **)error;
@end

// Public Interface extension category
//@interface HealthKit ()
//+ (HKHealthStore *)sharedHealthStore;
//@end

// Internal interface
@interface HealthKit (Internal)
- (void)checkAuthStatusWithCallbackId:(NSString *)callbackId
                              forType:(HKObjectType *)type
                        andCompletion:(void (^)(CDVPluginResult *result, NSString *innerCallbackId))completion;
@end


// Internal interface helper methods
@interface HealthKit (InternalHelpers)
+ (NSString *)stringFromDate:(NSDate *)date;

+ (HKUnit *)getUnit:(NSString *)type expected:(NSString *)expected;

+ (HKObjectType *)getHKObjectType:(NSString *)elem;

+ (HKQuantityType *)getHKQuantityType:(NSString *)elem;

+ (HKSampleType *)getHKSampleType:(NSString *)elem;

- (HKQuantitySample *)loadHKSampleFromInputDictionary:(NSDictionary *)inputDictionary error:(NSError **)error;

- (HKCorrelation *)loadHKCorrelationFromInputDictionary:(NSDictionary *)inputDictionary error:(NSError **)error;

+ (HKQuantitySample *)getHKQuantitySampleWithStartDate:(NSDate *)startDate endDate:(NSDate *)endDate sampleTypeString:(NSString *)sampleTypeString unitTypeString:(NSString *)unitTypeString value:(double)value metadata:(NSDictionary *)metadata error:(NSError **)error;

- (HKCorrelation *)getHKCorrelationWithStartDate:(NSDate *)startDate endDate:(NSDate *)endDate correlationTypeString:(NSString *)correlationTypeString objects:(NSSet *)objects metadata:(NSDictionary *)metadata error:(NSError **)error;

+ (void)triggerErrorCallbackWithMessage: (NSString *) message command: (CDVInvokedUrlCommand *) command delegate: (id<CDVCommandDelegate>) delegate;

+ (void)executeOnMainThread:(void (^)(void))block;

+ (NSDictionary *)filterDictionaryForJSON:(NSDictionary *)input;

+ (NSDictionary *)extractNutritionInfoFromFoodCorrelation:(HKCorrelation *)foodCorrelation;

@end

/**
 * Implementation of internal interface
 * **************************************************************************************
 */
#pragma mark Internal Interface

@implementation HealthKit (Internal)
+ (void)initialize {
    if( self == [HealthKit self]) {
        HKSampleTypeToUnit = @{
           @"HKQuantityTypeIdentifierStepCount" : @"count",
           @"HKQuantityTypeIdentifierDistanceWalkingRunning" : @"m",
           @"HKQuantityTypeIdentifierActiveEnergyBurned" : @"kcal",
           @"HKQuantityTypeIdentifierBasalEnergyBurned" : @"kcal",
           @"HKQuantityTypeIdentifierHeight" : @"m",
           @"HKQuantityTypeIdentifierBodyMass" : @"kg",
           @"HKQuantityTypeIdentifierBodyMassIndex" : @"count",
           @"HKQuantityTypeIdentifierHeartRate" : @"count/min",
           @"HKQuantityTypeIdentifierRestingHeartRate" : @"count/min",
           @"HKQuantityTypeIdentifierHeartRateVariabilitySDNN" : @"ms",
           @"HKQuantityTypeIdentifierBodyFatPercentage" : @"%",
           @"HKQuantityTypeIdentifierWaistCircumference" : @"m",
           @"HKQuantityTypeIdentifierDietaryEnergyConsumed" : @"kcal",
           @"HKQuantityTypeIdentifierDietaryFatTotal" : @"g",
           @"HKQuantityTypeIdentifierDietaryFatSaturated" : @"g",
           @"HKQuantityTypeIdentifierDietaryFatPolyunsaturated" : @"g",
           @"HKQuantityTypeIdentifierDietaryFatMonounsaturated" : @"g",
           @"HKQuantityTypeIdentifierDietaryCholesterol" : @"mg",
           @"HKQuantityTypeIdentifierDietarySodium" : @"mg",
           @"HKQuantityTypeIdentifierDietaryPotassium" : @"mg",
           @"HKQuantityTypeIdentifierDietaryCarbohydrates" : @"g",
           @"HKQuantityTypeIdentifierDietaryFiber" : @"g",
           @"HKQuantityTypeIdentifierDietarySugar" : @"g",
           @"HKQuantityTypeIdentifierDietaryProtein" : @"g",
           @"HKQuantityTypeIdentifierDietaryVitaminA" : @"mcg",
           @"HKQuantityTypeIdentifierDietaryVitaminC" : @"mg",
           @"HKQuantityTypeIdentifierDietaryCalcium" : @"mg",
           @"HKQuantityTypeIdentifierDietaryIron" : @"mg",
           @"HKQuantityTypeIdentifierDietaryWater" : @"ml",
           @"HKQuantityTypeIdentifierDietaryCaffeine" : @"g",
           @"HKQuantityTypeIdentifierBloodGlucose" : @"mmol/L",
           @"HKQuantityTypeIdentifierInsulinDelivery" : @"IU",
           @"HKQuantityTypeIdentifierAppleExerciseTime" : @"min",
           @"HKQuantityTypeIdentifierBloodPressureSystolic" : @"mmHg",
           @"HKQuantityTypeIdentifierBloodPressureDiastolic" : @"mmHg",
           @"HKQuantityTypeIdentifierRespiratoryRate" : @"count/min",
           @"HKQuantityTypeIdentifierOxygenSaturation" : @"%",
           @"HKQuantityTypeIdentifierVO2Max" : @"ml/(kg*min)",
           @"HKQuantityTypeIdentifierBodyTemperature" : @"degC",
           @"HKQuantityTypeIdentifierUVExposure" : @"count"
       };
        
        HKSampleTypeToJSType = @{
            @"HKCategoryTypeIdentifierMindfulSession" : @"mindfulness",
            @"HKQuantityTypeIdentifierStepCount" : @"steps",
            @"HKQuantityTypeIdentifierFlightsClimbed" : @"stairs",
            @"HKQuantityTypeIdentifierDistanceWalkingRunning" : @"distance",
            @"HKQuantityTypeIdentifierActiveEnergyBurned" : @"calories.active",
            @"HKQuantityTypeIdentifierBasalEnergyBurned" : @"calories.basal",
            @"HKQuantityTypeIdentifierHeight" : @"height",
            @"HKQuantityTypeIdentifierBodyMass" : @"weight",
            @"HKQuantityTypeIdentifierBodyMassIndex" : @"bmi",
            @"HKQuantityTypeIdentifierHeartRate" : @"heart_rate",
            @"HKQuantityTypeIdentifierRestingHeartRate" : @"heart_rate.resting",
            @"HKQuantityTypeIdentifierHeartRateVariabilitySDNN" : @"heart_rate.variability",
            @"HKQuantityTypeIdentifierBodyFatPercentage" : @"fat_percentage",
            @"HKQuantityTypeIdentifierWaistCircumference" : @"waist_circumference",
            @"HKWorkoutTypeIdentifier" : @"activity",
            @"HKCategoryTypeIdentifierSleepAnalysis" : @"sleep",
            @"HKCorrelationTypeIdentifierFood" : @"nutrition",
            @"HKQuantityTypeIdentifierDietaryEnergyConsumed" : @"nutrition.calories",
            @"HKQuantityTypeIdentifierDietaryFatTotal" : @"nutrition.fat.total",
            @"HKQuantityTypeIdentifierDietaryFatSaturated" : @"nutrition.fat.saturated",
            @"HKQuantityTypeIdentifierDietaryFatPolyunsaturated" : @"nutrition.fat.polyunsaturated",
            @"HKQuantityTypeIdentifierDietaryFatMonounsaturated" : @"nutrition.fat.monounsaturated",
            @"HKQuantityTypeIdentifierDietaryCholesterol" : @"nutrition.cholesterol",
            @"HKQuantityTypeIdentifierDietarySodium" : @"nutrition.sodium",
            @"HKQuantityTypeIdentifierDietaryPotassium" : @"nutrition.potassium",
            @"HKQuantityTypeIdentifierDietaryCarbohydrates" : @"nutrition.carbs.total",
            @"HKQuantityTypeIdentifierDietaryFiber" : @"nutrition.dietary_fiber",
            @"HKQuantityTypeIdentifierDietarySugar" : @"nutrition.sugar",
            @"HKQuantityTypeIdentifierDietaryProtein" : @"nutrition.protein",
            @"HKQuantityTypeIdentifierDietaryVitaminA" : @"nutrition.vitamin_a",
            @"HKQuantityTypeIdentifierDietaryVitaminC" : @"nutrition.vitamin_c",
            @"HKQuantityTypeIdentifierDietaryCalcium" : @"nutrition.calcium",
            @"HKQuantityTypeIdentifierDietaryIron" : @"nutrition.iron",
            @"HKQuantityTypeIdentifierDietaryWater" : @"nutrition.water",
            @"HKQuantityTypeIdentifierDietaryCaffeine" : @"nutrition.caffeine",
            @"HKQuantityTypeIdentifierBloodGlucose" : @"blood_glucose",
            @"HKQuantityTypeIdentifierInsulinDelivery" : @"insulin",
            @"HKQuantityTypeIdentifierAppleExerciseTime" : @"appleExerciseTime",
            @"HKCorrelationTypeIdentifierBloodPressure" : @"blood_pressure",
            @"HKQuantityTypeIdentifierBloodPressureSystolic" : @"blood_pressure_systolic",
            @"HKQuantityTypeIdentifierBloodPressureDiastolic" : @"blood_pressure_diastolic",
            @"HKQuantityTypeIdentifierRespiratoryRate" : @"resp_rate",
            @"HKQuantityTypeIdentifierOxygenSaturation" : @"oxygen_saturation",
            @"HKQuantityTypeIdentifierVO2Max" : @"vo2max",
            @"HKQuantityTypeIdentifierBodyTemperature" : @"temperature",
            @"HKQuantityTypeIdentifierUVExposure" : @"UVexposure"
        };
        
        HKNutritionTypeToSimplified = @{
            HKQuantityTypeIdentifierDietaryEnergyConsumed: @"calories",
            HKQuantityTypeIdentifierDietaryProtein: @"protein",
            HKQuantityTypeIdentifierDietaryFatTotal: @"fat",
            HKQuantityTypeIdentifierDietaryCarbohydrates: @"carbs",
            HKQuantityTypeIdentifierDietaryFiber: @"fiber"
        };

    }
}
/**
 * Check the authorization status for a HealthKit type and dispatch the callback with result
 *
 * @param callbackId    *NSString
 * @param type          *HKObjectType
 * @param completion    void(^)
 */
- (void)checkAuthStatusWithCallbackId:(NSString *)callbackId forType:(HKObjectType *)type andCompletion:(void (^)(CDVPluginResult *, NSString *))completion {

    CDVPluginResult *pluginResult = nil;

    if (type == nil) {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"type is an invalid value"];
    } else {
        HKAuthorizationStatus status = [[HealthKit sharedHealthStore] authorizationStatusForType:type];

        NSString *authorizationResult = nil;
        switch (status) {
            case HKAuthorizationStatusSharingAuthorized:
                authorizationResult = @"authorized";
                break;
            case HKAuthorizationStatusSharingDenied:
                authorizationResult = @"denied";
                break;
            default:
                authorizationResult = @"undetermined";
        }

#ifdef HKPLUGIN_DEBUG
        NSLog(@"Health store returned authorization status: %@ for type %@", authorizationResult, [type description]);
#endif

        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:authorizationResult];
    }

    completion(pluginResult, callbackId);
}

@end

/**
 * Implementation of internal helpers interface
 * **************************************************************************************
 */
#pragma mark Internal Helpers

@implementation HealthKit (InternalHelpers)

+ (NSDictionary *)extractNutritionInfoFromFoodCorrelation:(HKCorrelation *)foodCorrelation {
    // Define your keys
    NSArray *keys = @[HKQuantityTypeIdentifierDietaryEnergyConsumed, HKQuantityTypeIdentifierDietaryProtein, HKQuantityTypeIdentifierDietaryFatTotal, HKQuantityTypeIdentifierDietaryCarbohydrates, HKQuantityTypeIdentifierDietaryFiber];
    
    // Initialize the dictionary with 0 values for each type
    NSMutableDictionary *nutritionInfo = [NSMutableDictionary dictionaryWithDictionary:@{
        HKNutritionTypeToSimplified[HKQuantityTypeIdentifierDietaryEnergyConsumed]: @(0),
        HKNutritionTypeToSimplified[HKQuantityTypeIdentifierDietaryProtein]: @(0),
        HKNutritionTypeToSimplified[HKQuantityTypeIdentifierDietaryFatTotal]: @(0),
        HKNutritionTypeToSimplified[HKQuantityTypeIdentifierDietaryCarbohydrates]: @(0),
        HKNutritionTypeToSimplified[HKQuantityTypeIdentifierDietaryFiber]: @(0)
    }];
    
    for (HKSample *sample in foodCorrelation.objects) {
        if ([sample isKindOfClass:[HKQuantitySample class]]) {
            HKQuantitySample *quantitySample = (HKQuantitySample *)sample;
            if ([keys containsObject:quantitySample.quantityType.identifier]) {
                NSString *key = HKNutritionTypeToSimplified[quantitySample.quantityType.identifier];
                double existingValue = [nutritionInfo[key] doubleValue];
                double valueToAdd = 0;
                
                if ([quantitySample.quantityType.identifier isEqualToString:HKQuantityTypeIdentifierDietaryEnergyConsumed]) {
                    valueToAdd = [quantitySample.quantity doubleValueForUnit:[HKUnit kilocalorieUnit]];
                } else {
                    valueToAdd = [quantitySample.quantity doubleValueForUnit:[HKUnit gramUnit]];
                }
                
                nutritionInfo[key] = @(existingValue + valueToAdd);
            }
        }
    }
    
    return [nutritionInfo copy];
}

+ (void)executeOnMainThread:(void (^)(void))block {
    if ([NSThread isMainThread]) {
        block();
    } else {
        dispatch_sync(dispatch_get_main_queue(), block);
    }
}

+ (NSDictionary *)filterDictionaryForJSON:(NSDictionary *)input {
    if(!input) {
        return @{};
    }
    
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    [input enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        if ([key isKindOfClass:[NSString class]] && ([obj isKindOfClass:[NSString class]] || [obj isKindOfClass:[NSNumber class]])) {
            result[key] = obj;
        }
    }];
    return [result copy];
}

/**
 * Get a string representation of an NSDate object
 *
 * @param date  *NSDate
 * @return      *NSString
 */
+ (NSString *)stringFromDate:(NSDate *)date {
    __strong static NSDateFormatter *formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
        [formatter setLocale:[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"]];
        [formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZZZZZ"];
    });

    return [formatter stringFromDate:date];
}

/**
 * Get a HealthKit unit and make sure its local representation matches what is expected
 *
 * @param type      *NSString
 * @param expected  *NSString
 * @return          *HKUnit
 */
+ (HKUnit *)getUnit:(NSString *)type expected:(NSString *)expected {
    HKUnit *localUnit;
    @try {
        // this throws an exception instead of returning nil if type is unknown
        localUnit = [HKUnit unitFromString:type];
        if ([[[localUnit class] description] isEqualToString:expected]) {
            return localUnit;
        } else {
            return nil;
        }
    }
    @catch (NSException *e) {
        return nil;
    }
}

/**
 * Get a HealthKit object type by name
 *
 * @param elem  *NSString
 * @return      *HKObjectType
 */
+ (HKObjectType *)getHKObjectType:(NSString *)elem {

    HKObjectType *type = nil;

    type = [HKObjectType quantityTypeForIdentifier:elem];
    if (type != nil) {
        return type;
    }

    type = [HKObjectType characteristicTypeForIdentifier:elem];
    if (type != nil) {
        return type;
    }

    // @TODO | The fall through here is inefficient.
    // @TODO | It needs to be refactored so the same HK method isnt called twice
    return [HealthKit getHKSampleType:elem];
}

/**
 * Get a HealthKit quantity type by name
 *
 * @param elem  *NSString
 * @return      *HKQuantityType
 */
+ (HKQuantityType *)getHKQuantityType:(NSString *)elem {
    return [HKQuantityType quantityTypeForIdentifier:elem];
}

/**
 * Get sample type by name
 *
 * @param elem  *NSString
 * @return      *HKSampleType
 */
+ (HKSampleType *)getHKSampleType:(NSString *)elem {

    HKSampleType *type = nil;

    type = [HKObjectType quantityTypeForIdentifier:elem];
    if (type != nil) {
        return type;
    }

    type = [HKObjectType categoryTypeForIdentifier:elem];
    if (type != nil) {
        return type;
    }

    type = [HKObjectType correlationTypeForIdentifier:elem];
    if (type != nil) {
        return type;
    }

    if ([elem isEqualToString:@"workoutType"]) {
        return [HKObjectType workoutType];
    }

    // leave this here for if/when apple adds other sample types
    return type;

}

/**
 * Parse out a sample from a dictionary and perform error checking
 *
 * @param inputDictionary   *NSDictionary
 * @param error             **NSError
 * @return                  *HKQuantitySample
 */
- (HKSample *)loadHKSampleFromInputDictionary:(NSDictionary *)inputDictionary error:(NSError **)error {
    //Load quantity sample from args to command

    if (![inputDictionary hasAllRequiredKeys:@[HKPluginKeyStartDate, HKPluginKeyEndDate, HKPluginKeySampleType] error:error]) {
        return nil;
    }

    NSDate *startDate = [NSDate dateWithTimeIntervalSince1970:[inputDictionary[HKPluginKeyStartDate] longValue]];
    NSDate *endDate = [NSDate dateWithTimeIntervalSince1970:[inputDictionary[HKPluginKeyEndDate] longValue]];
    NSString *sampleTypeString = inputDictionary[HKPluginKeySampleType];

    //Load optional metadata key
    NSDictionary *metadata = inputDictionary[HKPluginKeyMetadata];
    if (metadata == nil) {
      metadata = @{};
    }

    if ([inputDictionary objectForKey:HKPluginKeyUnit]) {
        if (![inputDictionary hasAllRequiredKeys:@[HKPluginKeyUnit] error:error]) return nil;
        NSString *unitString = [inputDictionary objectForKey:HKPluginKeyUnit];

            return [HealthKit getHKQuantitySampleWithStartDate:startDate
                                                   endDate:endDate
                                          sampleTypeString:sampleTypeString
                                            unitTypeString:unitString
                                                     value:[inputDictionary[HKPluginKeyAmount] doubleValue]
                                                  metadata:metadata error:error];
    } else {
            if (![inputDictionary hasAllRequiredKeys:@[HKPluginKeyValue] error:error]) return nil;
            NSString *categoryString = [inputDictionary objectForKey:HKPluginKeyValue];

            return [self getHKCategorySampleWithStartDate:startDate
                                                       endDate:endDate
                                              sampleTypeString:sampleTypeString
                                                categoryString:categoryString
                                                      metadata:metadata
                                                         error:error];
        }
  }

/**
 * Parse out a correlation from a dictionary and perform error checking
 *
 * @param inputDictionary   *NSDictionary
 * @param error             **NSError
 * @return                  *HKCorrelation
 */
- (HKCorrelation *)loadHKCorrelationFromInputDictionary:(NSDictionary *)inputDictionary error:(NSError **)error {
    //Load correlation from args to command

    if (![inputDictionary hasAllRequiredKeys:@[HKPluginKeyStartDate, HKPluginKeyEndDate, HKPluginKeyCorrelationType, HKPluginKeyObjects] error:error]) {
        return nil;
    }

    NSDate *startDate = [NSDate dateWithTimeIntervalSince1970:[inputDictionary[HKPluginKeyStartDate] longValue]];
    NSDate *endDate = [NSDate dateWithTimeIntervalSince1970:[inputDictionary[HKPluginKeyEndDate] longValue]];
    NSString *correlationTypeString = inputDictionary[HKPluginKeyCorrelationType];
    NSArray *objectDictionaries = inputDictionary[HKPluginKeyObjects];

    NSMutableSet *objects = [NSMutableSet set];
    for (NSDictionary *objectDictionary in objectDictionaries) {
        HKSample *sample = [self loadHKSampleFromInputDictionary:objectDictionary error:error];
        if (sample == nil) {
            return nil;
        }
        [objects addObject:sample];
    }

    NSDictionary *metadata = inputDictionary[HKPluginKeyMetadata];
    if (metadata == nil) {
        metadata = @{};
    }
    return [self getHKCorrelationWithStartDate:startDate
                                       endDate:endDate
                         correlationTypeString:correlationTypeString
                                       objects:objects
                                      metadata:metadata
                                         error:error];
}

/**
 * Query HealthKit to get a quantity sample in a specified date range
 *
 * @param startDate         *NSDate
 * @param endDate           *NSDate
 * @param sampleTypeString  *NSString
 * @param unitTypeString    *NSString
 * @param value             double
 * @param metadata          *NSDictionary
 * @param error             **NSError
 * @return                  *HKQuantitySample
 */
+ (HKQuantitySample *)getHKQuantitySampleWithStartDate:(NSDate *)startDate
                                               endDate:(NSDate *)endDate
                                      sampleTypeString:(NSString *)sampleTypeString
                                        unitTypeString:(NSString *)unitTypeString
                                                 value:(double)value
                                              metadata:(NSDictionary *)metadata
                                                 error:(NSError **)error {
    HKQuantityType *type = [HealthKit getHKQuantityType:sampleTypeString];
    if (type == nil) {
        if (error != nil) {
            *error = [NSError errorWithDomain:HKPluginError code:0 userInfo:@{NSLocalizedDescriptionKey: @"quantity type string was invalid"}];
        }

        return nil;
    }

    HKUnit *unit = nil;
    @try {
        if (unitTypeString != nil) {
            if ([unitTypeString isEqualToString:@"mmol/L"]) {
                // @see https://stackoverflow.com/a/30196642/1214598
                unit = [[HKUnit moleUnitWithMetricPrefix:HKMetricPrefixMilli molarMass:HKUnitMolarMassBloodGlucose] unitDividedByUnit:[HKUnit literUnit]];
            } else {
                // issue 51
                // @see https://github.com/Telerik-Verified-Plugins/HealthKit/issues/51
                if ([unitTypeString isEqualToString:@"percent"]) {
                    unitTypeString = @"%";
                }
                unit = [HKUnit unitFromString:unitTypeString];
            }
        } else {
            if (error != nil) {
                *error = [NSError errorWithDomain:HKPluginError code:0 userInfo:@{NSLocalizedDescriptionKey: @"unit is invalid"}];
            }
            return nil;
        }
    } @catch (NSException *e) {
        if (error != nil) {
            *error = [NSError errorWithDomain:HKPluginError code:0 userInfo:@{NSLocalizedDescriptionKey: @"unit is invalid"}];
        }
        return nil;
    }

    HKQuantity *quantity = [HKQuantity quantityWithUnit:unit doubleValue:value];
    if (![quantity isCompatibleWithUnit:unit]) {
        if (error != nil) {
            *error = [NSError errorWithDomain:HKPluginError code:0 userInfo:@{NSLocalizedDescriptionKey: @"unit is not compatible with quantity"}];
        }

        return nil;
    }

    return [HKQuantitySample quantitySampleWithType:type quantity:quantity startDate:startDate endDate:endDate metadata:metadata];
}

// Helper to handle the functionality with HealthKit to get a category sample
- (HKCategorySample*) getHKCategorySampleWithStartDate:(NSDate*) startDate endDate:(NSDate*) endDate sampleTypeString:(NSString*) sampleTypeString categoryString:(NSString*) categoryString metadata:(NSDictionary*) metadata error:(NSError**) error {
    HKCategoryType *type = [HKCategoryType categoryTypeForIdentifier:sampleTypeString];
    if (type==nil) {
      *error = [NSError errorWithDomain:HKPluginError code:0 userInfo:@{NSLocalizedDescriptionKey:@"quantity type string is invalid"}];
      return nil;
    }
    NSNumber* value = [self getCategoryValueByName:categoryString type:type];
    if (value == nil && ![type.identifier isEqualToString:@"HKCategoryTypeIdentifierMindfulSession"]) {
        *error = [NSError errorWithDomain:HKPluginError code:0 userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"%@,%@,%@",@"category value is not compatible with category",type.identifier,categoryString]}];
        return nil;
    }

    return [HKCategorySample categorySampleWithType:type value:[value integerValue] startDate:startDate endDate:endDate];
}

- (NSNumber*) getCategoryValueByName:(NSString *) categoryValue type:(HKCategoryType*) type {
    NSDictionary * map = @{
      @"HKCategoryTypeIdentifierSleepAnalysis":@{
        @"HKCategoryValueSleepAnalysisInBed":@(HKCategoryValueSleepAnalysisInBed),
        @"HKCategoryValueSleepAnalysisAsleep":@(HKCategoryValueSleepAnalysisAsleep),
        @"HKCategoryValueSleepAnalysisAwake":@(HKCategoryValueSleepAnalysisAwake),
        @"HKCategoryValueSleepAnalysisAsleepCore":@(HKCategoryValueSleepAnalysisAsleepCore),
        @"HKCategoryValueSleepAnalysisAsleepDeep":@(HKCategoryValueSleepAnalysisAsleepDeep),
        @"HKCategoryValueSleepAnalysisAsleepREM":@(HKCategoryValueSleepAnalysisAsleepREM)
      }
    };

    NSDictionary * valueMap = map[type.identifier];
    if (!valueMap) {
      return HKCategoryValueNotApplicable;
    }
    return valueMap[categoryValue];
}

/**
 * Query HealthKit to get correlation data within a specified date range
 *
 * @param startDate
 * @param endDate
 * @param correlationTypeString
 * @param objects
 * @param metadata
 * @param error
 * @return
 */
- (HKCorrelation *)getHKCorrelationWithStartDate:(NSDate *)startDate
                                         endDate:(NSDate *)endDate
                           correlationTypeString:(NSString *)correlationTypeString
                                         objects:(NSSet *)objects
                                        metadata:(NSDictionary *)metadata
                                           error:(NSError **)error {
#ifdef HKPLUGIN_DEBUG
    NSLog(@"correlation type is %@", correlationTypeString);
#endif

    HKCorrelationType *correlationType = [HKCorrelationType correlationTypeForIdentifier:correlationTypeString];
    if (correlationType == nil) {
        if (error != nil) {
            *error = [NSError errorWithDomain:HKPluginError code:0 userInfo:@{NSLocalizedDescriptionKey: @"correlation type string is invalid"}];
        }

        return nil;
    }

    return [HKCorrelation correlationWithType:correlationType startDate:startDate endDate:endDate objects:objects metadata:metadata];
}

/**
 * Trigger a generic error callback
 *
 * @param message   *NSString
 * @param command   *CDVInvokedUrlCommand
 * @param delegate  id<CDVCommandDelegate>
 */
+ (void)triggerErrorCallbackWithMessage: (NSString *) message command: (CDVInvokedUrlCommand *) command delegate: (id<CDVCommandDelegate>) delegate {
    @autoreleasepool {
        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:message];
        [delegate sendPluginResult:result callbackId:command.callbackId];
    }
}

@end

/**
 * Implementation of NSDictionary (RequiredKey)
 */
#pragma mark NSDictionary (RequiredKey)

@implementation NSDictionary (RequiredKey)

/**
 *
 * @param keys  *NSArray
 * @param error **NSError
 * @return      BOOL
 */
- (BOOL)hasAllRequiredKeys:(NSArray<NSString *> *)keys error:(NSError **)error {
    NSMutableArray *missing = [NSMutableArray arrayWithCapacity:0];

    for (NSString *key in keys) {
        if (self[key] == nil) {
            [missing addObject:key];
        }
    }

    if (missing.count == 0) {
        return YES;
    }

    if (error != nil) {
        NSString *errMsg = [NSString stringWithFormat:@"required value(s) -%@- is missing from dictionary %@", [missing componentsJoinedByString:@", "], [self description]];
        *error = [NSError errorWithDomain:HKPluginError code:0 userInfo:@{NSLocalizedDescriptionKey: errMsg}];
    }

    return NO;
}

@end

/**
 * Implementation of public interface
 * **************************************************************************************
 */
#pragma mark Public Interface

@implementation HealthKit

/**
 * Get shared health store
 *
 * @return *HKHealthStore
 */
+ (HKHealthStore *)sharedHealthStore {
    __strong static HKHealthStore *store = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        store = [[HKHealthStore alloc] init];
    });

    return store;
}

/**
 * Tell delegate whether or not health data is available
 *
 * @param command *CDVInvokedUrlCommand
 */
- (void)available:(CDVInvokedUrlCommand *)command {
    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:[HKHealthStore isHealthDataAvailable]];
    [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
}

/**
 * Request authorization for read and/or write permissions
 *
 * @param command *CDVInvokedUrlCommand
 */
- (void)requestAuthorization:(CDVInvokedUrlCommand *)command {
    NSMutableDictionary *args = command.arguments[0];

    // read types
    NSArray<NSString *> *readTypes = args[HKPluginKeyReadTypes];
    NSMutableSet *readDataTypes = [[NSMutableSet alloc] init];

    for (NSString *elem in readTypes) {
#ifdef HKPLUGIN_DEBUG
        NSLog(@"Requesting read permissions for %@", elem);
#endif
        HKObjectType *type = nil;

        if ([elem isEqual:@"HKWorkoutTypeIdentifier"]) {
            type = [HKObjectType workoutType];
        } else {
            type = [HealthKit getHKObjectType:elem];
        }

        if (type == nil) {
            CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"readTypes contains an invalid value"];
            [result setKeepCallbackAsBool:YES];
            [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
            // not returning deliberately to be future proof; other permissions are still asked
        } else {
            [readDataTypes addObject:type];
        }
    }

    // write types
    NSArray<NSString *> *writeTypes = args[HKPluginKeyWriteTypes];
    NSMutableSet *writeDataTypes = [[NSMutableSet alloc] init];

    for (NSString *elem in writeTypes) {
#ifdef HKPLUGIN_DEBUG
        NSLog(@"Requesting write permission for %@", elem);
#endif
        HKObjectType *type = nil;

        if ([elem isEqual:@"HKWorkoutTypeIdentifier"]) {
            type = [HKObjectType workoutType];
        } else {
            type = [HealthKit getHKObjectType:elem];
        }

        if (type == nil) {
            CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"writeTypes contains an invalid value"];
            [result setKeepCallbackAsBool:YES];
            [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
            // not returning deliberately to be future proof; other permissions are still asked
        } else {
            [writeDataTypes addObject:type];
        }
    }

    [[HealthKit sharedHealthStore] requestAuthorizationToShareTypes:writeDataTypes readTypes:readDataTypes completion:^(BOOL success, NSError *error) {
        if (success) {
            [HealthKit executeOnMainThread:^{
                CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
                [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
            }];
        } else {
            [HealthKit executeOnMainThread:^{
                CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:error.localizedDescription];
                [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
            }];
        }
    }];
}

/**
 * Check the authorization status for a specified permission
 *
 * @param command *CDVInvokedUrlCommand
 */
- (void)checkAuthStatus:(CDVInvokedUrlCommand *)command {
    // If status = denied, prompt user to go to settings or the Health app
    // Note that read access is not reflected. We're not allowed to know
    // if a user grants/denies read access, *only* write access.
    NSMutableDictionary *args = command.arguments[0];
    NSString *checkType = args[HKPluginKeyType];
    HKObjectType *type;

    if ([checkType isEqual:@"HKWorkoutTypeIdentifier"]) {
        type = [HKObjectType workoutType];
    } else {
        type = [HealthKit getHKObjectType:checkType];
    }

    __block HealthKit *bSelf = self;
    [self checkAuthStatusWithCallbackId:command.callbackId forType:type andCompletion:^(CDVPluginResult *result, NSString *callbackId) {
        [bSelf.commandDelegate sendPluginResult:result callbackId:callbackId];
    }];
}

/**
 * Save workout data
 *
 * @param command *CDVInvokedUrlCommand
 */
- (void)saveWorkout:(CDVInvokedUrlCommand *)command {
    NSMutableDictionary *args = command.arguments[0];

    NSString *activityType = args[@"activityType"];
    NSString *quantityType = args[@"quantityType"]; // TODO verify this value

    HKWorkoutActivityType activityTypeEnum = [WorkoutActivityConversion convertStringToHKWorkoutActivityType:activityType];

    BOOL requestReadPermission = (args[@"requestReadPermission"] == nil || [args[@"requestReadPermission"] boolValue]);
    BOOL *cycling = (args[@"cycling"] != nil && [args[@"cycling"] boolValue]);

    // optional energy
    NSNumber *energy = args[@"energy"];
    NSString *energyUnit = args[@"energyUnit"];
    HKQuantity *nrOfEnergyUnits = nil;
    if (energy != nil && energy != (id) [NSNull null]) { // better safe than sorry
        HKUnit *preferredEnergyUnit = [HealthKit getUnit:energyUnit expected:@"HKEnergyUnit"];
        if (preferredEnergyUnit == nil) {
            [HealthKit triggerErrorCallbackWithMessage:@"invalid energyUnit is passed" command:command delegate:self.commandDelegate];
            return;
        }
        nrOfEnergyUnits = [HKQuantity quantityWithUnit:preferredEnergyUnit doubleValue:energy.doubleValue];
    }

    // optional distance
    NSNumber *distance = args[@"distance"];
    NSString *distanceUnit = args[@"distanceUnit"];
    HKQuantity *nrOfDistanceUnits = nil;
    if (distance != nil && distance != (id) [NSNull null]) { // better safe than sorry
        HKUnit *preferredDistanceUnit = [HealthKit getUnit:distanceUnit expected:@"HKLengthUnit"];
        if (preferredDistanceUnit == nil) {
            [HealthKit triggerErrorCallbackWithMessage:@"invalid distanceUnit is passed" command:command delegate:self.commandDelegate];
            return;
        }
        nrOfDistanceUnits = [HKQuantity quantityWithUnit:preferredDistanceUnit doubleValue:distance.doubleValue];
    }

    int duration = 0;
    NSDate *startDate = [NSDate dateWithTimeIntervalSince1970:[args[HKPluginKeyStartDate] doubleValue]];


    NSDate *endDate;
    if (args[@"duration"] != nil) {
        duration = [args[@"duration"] intValue];
        endDate = [NSDate dateWithTimeIntervalSince1970:startDate.timeIntervalSince1970 + duration];
    } else if (args[HKPluginKeyEndDate] != nil) {
        endDate = [NSDate dateWithTimeIntervalSince1970:[args[HKPluginKeyEndDate] doubleValue]];
    } else {
        [HealthKit triggerErrorCallbackWithMessage:@"no duration or endDate is set" command:command delegate:self.commandDelegate];
        return;
    }
    
    NSDictionary *metadata = args[HKPluginKeyMetadata];
    metadata = [HealthKit filterDictionaryForJSON:metadata];

    NSSet *types = [NSSet setWithObjects:
            [HKWorkoutType workoutType],
            [HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierActiveEnergyBurned],
            [HKQuantityType quantityTypeForIdentifier:quantityType],
                    nil];
    [[HealthKit sharedHealthStore] requestAuthorizationToShareTypes:types readTypes:(requestReadPermission ? types : nil) completion:^(BOOL success_requestAuth, NSError *error) {
        __block HealthKit *bSelf = self;
        if (!success_requestAuth) {
            [HealthKit executeOnMainThread:^{
                [HealthKit triggerErrorCallbackWithMessage:error.localizedDescription command:command delegate:bSelf.commandDelegate];
            }];
        } else {
            HKWorkout *workout = [HKWorkout workoutWithActivityType:activityTypeEnum
                                                          startDate:startDate
                                                            endDate:endDate
                                                           duration:0 // the diff between start and end is used
                                                  totalEnergyBurned:nrOfEnergyUnits
                                                      totalDistance:nrOfDistanceUnits
                                                           metadata:metadata]; // TODO find out if needed

            [[HealthKit sharedHealthStore] saveObject:workout withCompletion:^(BOOL success_save, NSError *innerError) {
                if (success_save) {
                    // now store the samples, so it shows up in the health app as well (pass this in as an option?)
                    if (energy != nil || distance != nil) {
                        HKQuantitySample *sampleDistance = nil;
                        if(distance != nil) {
                            if(cycling != nil && cycling){
                                sampleDistance = [HKQuantitySample quantitySampleWithType:[HKQuantityType quantityTypeForIdentifier:
                                                HKQuantityTypeIdentifierDistanceCycling]
                                                                                            quantity:nrOfDistanceUnits
                                                                                            startDate:startDate
                                                                                                endDate:endDate];
                            } else {
                                sampleDistance = [HKQuantitySample quantitySampleWithType:[HKQuantityType quantityTypeForIdentifier:
                                                HKQuantityTypeIdentifierDistanceWalkingRunning]
                                                                                            quantity:nrOfDistanceUnits
                                                                                            startDate:startDate
                                                                                                endDate:endDate];

                            }
                        }
                        HKQuantitySample *sampleCalories = nil;
                        if(energy != nil) {
                            sampleCalories = [HKQuantitySample quantitySampleWithType:[HKQuantityType     quantityTypeForIdentifier:
                                            HKQuantityTypeIdentifierActiveEnergyBurned]
                                                                                           quantity:nrOfEnergyUnits
                                                                                          startDate:startDate
                                                                                            endDate:endDate];
                        }
                         NSArray *samples = nil;
                         if (energy != nil &&  distance != nil) { 
                            // both distance and energy
                            samples = @[sampleDistance, sampleCalories];
                         } else if (energy != nil &&  distance == nil) { 
                            // only energy
                            samples = @[sampleCalories];
                         } else if (energy == nil &&  distance != nil) {
                            // only distance
                            samples = @[sampleDistance];
                         }
                        

                        [[HealthKit sharedHealthStore] addSamples:samples toWorkout:workout completion:^(BOOL success_addSamples, NSError *mostInnerError) {
                            if (success_addSamples) {
                                [HealthKit executeOnMainThread:^{
                                    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:workout.UUID.UUIDString];
                                    [bSelf.commandDelegate sendPluginResult:result callbackId:command.callbackId];
                                }];
                            } else {
                                [HealthKit executeOnMainThread:^{
                                    [HealthKit triggerErrorCallbackWithMessage:mostInnerError.localizedDescription command:command delegate:bSelf.commandDelegate];
                                }];
                            }
                        }];
                    } else {
                      // no samples, all OK then!
                        [HealthKit executeOnMainThread:^{
                          CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:workout.UUID.UUIDString];
                          [bSelf.commandDelegate sendPluginResult:result callbackId:command.callbackId];
                        }];
                    }
                } else {
                    [HealthKit executeOnMainThread:^{
                        [HealthKit triggerErrorCallbackWithMessage:innerError.localizedDescription command:command delegate:bSelf.commandDelegate];
                    }];
                }
            }];
        }
    }];
}

+ (void)findWorkoutsWithOnError:(void(^)(NSError *error))onError onSuccess:(void(^)(NSArray *results))onSuccess {
    NSPredicate *workoutPredicate = nil;
    // TODO if a specific workouttype was passed, use that
    //  if (false) {
    //    workoutPredicate = [HKQuery predicateForWorkoutsWithWorkoutActivityType:HKWorkoutActivityTypeCycling];
    //  }

    BOOL *includeCalsAndDist = YES;

    NSSet *types = [NSSet setWithObjects:[HKWorkoutType workoutType], nil];
    [[HealthKit sharedHealthStore] requestAuthorizationToShareTypes:nil readTypes:types completion:^(BOOL success, NSError *error) {
        __block HealthKit *bSelf = self;
        if (!success) {
            onError(error);
        } else {


            HKSampleQuery *query = [[HKSampleQuery alloc] initWithSampleType:[HKWorkoutType workoutType] predicate:workoutPredicate limit:100 sortDescriptors:nil resultsHandler:^(HKSampleQuery *sampleQuery, NSArray *results, NSError *innerError) {
                if (innerError) {
                    onError(innerError);
                } else {
                    NSMutableArray *finalResults = [[NSMutableArray alloc] initWithCapacity:results.count];

                    for (HKWorkout *workout in results) {
                        NSString *workoutActivity = [WorkoutActivityConversion convertHKWorkoutActivityTypeToString:workout.workoutActivityType];

                        // iOS 9 moves the source property to a collection of revisions
                        HKSource *source = nil;
                        if ([workout respondsToSelector:@selector(sourceRevision)]) {
                            source = [[workout valueForKey:@"sourceRevision"] valueForKey:@"source"];
                        } else {
                            //@TODO Update deprecated API call
                            source = workout.source;
                        }
                        NSMutableDictionary *entry;
                        NSDictionary *allStatistics = @{};
                        NSMutableDictionary *statsDict = [NSMutableDictionary new];

                        if (@available(iOS 16.0, *)) {
                            allStatistics = workout.allStatistics;
                                                        
                            for (HKQuantityType *quantityType in allStatistics) {
                                HKStatistics *statistics = allStatistics[quantityType];
                                HKQuantity *averageQuantity = statistics.averageQuantity;
                                if(averageQuantity == nil) {
                                    averageQuantity = statistics.sumQuantity;
                                }
                                NSString *key = HKSampleTypeToJSType[quantityType.identifier];
                                NSString *unitString = HKSampleTypeToUnit[quantityType.identifier];

                                
                                if (averageQuantity && key && unitString) {
                                    HKUnit *unit = nil;
                                    if ([unitString isEqualToString:@"mmol/L"]) {
                                        // @see https://stackoverflow.com/a/30196642/1214598
                                        unit = [[HKUnit moleUnitWithMetricPrefix:HKMetricPrefixMilli molarMass:HKUnitMolarMassBloodGlucose] unitDividedByUnit:[HKUnit literUnit]];
                                    } else {
                                        // issue 51
                                        // @see https://github.com/Telerik-Verified-Plugins/HealthKit/issues/51
                                        if ([unitString isEqualToString:@"percent"]) {
                                            unitString = @"%";
                                        }
                                        unit = [HKUnit unitFromString:unitString];
                                    }
                                    if(unit != nil) {
                                        double quantity = [averageQuantity doubleValueForUnit:unit];
                                        statsDict[key] = [NSString stringWithFormat:@"%f %@", quantity, unitString];
                                    }
                                }
                            }
                        }

                        if(includeCalsAndDist != nil && includeCalsAndDist) {
                            double meters = [workout.totalDistance doubleValueForUnit:[HKUnit meterUnit]];
                            NSString *metersString = [NSString stringWithFormat:@"%ld", (long) meters];

                            // Parse totalEnergyBurned in kilocalories
                            double cals = [workout.totalEnergyBurned doubleValueForUnit:[HKUnit kilocalorieUnit]];
                            NSString *calories = [[NSNumber numberWithDouble:cals] stringValue];

                            entry = [
                                @{
                                        @"duration": @(workout.duration),
                                        HKPluginKeyStartDate: [HealthKit stringFromDate:workout.startDate],
                                        HKPluginKeyEndDate: [HealthKit stringFromDate:workout.endDate],
                                        @"distance": (metersString == nil) ? [NSNull null] : metersString,
                                        @"energy": (calories == nil) ? [NSNull null] : calories,
                                        HKPluginKeySourceBundleId: (source.bundleIdentifier == nil) ? [NSNull null] : source.bundleIdentifier,
                                        HKPluginKeySourceName: (source.name == nil) ? [NSNull null] : source.name,
                                        @"activityType": (workoutActivity == nil) ? [NSNull null] : workoutActivity,
                                        @"statistics": statsDict,
                                        @"UUID": [workout.UUID UUIDString],
                                        HKPluginKeyMetadata: [HealthKit filterDictionaryForJSON:workout.metadata]
                                } mutableCopy
                            ];
                        }  else {
                            entry = [
                                @{
                                        @"duration": @(workout.duration),
                                        HKPluginKeyStartDate: [HealthKit stringFromDate:workout.startDate],
                                        HKPluginKeyEndDate: [HealthKit stringFromDate:workout.endDate],
                                        HKPluginKeySourceBundleId: (source.bundleIdentifier == nil) ? [NSNull null] : source.bundleIdentifier,
                                        HKPluginKeySourceName: (source.name == nil) ? [NSNull null] : source.name,
                                        @"activityType": (workoutActivity == nil) ? [NSNull null] : workoutActivity,
                                        @"statistics": statsDict,
                                        @"UUID": [workout.UUID UUIDString],
                                        HKPluginKeyMetadata: [HealthKit filterDictionaryForJSON:workout.metadata]
                                } mutableCopy
                            ];
                        }

                        [finalResults addObject:entry];
                    }

                    onSuccess(finalResults);
                }
            }];
            [[HealthKit sharedHealthStore] executeQuery:query];
        }
    }];
}
/**
 * Find workout data
 *
 * @param command *CDVInvokedUrlCommand
 */
- (void)findWorkouts:(CDVInvokedUrlCommand *)command {
    // TODO if a specific workouttype was passed, use that
    //  if (false) {
    //    workoutPredicate = [HKQuery predicateForWorkoutsWithWorkoutActivityType:HKWorkoutActivityTypeCycling];
    //  }

    void (^onError)(NSError *error) = ^(NSError *error) {
        [HealthKit executeOnMainThread:^{
            [HealthKit triggerErrorCallbackWithMessage:error.localizedDescription command:command delegate:self.commandDelegate];
        }];
    };

    void (^onSuccess)(NSArray *results) = ^(NSArray *results) {
        [HealthKit executeOnMainThread:^{
            CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:results];
            [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
        }];
    };

    [HealthKit findWorkoutsWithOnError:onError onSuccess:onSuccess];
}

/**
 * Save weight data
 *
 * @param command *CDVInvokedUrlCommand
 */
- (void)saveWeight:(CDVInvokedUrlCommand *)command {
    NSMutableDictionary *args = command.arguments[0];
    NSString *unit = args[HKPluginKeyUnit];
    NSNumber *amount = args[HKPluginKeyAmount];
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:[args[@"date"] doubleValue]];
    BOOL requestReadPermission = (args[@"requestReadPermission"] == nil || [args[@"requestReadPermission"] boolValue]);

    if (amount == nil) {
        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"no amount was set"];
        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
        return;
    }

    HKUnit *preferredUnit = [HealthKit getUnit:unit expected:@"HKMassUnit"];
    if (preferredUnit == nil) {
        [HealthKit triggerErrorCallbackWithMessage:@"invalid unit is passed" command:command delegate:self.commandDelegate];
        return;
    }

    HKQuantityType *weightType = [HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierBodyMass];
    NSSet *requestTypes = [NSSet setWithObjects:weightType, nil];
    __block HealthKit *bSelf = self;
    [[HealthKit sharedHealthStore] requestAuthorizationToShareTypes:requestTypes readTypes:(requestReadPermission ? requestTypes : nil) completion:^(BOOL success, NSError *error) {
        if (success) {
            HKQuantity *weightQuantity = [HKQuantity quantityWithUnit:preferredUnit doubleValue:[amount doubleValue]];
            HKQuantitySample *weightSample = [HKQuantitySample quantitySampleWithType:weightType quantity:weightQuantity startDate:date endDate:date];
            [[HealthKit sharedHealthStore] saveObject:weightSample withCompletion:^(BOOL success_save, NSError *errorInner) {
                if (success_save) {
                    [HealthKit executeOnMainThread:^{
                        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
                        [bSelf.commandDelegate sendPluginResult:result callbackId:command.callbackId];
                    }];
                } else {
                    [HealthKit executeOnMainThread:^{
                        [HealthKit triggerErrorCallbackWithMessage:errorInner.localizedDescription command:command delegate:bSelf.commandDelegate];
                    }];
                }
            }];
        } else {
            [HealthKit executeOnMainThread:^{
                [HealthKit triggerErrorCallbackWithMessage:error.localizedDescription command:command delegate:bSelf.commandDelegate];
            }];
        }
    }];
}

/**
 * Read weight data
 *
 * @param command *CDVInvokedUrlCommand
 */
- (void)readWeight:(CDVInvokedUrlCommand *)command {
    NSDictionary *args = command.arguments[0];
    NSString *unit = args[HKPluginKeyUnit];
    BOOL requestWritePermission = (args[@"requestWritePermission"] == nil || [args[@"requestWritePermission"] boolValue]);

    HKUnit *preferredUnit = [HealthKit getUnit:unit expected:@"HKMassUnit"];
    if (preferredUnit == nil) {
        [HealthKit triggerErrorCallbackWithMessage:@"invalid unit is passed" command:command delegate:self.commandDelegate];
        return;
    }

    // Query to get the user's latest weight, if it exists.
    HKQuantityType *weightType = [HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierBodyMass];
    NSSet *requestTypes = [NSSet setWithObjects:weightType, nil];
    // always ask for read and write permission if the app uses both, because granting read will remove write for the same type :(
    [[HealthKit sharedHealthStore] requestAuthorizationToShareTypes:(requestWritePermission ? requestTypes : nil) readTypes:requestTypes completion:^(BOOL success, NSError *error) {
        __block HealthKit *bSelf = self;
        if (success) {
            [[HealthKit sharedHealthStore] aapl_mostRecentQuantitySampleOfType:weightType predicate:nil completion:^(HKQuantity *mostRecentQuantity, NSDate *mostRecentDate, NSError *errorInner) {
                if (mostRecentQuantity) {
                    double usersWeight = [mostRecentQuantity doubleValueForUnit:preferredUnit];
                    NSMutableDictionary *entry = [
                            @{
                                    HKPluginKeyValue: @(usersWeight),
                                    HKPluginKeyUnit: unit,
                                    @"date": [HealthKit stringFromDate:mostRecentDate]
                            } mutableCopy
                    ];

                    //@TODO formerly dispatch_async
                    [HealthKit executeOnMainThread:^{
                        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:entry];
                        [bSelf.commandDelegate sendPluginResult:result callbackId:command.callbackId];
                    }];
                } else {
                    //@TODO formerly dispatch_async
                    [HealthKit executeOnMainThread:^{
                        NSString *errorDescription = ((errorInner.localizedDescription == nil) ? @"no data" : errorInner.localizedDescription);
                        [HealthKit triggerErrorCallbackWithMessage:errorDescription command:command delegate:bSelf.commandDelegate];
                    }];
                }
            }];
        } else {
            [HealthKit executeOnMainThread:^{
                [HealthKit triggerErrorCallbackWithMessage:error.localizedDescription command:command delegate:bSelf.commandDelegate];
            }];
        }
    }];
}

/**
 * Save height data
 *
 * @param command *CDVInvokedUrlCommand
 */
- (void)saveHeight:(CDVInvokedUrlCommand *)command {
    NSDictionary *args = command.arguments[0];
    NSString *unit = args[HKPluginKeyUnit];
    NSNumber *amount = args[HKPluginKeyAmount];
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:[args[@"date"] doubleValue]];
    BOOL requestReadPermission = (args[@"requestReadPermission"] == nil || [args[@"requestReadPermission"] boolValue]);

    if (amount == nil) {
        [HealthKit triggerErrorCallbackWithMessage:@"no amount is set" command:command delegate:self.commandDelegate];
        return;
    }

    HKUnit *preferredUnit = [HealthKit getUnit:unit expected:@"HKLengthUnit"];
    if (preferredUnit == nil) {
        [HealthKit triggerErrorCallbackWithMessage:@"invalid unit is passed" command:command delegate:self.commandDelegate];
        return;
    }

    HKQuantityType *heightType = [HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierHeight];
    NSSet *requestTypes = [NSSet setWithObjects:heightType, nil];
    [[HealthKit sharedHealthStore] requestAuthorizationToShareTypes:requestTypes readTypes:(requestReadPermission ? requestTypes : nil) completion:^(BOOL success_requestAuth, NSError *error) {
        __block HealthKit *bSelf = self;
        if (success_requestAuth) {
            HKQuantity *heightQuantity = [HKQuantity quantityWithUnit:preferredUnit doubleValue:[amount doubleValue]];
            HKQuantitySample *heightSample = [HKQuantitySample quantitySampleWithType:heightType quantity:heightQuantity startDate:date endDate:date];
            [[HealthKit sharedHealthStore] saveObject:heightSample withCompletion:^(BOOL success_save, NSError *innerError) {
                if (success_save) {
                    [HealthKit executeOnMainThread:^{
                        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
                        [bSelf.commandDelegate sendPluginResult:result callbackId:command.callbackId];
                    }];
                } else {
                    [HealthKit executeOnMainThread:^{
                        [HealthKit triggerErrorCallbackWithMessage:innerError.localizedDescription command:command delegate:bSelf.commandDelegate];
                    }];
                }
            }];
        } else {
            [HealthKit executeOnMainThread:^{
                [HealthKit triggerErrorCallbackWithMessage:error.localizedDescription command:command delegate:bSelf.commandDelegate];
            }];
        }
    }];
}

/**
 * Read height data
 *
 * @param command *CDVInvokedUrlCommand
 */
- (void)readHeight:(CDVInvokedUrlCommand *)command {
    NSDictionary *args = command.arguments[0];
    NSString *unit = args[HKPluginKeyUnit];
    BOOL requestWritePermission = (args[@"requestWritePermission"] == nil || [args[@"requestWritePermission"] boolValue]);

    HKUnit *preferredUnit = [HealthKit getUnit:unit expected:@"HKLengthUnit"];
    if (preferredUnit == nil) {
        [HealthKit triggerErrorCallbackWithMessage:@"invalid unit is passed" command:command delegate:self.commandDelegate];
        return;
    }

    // Query to get the user's latest height, if it exists.
    HKQuantityType *heightType = [HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierHeight];
    NSSet *requestTypes = [NSSet setWithObjects:heightType, nil];
    // always ask for read and write permission if the app uses both, because granting read will remove write for the same type :(
    [[HealthKit sharedHealthStore] requestAuthorizationToShareTypes:(requestWritePermission ? requestTypes : nil) readTypes:requestTypes completion:^(BOOL success, NSError *error) {
        __block HealthKit *bSelf = self;
        if (success) {
            [[HealthKit sharedHealthStore] aapl_mostRecentQuantitySampleOfType:heightType predicate:nil completion:^(HKQuantity *mostRecentQuantity, NSDate *mostRecentDate, NSError *errorInner) { // TODO use
                if (mostRecentQuantity) {
                    double usersHeight = [mostRecentQuantity doubleValueForUnit:preferredUnit];
                    NSMutableDictionary *entry = [
                            @{
                                    HKPluginKeyValue: @(usersHeight),
                                    HKPluginKeyUnit: unit,
                                    @"date": [HealthKit stringFromDate:mostRecentDate]
                            } mutableCopy
                    ];

                    //@TODO formerly dispatch_async
                    [HealthKit executeOnMainThread:^{
                        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:entry];
                        [bSelf.commandDelegate sendPluginResult:result callbackId:command.callbackId];
                    }];
                } else {
                    //@TODO formerly dispatch_async
                    [HealthKit executeOnMainThread:^{
                        NSString *errorDescritption = ((errorInner.localizedDescription == nil) ? @"no data" : errorInner.localizedDescription);
                        [HealthKit triggerErrorCallbackWithMessage:errorDescritption command:command delegate:bSelf.commandDelegate];
                    }];
                }
            }];
        } else {
            [HealthKit executeOnMainThread:^{
                [HealthKit triggerErrorCallbackWithMessage:error.localizedDescription command:command delegate:bSelf.commandDelegate];
            }];
        }
    }];
}

/**
 * Read gender data
 *
 * @param command *CDVInvokedUrlCommand
 */
- (void)readGender:(CDVInvokedUrlCommand *)command {
    HKCharacteristicType *genderType = [HKObjectType characteristicTypeForIdentifier:HKCharacteristicTypeIdentifierBiologicalSex];
    [[HealthKit sharedHealthStore] requestAuthorizationToShareTypes:nil readTypes:[NSSet setWithObjects:genderType, nil] completion:^(BOOL success, NSError *error) {
        __block HealthKit *bSelf = self;
        if (success) {
            HKBiologicalSexObject *sex = [[HealthKit sharedHealthStore] biologicalSexWithError:&error];
            if (sex != nil) {

                NSString *gender = nil;
                switch (sex.biologicalSex) {
                    case HKBiologicalSexMale:
                        gender = @"male";
                        break;
                    case HKBiologicalSexFemale:
                        gender = @"female";
                        break;
                    case HKBiologicalSexOther:
                        gender = @"other";
                        break;
                    default:
                        gender = @"unknown";
                }

                CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:gender];
                [bSelf.commandDelegate sendPluginResult:result callbackId:command.callbackId];
            } else {
                [HealthKit triggerErrorCallbackWithMessage:error.localizedDescription command:command delegate:bSelf.commandDelegate];
            }
        }
    }];
}

/**
 * Read Fitzpatrick Skin Type Data
 *
 * @param command *CDVInvokedUrlCommand
 */
- (void)readFitzpatrickSkinType:(CDVInvokedUrlCommand *)command {
    // fp skintype is available since iOS 9, so we need to check it
    if (![[HealthKit sharedHealthStore] respondsToSelector:@selector(fitzpatrickSkinTypeWithError:)]) {
        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"not available on this device"];
        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
        return;
    }

    HKCharacteristicType *type = [HKObjectType characteristicTypeForIdentifier:HKCharacteristicTypeIdentifierFitzpatrickSkinType];
    [[HealthKit sharedHealthStore] requestAuthorizationToShareTypes:nil readTypes:[NSSet setWithObjects:type, nil] completion:^(BOOL success, NSError *error) {
        __block HealthKit *bSelf = self;
        if (success) {
            HKFitzpatrickSkinTypeObject *skinType = [[HealthKit sharedHealthStore] fitzpatrickSkinTypeWithError:&error];
            if (skinType != nil) {

                NSString *skin = nil;
                switch (skinType.skinType) {
                    case HKFitzpatrickSkinTypeI:
                        skin = @"I";
                        break;
                    case HKFitzpatrickSkinTypeII:
                        skin = @"II";
                        break;
                    case HKFitzpatrickSkinTypeIII:
                        skin = @"III";
                        break;
                    case HKFitzpatrickSkinTypeIV:
                        skin = @"IV";
                        break;
                    case HKFitzpatrickSkinTypeV:
                        skin = @"V";
                        break;
                    case HKFitzpatrickSkinTypeVI:
                        skin = @"VI";
                        break;
                    default:
                        skin = @"unknown";
                }

                CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:skin];
                [bSelf.commandDelegate sendPluginResult:result callbackId:command.callbackId];
            } else {
                [HealthKit triggerErrorCallbackWithMessage:error.localizedDescription command:command delegate:bSelf.commandDelegate];
            }
        }
    }];
}

/**
 * Read blood type data
 *
 * @param command *CDVInvokedUrlCommand
 */
- (void)readBloodType:(CDVInvokedUrlCommand *)command {
    HKCharacteristicType *bloodType = [HKObjectType characteristicTypeForIdentifier:HKCharacteristicTypeIdentifierBloodType];
    [[HealthKit sharedHealthStore] requestAuthorizationToShareTypes:nil readTypes:[NSSet setWithObjects:bloodType, nil] completion:^(BOOL success, NSError *error) {
        __block HealthKit *bSelf = self;
        if (success) {
            HKBloodTypeObject *innerBloodType = [[HealthKit sharedHealthStore] bloodTypeWithError:&error];
            if (innerBloodType != nil) {
                NSString *bt = nil;

                switch (innerBloodType.bloodType) {
                    case HKBloodTypeAPositive:
                        bt = @"A+";
                        break;
                    case HKBloodTypeANegative:
                        bt = @"A-";
                        break;
                    case HKBloodTypeBPositive:
                        bt = @"B+";
                        break;
                    case HKBloodTypeBNegative:
                        bt = @"B-";
                        break;
                    case HKBloodTypeABPositive:
                        bt = @"AB+";
                        break;
                    case HKBloodTypeABNegative:
                        bt = @"AB-";
                        break;
                    case HKBloodTypeOPositive:
                        bt = @"O+";
                        break;
                    case HKBloodTypeONegative:
                        bt = @"O-";
                        break;
                    default:
                        bt = @"unknown";
                }

                CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:bt];
                [bSelf.commandDelegate sendPluginResult:result callbackId:command.callbackId];
            } else {
                [HealthKit triggerErrorCallbackWithMessage:error.localizedDescription command:command delegate:bSelf.commandDelegate];
            }
        }
    }];
}

/**
 * Read date of birth data
 *
 * @param command *CDVInvokedUrlCommand
 */
- (void)readDateOfBirth:(CDVInvokedUrlCommand *)command {
    HKCharacteristicType *birthdayType = [HKObjectType characteristicTypeForIdentifier:HKCharacteristicTypeIdentifierDateOfBirth];
    [[HealthKit sharedHealthStore] requestAuthorizationToShareTypes:nil readTypes:[NSSet setWithObjects:birthdayType, nil] completion:^(BOOL success, NSError *error) {
        __block HealthKit *bSelf = self;
        if (success) {
            NSDate *dateOfBirth = [[HealthKit sharedHealthStore] dateOfBirthWithError:&error];
            if (dateOfBirth) {
                CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:[HealthKit stringFromDate:dateOfBirth]];
                [bSelf.commandDelegate sendPluginResult:result callbackId:command.callbackId];
            } else {
                [HealthKit triggerErrorCallbackWithMessage:error.localizedDescription command:command delegate:bSelf.commandDelegate];
            }
        }
    }];
}

/**
 * Monitor a specified sample type
 *
 * @param command *CDVInvokedUrlCommand
 */
- (void)monitorSampleType:(CDVInvokedUrlCommand *)command {
    NSDictionary *args = command.arguments[0];
    NSString *sampleTypeString = args[HKPluginKeySampleType];
    HKSampleType *type = [HealthKit getHKSampleType:sampleTypeString];
    HKUpdateFrequency updateFrequency = HKUpdateFrequencyImmediate;
    if (type == nil) {
        [HealthKit triggerErrorCallbackWithMessage:@"sampleType was invalid" command:command delegate:self.commandDelegate];
        return;
    }

    // TODO use this an an anchor for an achored query
    //__block int *anchor = 0;
#ifdef HKPLUGIN_DEBUG
    NSLog(@"Setting up ObserverQuery");
#endif

    HKObserverQuery *query;
    query = [[HKObserverQuery alloc] initWithSampleType:type
                                              predicate:nil
                                          updateHandler:^(HKObserverQuery *observerQuery,
                                                  HKObserverQueryCompletionHandler handler,
                                                  NSError *error) {
                                              __block HealthKit *bSelf = self;
                                              if (error) {
                                                  handler();
                                                  [HealthKit executeOnMainThread:^{
                                                      [HealthKit triggerErrorCallbackWithMessage:error.localizedDescription command:command delegate:bSelf.commandDelegate];
                                                  }];
                                              } else {
                                                  handler();
#ifdef HKPLUGIN_DEBUG
                                                  NSLog(@"HealthKit plugin received a monitorSampleType, passing it to JS.");
#endif
                                                  // TODO using a anchored qery to return the new and updated values.
                                                  // Until then use querySampleType({limit=1, ascending="T", endDate=new Date()}) to return the last result

                                                  // Issue #47: commented this block since it resulted in callbacks not being delivered while the app was in the background
                                                  //dispatch_sync(dispatch_get_main_queue(), ^{
                                                  CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:sampleTypeString];
                                                  [result setKeepCallbackAsBool:YES];
                                                  [bSelf.commandDelegate sendPluginResult:result callbackId:command.callbackId];
                                                  //});
                                              }
                                          }];

    // Make sure we get the updated immediately
    [[HealthKit sharedHealthStore] enableBackgroundDeliveryForType:type frequency:updateFrequency withCompletion:^(BOOL success, NSError *error) {
#ifdef HKPLUGIN_DEBUG
        if (success) {
            NSLog(@"Background devliery enabled %@", sampleTypeString);
        } else {
            NSLog(@"Background delivery not enabled for %@ because of %@", sampleTypeString, error);
        }
        NSLog(@"Executing ObserverQuery");
#endif
        [[HealthKit sharedHealthStore] executeQuery:query];
        // TODO provide some kind of callback to stop monitoring this value, store the query in some kind of WeakHashSet equilavent?
    }];
};

/**
 * Get the sum of a specified quantity type
 *
 * @param command *CDVInvokedUrlCommand
 */
- (void)sumQuantityType:(CDVInvokedUrlCommand *)command {
    NSDictionary *args = command.arguments[0];

    NSDate *startDate = [NSDate dateWithTimeIntervalSince1970:[args[HKPluginKeyStartDate] longValue]];
    NSDate *endDate = [NSDate dateWithTimeIntervalSince1970:[args[HKPluginKeyEndDate] longValue]];
    NSString *sampleTypeString = args[HKPluginKeySampleType];
    NSString *unitString = args[HKPluginKeyUnit];
    HKQuantityType *type = [HKObjectType quantityTypeForIdentifier:sampleTypeString];


    if (type == nil) {
        [HealthKit triggerErrorCallbackWithMessage:@"sampleType was invalid" command:command delegate:self.commandDelegate];
        return;
    }

    NSPredicate *predicate = [HKQuery predicateForSamplesWithStartDate:startDate endDate:endDate options:HKQueryOptionStrictStartDate];
    HKStatisticsOptions sumOptions = HKStatisticsOptionCumulativeSum;
    HKStatisticsQuery *query;
    HKUnit *unit = ((unitString != nil) ? [HKUnit unitFromString:unitString] : [HKUnit countUnit]);
    query = [[HKStatisticsQuery alloc] initWithQuantityType:type
                                    quantitySamplePredicate:predicate
                                                    options:sumOptions
                                          completionHandler:^(HKStatisticsQuery *statisticsQuery,
                                                  HKStatistics *result,
                                                  NSError *error) {
                                              HKQuantity *sum = [result sumQuantity];
                                              CDVPluginResult *response = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDouble:[sum doubleValueForUnit:unit]];
                                              [self.commandDelegate sendPluginResult:response callbackId:command.callbackId];
                                          }];

    [[HealthKit sharedHealthStore] executeQuery:query];
}

+ (void)queryLooseMacros:(NSDate *)startDate endDate:(NSDate *)endDate remainingMacros:(NSMutableArray *)remainingMacros currentResult:(NSMutableDictionary *)currentResult excludeSources:(NSArray *)excludeSources onComplete:(void(^)(NSMutableArray *results))onComplete onError:(void(^)(NSString *errorMsg))onError {
    
    NSString *sampleTypeString = remainingMacros[0];
    NSString *jsTypeString = HKNutritionTypeToSimplified[sampleTypeString];
    [remainingMacros removeObjectAtIndex:0];
    
    NSString *unitString = HKSampleTypeToUnit[sampleTypeString];
    
    NSPredicate *sourcePredicate = [HKQuery predicateForObjectsFromSources:[NSSet setWithArray:excludeSources]];
    NSPredicate *extraPredicate = [NSCompoundPredicate notPredicateWithSubpredicate:sourcePredicate];
    
    void (^onErrorMsg)(NSString *errorMsg) = ^(NSString *errorMsg) {
        onError(errorMsg);
    };

    void (^onSuccess)(NSArray *results) = ^(NSArray *results) {
        for (NSMutableDictionary *result in results) {
            NSMutableDictionary *newVals = [@{ jsTypeString: result[@"quantity"] } mutableCopy];
            if(currentResult[result[@"startDate"]]) {
                [currentResult[result[@"startDate"]] addEntriesFromDictionary:newVals];
            } else {
                currentResult[result[@"startDate"]] = newVals;
            }
        }
        
        if ([remainingMacros count] > 0) {
            [self queryLooseMacros:startDate endDate:endDate remainingMacros:remainingMacros currentResult:currentResult excludeSources:excludeSources onComplete:onComplete onError:onError];
        } else {
            NSMutableArray *finalResult = [NSMutableArray new];

            for (NSString *startDateStr in currentResult) {
                NSMutableDictionary *value = currentResult[startDateStr];
                                
                if(value[@"calories"]) {
                    int cals = [value[@"calories"] intValue];
                    if(cals > 0) {
                        NSMutableDictionary *finalValue = [@{} mutableCopy];
                        [finalValue setObject:value forKey:@"macros"];
                        [finalValue setObject:startDateStr forKey:@"startDate"];
                        [finalValue setObject:@"aggregated" forKey:@"sourceBundleId"];

                        [finalResult addObject:finalValue];
                    }
                }
            }
            onComplete(finalResult);
        }
    };

    [self querySampleTypeAggregatedCore:startDate
                                endDate:endDate
                       sampleTypeString:sampleTypeString
                             unitString:unitString
                            aggregation:@"day"
                         extraPredicate:extraPredicate
                     filterOutUserInput:NO
                              onSuccess:onSuccess
                                onError:onErrorMsg
    ];
    
}

+ (void)queryObservedSamples:(NSMutableArray *)observedSampleTypes currentResults:(NSMutableDictionary *)currentResults onComplete:(void(^)(NSMutableDictionary *results))onComplete onError:(void(^)(NSString *errorMsg))onError {
    
    if ([observedSampleTypes count] == 0) {
        onComplete(currentResults);
        return;
    }
    
    NSString *sampleTypeString = observedSampleTypes[0];
    NSString *jsTypeString = HKSampleTypeToJSType[sampleTypeString];
    [observedSampleTypes removeObjectAtIndex:0];

    NSDate *now = [NSDate date];
    NSDate *startDate = [NSDate dateWithTimeIntervalSinceNow: -96*60*60];
    NSCalendar *calendar = [NSCalendar currentCalendar];
    startDate = [calendar startOfDayForDate:startDate];

    NSDate *startOfNextDay = [calendar dateByAddingUnit:NSCalendarUnitDay value:1 toDate:now options:0];
    NSDate *endDate = [startOfNextDay dateByAddingTimeInterval:-1];

    void (^onErrorObj)(NSError *error) = ^(NSError *error) {
        onError(error.localizedDescription);
    };
    
    void (^onErrorMsg)(NSString *errorMsg) = ^(NSString *errorMsg) {
        onError(errorMsg);
    };

    void (^onSuccess)(NSArray *results) = ^(NSArray *results) {
        currentResults[jsTypeString] = results;
        
        if ([observedSampleTypes count] > 0) {
            [self queryObservedSamples:observedSampleTypes currentResults:currentResults onComplete:onComplete onError:onError];
        } else {
            onComplete(currentResults);
        }
    };
    
    void (^onSuccessMacros)(NSArray *results) = ^(NSArray *results) {
        void (^onSuccessAggMacs)(NSArray *aggResults) = ^(NSArray *aggResults) {
            for(NSMutableDictionary *result in results) {
                [result removeObjectForKey:@"source"];
            }
            NSArray *finalResults = [results arrayByAddingObjectsFromArray:aggResults];
            onSuccess(finalResults);
        };
        
        NSMutableArray *sources = [[NSMutableArray alloc] init];
        
        for (NSDictionary *dict in results) {
            if(dict[@"source"]) {
                [sources addObject:[dict objectForKey:@"source"]];
            }
        }
        
        [self queryLooseMacros:startDate endDate:endDate remainingMacros:[[HKNutritionTypeToSimplified allKeys] mutableCopy] currentResult:[@{} mutableCopy] excludeSources:sources onComplete:onSuccessAggMacs onError:onError];
    };

    if ([sampleTypeString isEqual:@"HKWorkoutTypeIdentifier"]) {
        [self findWorkoutsWithOnError:onErrorObj onSuccess:onSuccess];
    } else {
        NSString *unitString = HKSampleTypeToUnit[sampleTypeString];
        HKSampleType *type = [HealthKit getHKSampleType:sampleTypeString];

        if ([type isKindOfClass:[HKQuantityType class]] && ![jsTypeString isEqualToString:@"weight"]) {
            [self querySampleTypeAggregatedCore:startDate
                                        endDate:endDate
                               sampleTypeString:sampleTypeString
                                     unitString:unitString
                                    aggregation:@"day"
                                 extraPredicate:nil
                             filterOutUserInput:NO
                                      onSuccess:onSuccess
                                        onError:onErrorMsg
            ];
        } else {
            [self querySampleTypeCoreWithStartDate:startDate
                                      endDate:endDate
                             sampleTypeString:sampleTypeString
                                   unitString:unitString
                                        limit:1000
                                    ascending:NO
                                     returnSources:[sampleTypeString isEqualToString:HKCorrelationTypeIdentifierFood]
                           filterOutUserInput:NO
                                      onError:onErrorObj
                                         onSuccess:([sampleTypeString isEqualToString:HKCorrelationTypeIdentifierFood] ? onSuccessMacros : onSuccess)
            ];
        }
    }
    
}

/**
 * Query a specified sample type
 *
 * @param command *CDVInvokedUrlCommand
 */
+ (void)querySampleTypeCoreWithStartDate:(NSDate *)startDate endDate:(NSDate *)endDate sampleTypeString:(NSString *)sampleTypeString unitString:(NSString *)unitString limit:(NSUInteger)limit ascending:(BOOL)ascending returnSources:(BOOL)returnSources filterOutUserInput:(BOOL)filterOutUserInput onError:(void(^)(NSError *error))onError onSuccess:(void(^)(NSArray *results))onSuccess {

    HKSampleType *type = [HealthKit getHKSampleType:sampleTypeString];
    HKSampleType *requestType = [HealthKit getHKSampleType:sampleTypeString];
    if (type == nil) {
        onError([NSError errorWithDomain:@"healthkit.cordova.plugin" code:1001 userInfo:@{NSLocalizedDescriptionKey: @"sampleType was invalid"}]);
        return;
    } else if ([type.identifier isEqualToString:HKCorrelationTypeIdentifierFood]) {
        requestType = [HealthKit getHKSampleType:HKQuantityTypeIdentifierDietaryEnergyConsumed];
    }
    
    HKUnit *unit = nil;
    if (unitString != nil) {
        if ([unitString isEqualToString:@"mmol/L"]) {
            // @see https://stackoverflow.com/a/30196642/1214598
            unit = [[HKUnit moleUnitWithMetricPrefix:HKMetricPrefixMilli molarMass:HKUnitMolarMassBloodGlucose] unitDividedByUnit:[HKUnit literUnit]];
        } else {
            // issue 51
            // @see https://github.com/Telerik-Verified-Plugins/HealthKit/issues/51
            if ([unitString isEqualToString:@"percent"]) {
                unitString = @"%";
            }
            unit = [HKUnit unitFromString:unitString];
        }
    }

    // TODO check that unit is compatible with sampleType if sample type of HKQuantityType
    NSPredicate *predicate1 = [HKQuery predicateForSamplesWithStartDate:startDate endDate:endDate options:HKQueryOptionStrictStartDate];
    NSPredicate *predicate2 = nil;

    if (filterOutUserInput) {
        predicate2 = [NSPredicate predicateWithFormat:@"metadata.%K != YES", HKMetadataKeyWasUserEntered];
    }

    // only include the user input predicate if it is not nil
    NSArray *predicates = predicate2 != nil ? @[predicate1, predicate2] : @[predicate1];

    NSCompoundPredicate *compoundPredicate = [NSCompoundPredicate andPredicateWithSubpredicates:predicates];

    NSSet *requestTypes = [NSSet setWithObjects:requestType, nil];
    [[HealthKit sharedHealthStore] requestAuthorizationToShareTypes:nil readTypes:requestTypes completion:^(BOOL success, NSError *error) {
        __block HealthKit *bSelf = self;
        if (success) {
            NSString *endKey = HKSampleSortIdentifierEndDate;
            NSSortDescriptor *endDateSort = [NSSortDescriptor sortDescriptorWithKey:endKey ascending:ascending];
            HKSampleQuery *query = [[HKSampleQuery alloc] initWithSampleType:type
                                                                   predicate:compoundPredicate
                                                                       limit:limit
                                                             sortDescriptors:@[endDateSort]
                                                              resultsHandler:^(HKSampleQuery *sampleQuery,
                                                                      NSArray *results,
                                                                      NSError *innerError) {
                                                                  if (innerError != nil) {
                                                                      onError(innerError);
                                                                  } else {
                                                                      NSMutableArray *finalResults = [[NSMutableArray alloc] initWithCapacity:results.count];

                                                                      for (HKSample *sample in results) {

                                                                          NSDate *startSample = sample.startDate;
                                                                          NSDate *endSample = sample.endDate;
                                                                          NSMutableDictionary *entry = [NSMutableDictionary dictionary];

                                                                          // common indices
                                                                          entry[HKPluginKeyStartDate] =[HealthKit stringFromDate:startSample];
                                                                          entry[HKPluginKeyEndDate] = [HealthKit stringFromDate:endSample];
                                                                          entry[HKPluginKeyUUID] = sample.UUID.UUIDString;

                                                                          if ([sample respondsToSelector:@selector(sourceRevision)]) {
                                                                              HKSource *source = [[sample valueForKey:@"sourceRevision"] valueForKey:@"source"];
                                                                              entry[HKPluginKeySourceName] = source.name;
                                                                              entry[HKPluginKeySourceBundleId] = source.bundleIdentifier;
                                                                              if(returnSources) {
                                                                                  entry[@"source"] = source;
                                                                              }
                                                                          } else {
                                                                                //@TODO Update deprecated API call
                                                                                entry[HKPluginKeySourceName] = sample.source.name;
                                                                                entry[HKPluginKeySourceBundleId] = sample.source.bundleIdentifier;
                                                                                if(returnSources) {
                                                                                    entry[@"source"] = sample.source;
                                                                                }
                                                                            }

                                                                          if (sample.metadata == nil || ![NSJSONSerialization isValidJSONObject:sample.metadata]) {
                                                                              entry[HKPluginKeyMetadata] = @{};
                                                                          } else {
                                                                              entry[HKPluginKeyMetadata] = sample.metadata;
                                                                          }

                                                                          // case-specific indices
                                                                          if ([sample isKindOfClass:[HKCategorySample class]]) {

                                                                              HKCategorySample *csample = (HKCategorySample *) sample;
                                                                              entry[HKPluginKeyValue] = @(csample.value);
                                                                              entry[@"categoryType.identifier"] = csample.categoryType.identifier;
                                                                              entry[@"categoryType.description"] = csample.categoryType.description;

                                                                          } else if ([sample isKindOfClass:[HKCorrelation class]]) {
                                                                              
                                                                              HKCorrelation *correlation = (HKCorrelation *)sample;
                                                                              entry[HKPluginKeyCorrelationType] = correlation.correlationType.identifier;
                                                                              
                                                                              if([correlation.correlationType.identifier isEqualToString:HKCorrelationTypeIdentifierFood]) {
                                                                                  entry[@"macros"] = [HealthKit extractNutritionInfoFromFoodCorrelation:correlation];
                                                                              }

                                                                          } else if ([sample isKindOfClass:[HKCorrelationType class]]) {

                                                                              HKCorrelation *correlation = (HKCorrelation *) sample;
                                                                              entry[HKPluginKeyCorrelationType] = correlation.correlationType.identifier;
                                                                              
                                                                              if([correlation.correlationType.identifier isEqualToString:HKCorrelationTypeIdentifierFood]) {
                                                                                  entry[@"macros"] = [HealthKit extractNutritionInfoFromFoodCorrelation:correlation];
                                                                              }

                                                                          } else if ([sample isKindOfClass:[HKQuantitySample class]]) {

                                                                              HKQuantitySample *qsample = (HKQuantitySample *) sample;
                                                                              [entry setValue:@([qsample.quantity doubleValueForUnit:unit]) forKey:@"quantity"];

                                                                          } else if ([sample isKindOfClass:[HKWorkout class]]) {

                                                                              HKWorkout *wsample = (HKWorkout *) sample;
                                                                              [entry setValue:@(wsample.duration) forKey:@"duration"];
                                                                              [entry setValue:@(wsample.workoutActivityType) forKey:@"activityType"];

                                                                          }

                                                                          [finalResults addObject:entry];
                                                                      }

                                                                      onSuccess(finalResults);
                                                                  }
                                                              }];

            [[HealthKit sharedHealthStore] executeQuery:query];
        } else {
            onError(error);
        }
    }];
}

- (void)querySampleType:(CDVInvokedUrlCommand *)command {
    NSDictionary *args = command.arguments[0];
    NSDate *startDate = [NSDate dateWithTimeIntervalSince1970:[args[HKPluginKeyStartDate] longValue]];
    NSDate *endDate = [NSDate dateWithTimeIntervalSince1970:[args[HKPluginKeyEndDate] longValue]];
    NSString *sampleTypeString = args[HKPluginKeySampleType];
    NSString *unitString = args[HKPluginKeyUnit];
    NSUInteger limit = ((args[@"limit"] != nil) ? [args[@"limit"] unsignedIntegerValue] : 1000);
    BOOL ascending = (args[@"ascending"] != nil && [args[@"ascending"] boolValue]);
    BOOL filterOutUserInput = (args[@"filterOutUserInput"] != nil && [args[@"filterOutUserInput"] boolValue]);

    void (^onError)(NSError *error) = ^(NSError *error) {
        [HealthKit executeOnMainThread:^{
            [HealthKit triggerErrorCallbackWithMessage:error.localizedDescription command:command delegate:self.commandDelegate];
        }];
    };

    void (^onSuccess)(NSArray *results) = ^(NSArray *results) {
        [HealthKit executeOnMainThread:^{
            CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:results];
            [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
        }];
    };

    [HealthKit querySampleTypeCoreWithStartDate:startDate endDate:endDate sampleTypeString:sampleTypeString unitString:unitString limit:limit ascending:ascending returnSources:NO filterOutUserInput:filterOutUserInput onError:onError onSuccess:onSuccess];
}

/**
 * Query a specified sample type using an aggregation
 *
 * @param command *CDVInvokedUrlCommand
 */
+ (void)querySampleTypeAggregatedCore:(NSDate *)startDate endDate:(NSDate *)endDate sampleTypeString:(NSString *)sampleTypeString unitString:(NSString *)unitString aggregation:(NSString *)aggregation extraPredicate:(NSPredicate *)extraPredicate filterOutUserInput:(BOOL)filterOutUserInput onSuccess:(void (^)(NSArray *))onSuccess onError:(void (^)(NSString *))onError {
    
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDateComponents *interval = [[NSDateComponents alloc] init];
    
    // TODO would be nice to also have the dev pass in the nr of hours/days/..
    if ([@"minute" isEqualToString:aggregation]) {
        interval.minute = 1;
    } else if ([@"fiveminutes" isEqualToString:aggregation]) {
        interval.minute = 5;
    } else if ([@"hour" isEqualToString:aggregation]) {
        interval.hour = 1;
    } else if ([@"week" isEqualToString:aggregation]) {
        interval.day = 7;
    } else if ([@"month" isEqualToString:aggregation]) {
        interval.month = 1;
    } else if ([@"year" isEqualToString:aggregation]) {
        interval.year = 1;
    } else {
        // default 'day'
        interval.day = 1;
    }

    NSDateComponents *anchorComponents = [calendar components:NSCalendarUnitDay | NSCalendarUnitMonth | NSCalendarUnitYear
                                                     fromDate:endDate]; //[NSDate date]];
    anchorComponents.hour = 0; //at 00:00 AM
    NSDate *anchorDate = [calendar dateFromComponents:anchorComponents];
    HKQuantityType *quantityType = [HKObjectType quantityTypeForIdentifier:sampleTypeString];

    HKStatisticsOptions statOpt = HKStatisticsOptionNone;

    if (quantityType == nil) {
        onError(@"sampleType is invalid");
        return;
    } else if ([sampleTypeString isEqualToString:@"HKQuantityTypeIdentifierHeartRate"]) {
        statOpt = HKStatisticsOptionDiscreteAverage;

    } else { //HKQuantityTypeIdentifierStepCount, etc...
        statOpt = HKStatisticsOptionCumulativeSum;
    }

    HKUnit *unit = nil;
    if (unitString != nil) {
        // issue 51
        // @see https://github.com/Telerik-Verified-Plugins/HealthKit/issues/51
        if ([unitString isEqualToString:@"percent"]) {
            unitString = @"%";
        }
        unit = [HKUnit unitFromString:unitString];
    }

    HKSampleType *type = [HealthKit getHKSampleType:sampleTypeString];
    if (type == nil) {
        onError(@"sampleType is invalid");
        return;
    }

    NSPredicate *predicate1 = [HKQuery predicateForSamplesWithStartDate:startDate endDate:endDate options:HKQueryOptionStrictStartDate];
    NSPredicate *predicate2 = nil;

    if (filterOutUserInput) {
        predicate2 = [NSPredicate predicateWithFormat:@"metadata.%K != YES", HKMetadataKeyWasUserEntered];
    }

    // only include the user input predicate if it is not nil
    NSMutableArray *predicates = [@[predicate1] mutableCopy];
    if(predicate2) {
        [predicates addObject:predicate2];
    }
    
    if(extraPredicate) {
        [predicates addObject:extraPredicate];
    }

    NSCompoundPredicate *compoundPredicate = [NSCompoundPredicate andPredicateWithSubpredicates:predicates];

    NSSet *requestTypes = [NSSet setWithObjects:type, nil];
    [[HealthKit sharedHealthStore] requestAuthorizationToShareTypes:nil readTypes:requestTypes completion:^(BOOL success, NSError *error) {
        __block HealthKit *bSelf = self;
        if (success) {
            HKStatisticsCollectionQuery *query = [[HKStatisticsCollectionQuery alloc] initWithQuantityType:quantityType
                                                                                   quantitySamplePredicate:compoundPredicate
                                                                                                   options:statOpt
                                                                                                anchorDate:anchorDate
                                                                                        intervalComponents:interval];

            // Set the results handler
            query.initialResultsHandler = ^(HKStatisticsCollectionQuery *statisticsCollectionQuery, HKStatisticsCollection *results, NSError *innerError) {
                if (innerError) {
                    // Perform proper error handling here
                    //                    NSLog(@"*** An error occurred while calculating the statistics: %@ ***",error.localizedDescription);
                    onError(innerError.localizedDescription);
                } else {
                    // Get the daily steps over the past n days
                    //            HKUnit *unit = unitString!=nil ? [HKUnit unitFromString:unitString] : [HKUnit countUnit];
                    NSMutableArray *finalResults = [[NSMutableArray alloc] initWithCapacity:[[results statistics] count]];

                    [results enumerateStatisticsFromDate:startDate
                                                  toDate:endDate
                                               withBlock:^(HKStatistics *result, BOOL *stop) {

                                                   NSDate *valueStartDate = result.startDate;
                                                   NSDate *valueEndDate = result.endDate;

                                                   NSMutableDictionary *entry = [NSMutableDictionary dictionary];
                                                   entry[HKPluginKeyStartDate] = [HealthKit stringFromDate:valueStartDate];
                                                   entry[HKPluginKeyEndDate] = [HealthKit stringFromDate:valueEndDate];

                                                   HKQuantity *quantity = nil;
                                                   switch (statOpt) {
                                                       case HKStatisticsOptionDiscreteAverage:
                                                           quantity = result.averageQuantity;
                                                           break;
                                                       case HKStatisticsOptionCumulativeSum:
                                                           quantity = result.sumQuantity;
                                                           break;
                                                       case HKStatisticsOptionDiscreteMin:
                                                           quantity = result.minimumQuantity;
                                                           break;
                                                       case HKStatisticsOptionDiscreteMax:
                                                           quantity = result.maximumQuantity;
                                                           break;

                                                           // @TODO return appropriate values here
                                                       case HKStatisticsOptionSeparateBySource:
                                                       case HKStatisticsOptionNone:
                                                       default:
                                                           break;
                                                   }

                                                   double value = [quantity doubleValueForUnit:unit];
                                                   entry[@"quantity"] = @(value);
                                                   [finalResults addObject:entry];
                                               }];

                    onSuccess(finalResults);
                }
            };

            [[HealthKit sharedHealthStore] executeQuery:query];

        } else {
            onError(error.localizedDescription);
        }
    }];


}

- (void)querySampleTypeAggregated:(CDVInvokedUrlCommand *)command {
    NSDictionary *args = command.arguments[0];
    NSDate *startDate = [NSDate dateWithTimeIntervalSince1970:[args[HKPluginKeyStartDate] longValue]];
    NSDate *endDate = [NSDate dateWithTimeIntervalSince1970:[args[HKPluginKeyEndDate] longValue]];
    
    NSString *sampleTypeString = args[HKPluginKeySampleType];
    NSString *unitString = args[HKPluginKeyUnit];
    NSString *aggregation = args[HKPluginKeyAggregation];
    
    BOOL filterOutUserInput = (args[@"filterOutUserInput"] != nil && [args[@"filterOutUserInput"] boolValue]);
    
    [HealthKit querySampleTypeAggregatedCore:startDate endDate:endDate sampleTypeString:sampleTypeString unitString:unitString aggregation:aggregation extraPredicate:nil filterOutUserInput:filterOutUserInput onSuccess:^(NSArray *finalResults) {
        [HealthKit executeOnMainThread:^{
            CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:finalResults];
            [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
        }];
    } onError:^(NSString *error) {
        [HealthKit executeOnMainThread:^{
            [HealthKit triggerErrorCallbackWithMessage:error command:command delegate:self.commandDelegate];
        }];
    }];
}

/**
 * Query a specified correlation type
 *
 * @param command *CDVInvokedUrlCommand
 */
- (void)queryCorrelationType:(CDVInvokedUrlCommand *)command {
    NSDictionary *args = command.arguments[0];
    NSDate *startDate = [NSDate dateWithTimeIntervalSince1970:[args[HKPluginKeyStartDate] longValue]];
    NSDate *endDate = [NSDate dateWithTimeIntervalSince1970:[args[HKPluginKeyEndDate] longValue]];
    NSString *correlationTypeString = args[HKPluginKeyCorrelationType];
    NSArray<NSString *> *unitsString = args[HKPluginKeyUnits];

    HKCorrelationType *type = (HKCorrelationType *) [HealthKit getHKSampleType:correlationTypeString];
    if (type == nil) {
        [HealthKit triggerErrorCallbackWithMessage:@"sampleType is invalid" command:command delegate:self.commandDelegate];
        return;
    }
    NSMutableArray *units = [[NSMutableArray alloc] init];
    for (NSString *unitString in unitsString) {
        HKUnit *unit = ((unitString != nil) ? [HKUnit unitFromString:unitString] : nil);
        [units addObject:unit];
    }

    // TODO check that unit is compatible with sampleType if sample type of HKQuantityType
    NSPredicate *predicate = [HKQuery predicateForSamplesWithStartDate:startDate endDate:endDate options:HKQueryOptionStrictStartDate];

    HKCorrelationQuery *query = [[HKCorrelationQuery alloc] initWithType:type predicate:predicate samplePredicates:nil completion:^(HKCorrelationQuery *correlationQuery, NSArray *correlations, NSError *error) {
        __block HealthKit *bSelf = self;
        if (error) {
            [HealthKit executeOnMainThread:^{
                [HealthKit triggerErrorCallbackWithMessage:error.localizedDescription command:command delegate:bSelf.commandDelegate];
            }];
        } else {
            NSMutableArray *finalResults = [[NSMutableArray alloc] initWithCapacity:correlations.count];
            for (HKSample *sample in correlations) {
                NSDate *startSample = sample.startDate;
                NSDate *endSample = sample.endDate;

                NSMutableDictionary *entry = [NSMutableDictionary dictionary];
                entry[HKPluginKeyStartDate] = [HealthKit stringFromDate:startSample];
                entry[HKPluginKeyEndDate] = [HealthKit stringFromDate:endSample];

                // common indices
                entry[HKPluginKeyUUID] = sample.UUID.UUIDString;
                entry[HKPluginKeySourceName] = sample.source.name;
                entry[HKPluginKeySourceBundleId] = sample.source.bundleIdentifier;
                if (sample.metadata == nil || ![NSJSONSerialization isValidJSONObject:sample.metadata]) {
                    entry[HKPluginKeyMetadata] = @{};
                } else {
                    entry[HKPluginKeyMetadata] = sample.metadata;
                }


                if ([sample isKindOfClass:[HKCategorySample class]]) {

                    HKCategorySample *csample = (HKCategorySample *) sample;
                    entry[HKPluginKeyValue] = @(csample.value);
                    entry[@"categoryType.identifier"] = csample.categoryType.identifier;
                    entry[@"categoryType.description"] = csample.categoryType.description;

                } else if ([sample isKindOfClass:[HKCorrelation class]]) {

                    HKCorrelation *correlation = (HKCorrelation *) sample;
                    entry[HKPluginKeyCorrelationType] = correlation.correlationType.identifier;

                    NSMutableArray *samples = [NSMutableArray arrayWithCapacity:correlation.objects.count];
                    for (HKQuantitySample *quantitySample in correlation.objects) {
                        for (int i=0; i<[units count]; i++) {
                            HKUnit *unit = units[i];
                            NSString *unitS = unitsString[i];
                            if ([quantitySample.quantity isCompatibleWithUnit:unit]) {
                                [samples addObject:@{
                                                     HKPluginKeyStartDate: [HealthKit stringFromDate:quantitySample.startDate],
                                                     HKPluginKeyEndDate: [HealthKit stringFromDate:quantitySample.endDate],
                                                     HKPluginKeySampleType: quantitySample.sampleType.identifier,
                                                     HKPluginKeyValue: @([quantitySample.quantity doubleValueForUnit:unit]),
                                                     HKPluginKeyUnit: unitS,
                                                     HKPluginKeyMetadata: (quantitySample.metadata == nil || ![NSJSONSerialization isValidJSONObject:quantitySample.metadata]) ? @{} : quantitySample.metadata,
                                                     HKPluginKeyUUID: quantitySample.UUID.UUIDString
                                                     }
                                 ];
                                break;
                            }
                        }
                    }
                    entry[HKPluginKeyObjects] = samples;

                } else if ([sample isKindOfClass:[HKQuantitySample class]]) {

                    HKQuantitySample *qsample = (HKQuantitySample *) sample;
                    for (int i=0; i<[units count]; i++) {
                        HKUnit *unit = units[i];
                        if ([qsample.quantity isCompatibleWithUnit:unit]) {
                            double quantity = [qsample.quantity doubleValueForUnit:unit];
                            entry[@"quantity"] = [NSString stringWithFormat:@"%f", quantity];
                            break;
                        }
                    }

                } else if ([sample isKindOfClass:[HKWorkout class]]) {

                    HKWorkout *wsample = (HKWorkout *) sample;
                    entry[@"duration"] = @(wsample.duration);

                } else if ([sample isKindOfClass:[HKCorrelationType class]]) {
                    // TODO
                    // wat do?
                }

                [finalResults addObject:entry];
            }

            [HealthKit executeOnMainThread:^{
                CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:finalResults];
                [bSelf.commandDelegate sendPluginResult:result callbackId:command.callbackId];
            }];
        }
    }];
    [[HealthKit sharedHealthStore] executeQuery:query];
}

/**
 * Save sample data
 *
 * @param command *CDVInvokedUrlCommand
 */
- (void)saveSample:(CDVInvokedUrlCommand *)command {
    NSDictionary *args = command.arguments[0];

    //Use helper method to create quantity sample
    NSError *error = nil;
    HKSample *sample = [self loadHKSampleFromInputDictionary:args error:&error];

    //If error in creation, return plugin result
    if (error) {
        [HealthKit triggerErrorCallbackWithMessage:error.localizedDescription command:command delegate:self.commandDelegate];
        return;
    }

    //Otherwise save to health store
    [[HealthKit sharedHealthStore] saveObject:sample withCompletion:^(BOOL success, NSError *innerError) {
        __block HealthKit *bSelf = self;
        if (success) {
            [HealthKit executeOnMainThread:^{
                CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
                [bSelf.commandDelegate sendPluginResult:result callbackId:command.callbackId];
            }];
        } else {
            [HealthKit executeOnMainThread:^{
                [HealthKit triggerErrorCallbackWithMessage:innerError.localizedDescription command:command delegate:bSelf.commandDelegate];
            }];
        }
    }];

}

/**
 * Save correlation data
 *
 * @param command *CDVInvokedUrlCommand
 */
- (void)saveCorrelation:(CDVInvokedUrlCommand *)command {
    NSDictionary *args = command.arguments[0];
    NSError *error = nil;

    //Use helper method to create correlation
    HKCorrelation *correlation = [self loadHKCorrelationFromInputDictionary:args error:&error];

    //If error in creation, return plugin result
    if (error) {
        [HealthKit triggerErrorCallbackWithMessage:error.localizedDescription command:command delegate:self.commandDelegate];
        return;
    }

    //Otherwise save to health store
    [[HealthKit sharedHealthStore] saveObject:correlation withCompletion:^(BOOL success, NSError *saveError) {
        __block HealthKit *bSelf = self;
        if (success) {
            [HealthKit executeOnMainThread:^{
                CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:correlation.UUID.UUIDString];
                [bSelf.commandDelegate sendPluginResult:result callbackId:command.callbackId];
            }];
        } else {
            [HealthKit executeOnMainThread:^{
                [HealthKit triggerErrorCallbackWithMessage:saveError.localizedDescription command:command delegate:bSelf.commandDelegate];
            }];
        }
    }];
}

- (void)deleteObjectById:(CDVInvokedUrlCommand *)command {
    NSDictionary *args = command.arguments[0];
    NSString *idString = args[@"id"];
    NSString *objectType = args[@"type"];
    __block HealthKit *bSelf = self;
    NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:idString];
    
    if (uuid == nil) {
        [HealthKit executeOnMainThread:^{
            [HealthKit triggerErrorCallbackWithMessage:@"Invalid UUID string" command:command delegate:bSelf.commandDelegate];
        }];
        return;
    }
    
    HKSampleType *type = [HKObjectType workoutType];
    if([objectType isEqualToString:@"food"]) {
        type = [HKCorrelationType correlationTypeForIdentifier:HKCorrelationTypeIdentifierFood];
    }
    NSPredicate *predicate = [HKQuery predicateForObjectWithUUID:uuid];
    
    HKSampleQuery *query = [[HKSampleQuery alloc] initWithSampleType:type predicate:predicate limit:1 sortDescriptors:nil resultsHandler:^(HKSampleQuery * _Nonnull query, NSArray<__kindof HKSample *> * _Nullable results, NSError * _Nullable error) {
        
        if (!results.count) {
            [HealthKit executeOnMainThread:^{
                [HealthKit triggerErrorCallbackWithMessage:@"No object with that ID found to delete" command:command delegate:bSelf.commandDelegate];
            }];
            return;
        }
        
        HKObject *objectToDelete = results[0];
        
        [[HealthKit sharedHealthStore] deleteObject:objectToDelete withCompletion:^(BOOL success, NSError * _Nullable error) {
            if (success) {
                [HealthKit executeOnMainThread:^{
                    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
                    [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
                }];
            } else {
                [HealthKit executeOnMainThread:^{
                    [HealthKit triggerErrorCallbackWithMessage:error.localizedDescription command:command delegate:bSelf.commandDelegate];
                }];
            }
        }];
    }];
    
    [[HealthKit sharedHealthStore] executeQuery:query];
}

/**
 * Delete matching samples from the HealthKit store.
 * See https://developer.apple.com/library/ios/documentation/HealthKit/Reference/HKHealthStore_Class/#//apple_ref/occ/instm/HKHealthStore/deleteObject:withCompletion:
 *
 * @param command *CDVInvokedUrlCommand
 */
- (void)deleteSamples:(CDVInvokedUrlCommand *)command {
  NSDictionary *args = command.arguments[0];
  NSDate *startDate = [NSDate dateWithTimeIntervalSince1970:[args[HKPluginKeyStartDate] longValue]];
  NSDate *endDate = [NSDate dateWithTimeIntervalSince1970:[args[HKPluginKeyEndDate] longValue]];
  NSString *sampleTypeString = args[HKPluginKeySampleType];

  HKSampleType *type = [HealthKit getHKSampleType:sampleTypeString];
  if (type == nil) {
    [HealthKit triggerErrorCallbackWithMessage:@"sampleType is invalid" command:command delegate:self.commandDelegate];
    return;
  }

  NSPredicate *predicate = [HKQuery predicateForSamplesWithStartDate:startDate endDate:endDate options:HKQueryOptionStrictStartDate];

  NSSet *requestTypes = [NSSet setWithObjects:type, nil];
  [[HealthKit sharedHealthStore] requestAuthorizationToShareTypes:nil readTypes:requestTypes completion:^(BOOL success, NSError *error) {
    __block HealthKit *bSelf = self;
    if (success) {
      [[HealthKit sharedHealthStore] deleteObjectsOfType:type predicate:predicate withCompletion:^(BOOL success, NSUInteger deletedObjectCount, NSError * _Nullable deletionError) {
        if (deletionError != nil) {
            [HealthKit executeOnMainThread:^{
                [HealthKit triggerErrorCallbackWithMessage:deletionError.localizedDescription command:command delegate:bSelf.commandDelegate];
            }];
        } else {
            [HealthKit executeOnMainThread:^{
                CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsInt:(int)deletedObjectCount];
                [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
            }];
        }
      }];
    }
  }];
}

+ (void)sendObservedChanges:(int)minDelay completionHandler:(void(^)(void))completionHandler errorHandler:(void(^)(NSString *errorMsg))errorHandler {
    __block WKHTTPCookieStore *cookieStore = nil;
    
    [HealthKit executeOnMainThread:^{
        cookieStore = [WKWebsiteDataStore defaultDataStore].httpCookieStore;
    }];

    __block NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSArray<NSString *> *sampleTypes = [defaults objectForKey:@"HKObservedSampleTypes"];
    __block NSDate *lastHKSampleObservation = [defaults objectForKey:@"lastHKSampleObservation"];
    NSURL *updateUrl = [defaults URLForKey:@"HKUpdateUrl"];
    if(!lastHKSampleObservation) {
        lastHKSampleObservation = NSDate.distantPast;
    }
    NSTimeInterval timeSinceLastObservation = [[NSDate date] timeIntervalSinceDate:lastHKSampleObservation];

    if(timeSinceLastObservation >= minDelay) {

        NSDate *currentDate = [NSDate date];
        [defaults setObject:currentDate forKey:@"lastHKSampleObservation"];
        [defaults synchronize];

        // Send a POST request to the update URL
        NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
        [request setHTTPMethod:@"POST"];
        [request setURL:updateUrl];

        @try {
            [cookieStore getAllCookies:^(NSArray<NSHTTPCookie *> * _Nonnull cookies) {

                NSString *cookieHeader = nil;
                for (NSHTTPCookie *cookie in cookies) {
                    if (!cookieHeader) {
                        cookieHeader = [NSString stringWithFormat: @"%@=%@",[cookie name],[cookie value]];
                    } else {
                        cookieHeader = [NSString stringWithFormat: @"%@; %@=%@",cookieHeader,[cookie name],[cookie value]];
                    }
                }
                if (cookieHeader) {
                    [request addValue:cookieHeader forHTTPHeaderField:@"Cookie"];
                }

                void (^onComplete)(NSMutableDictionary *results) = ^(NSMutableDictionary *results) {
                    NSError *error = nil;
                    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:results options:0 error:&error];
                    if(!jsonData) {
                        //reset the timer if the request fails
                        [defaults setObject:lastHKSampleObservation forKey:@"lastHKSampleObservation"];
                        [defaults synchronize];

                        errorHandler(error.localizedDescription);
                    } else {
                        [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
                        [request setHTTPBody:jsonData];
                        
                        NSURLSession *session = [NSURLSession sharedSession];
                        NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:request
                                                                    completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                            if (error) {
                                //reset the timer if the request fails
                                [defaults setObject:lastHKSampleObservation forKey:@"lastHKSampleObservation"];
                                [defaults synchronize];

                                errorHandler([error localizedDescription]);
                            } else if (((NSHTTPURLResponse *)response).statusCode == 200) {
                                if(completionHandler) {
                                    completionHandler();
                                }
                            } else {
                                long code = ((NSHTTPURLResponse *)response).statusCode;

                                //reset the timer if the request fails
                                [defaults setObject:lastHKSampleObservation forKey:@"lastHKSampleObservation"];
                                [defaults synchronize];

                                NSString *msg = [NSString stringWithFormat:@"server returned status code %ld", code];
                                errorHandler(msg);
                            }
                        }];
                        [dataTask resume];
                    }
                };
        
                NSMutableDictionary *finalResults = [NSMutableDictionary dictionary];
                NSMutableArray *observedSampleTypes = [sampleTypes mutableCopy];
                [HealthKit queryObservedSamples:observedSampleTypes currentResults:finalResults onComplete:onComplete onError:errorHandler];

            }];
        } @catch (NSException *exception) {
                // Create a string with the exception name, reason, and call stack
                NSMutableString *errorString = [NSMutableString stringWithString:@"Exception Details:\n"];
                [errorString appendFormat:@"Name: %@\n", exception.name];
                [errorString appendFormat:@"Reason: %@\n", exception.reason];
                [errorString appendString:@"Call Stack:\n"];
                
                for (NSString *call in exception.callStackSymbols) {
                    [errorString appendFormat:@"%@\n", call];
                }

                NSLog(@"Exception caught during getAllCookies: %@", errorString);
                if (errorHandler) {
                    errorHandler(errorString);
                }
        } @finally {
        }
    } else if(completionHandler) {
        completionHandler();
    }
}

-(void)sendObservedChanges:(CDVInvokedUrlCommand*)command {
    [HealthKit sendObservedChanges:0
                 completionHandler:^{
                        [HealthKit executeOnMainThread:^{
                              CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:YES];
                              [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
                        }];
                    }
                      errorHandler:^(NSString *errorMsg) {
                        [HealthKit executeOnMainThread:^{
                            [HealthKit triggerErrorCallbackWithMessage:errorMsg command:command delegate:self.commandDelegate];
                        }];
                    }
    ];
}

- (void)observeChanges:(CDVInvokedUrlCommand*)command {
    NSMutableDictionary *args = command.arguments[0];

    // read types
    NSArray<NSString *> *sampleTypes = args[HKPluginKeySampleTypes];
    NSString *updateUrlStr = args[HKPluginKeyUpdateUrl];
    NSURL *updateUrl = [NSURL URLWithString:updateUrlStr];
    NSMutableArray<NSString *> *filteredSampleTypes = [NSMutableArray new];

    for (NSString *elem in sampleTypes) {
        HKObjectType *type = nil;

        if ([elem isEqual:@"HKWorkoutTypeIdentifier"]) {
            type = [HKObjectType workoutType];
        } else {
            type = [HealthKit getHKObjectType:elem];
        }

        if (type == nil) {
            CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"readTypes contains an invalid value"];
            [result setKeepCallbackAsBool:YES];
            [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
            // not returning deliberately to be future proof; other permissions are still asked
        } else {
            [filteredSampleTypes addObject:elem];
        }
    }

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:filteredSampleTypes forKey:@"HKObservedSampleTypes"];
    [defaults setURL:updateUrl forKey:@"HKUpdateUrl"];
    [defaults synchronize];

    HKSampleType *sampleType = [HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierStepCount];

    [[HealthKit sharedHealthStore] enableBackgroundDeliveryForType:sampleType
                                       frequency:HKUpdateFrequencyHourly
                                  withCompletion:^(BOOL success, NSError *error) {

        if (!success) {
            [HealthKit executeOnMainThread:^{
                [HealthKit triggerErrorCallbackWithMessage:error.localizedDescription command:command delegate:self.commandDelegate];
            }];
        } else {
            [HealthKit executeOnMainThread:^{
              CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:YES];
              [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
            }];
        }
    }];
}

@end

#pragma clang diagnostic pop
