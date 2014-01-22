//
//  ViewController.m
//  estimote2GOM
//
//  Created by Julian Krumow on 16.01.14.
//  Copyright (c) 2014 ART+COM AG. All rights reserved.
//

#import "ViewController.h"

NSString* const GOM_BEACON_PATH = @"/tests/beacons";
NSString* const GOM_BEACON_IMMEDIATE_PATH = @"/tests/beacons/immediate";

@interface ViewController ()
{
    BOOL _isGOMReady;
    NSURL *_gomRoot;
    GOMClient *_gomClient;
    NSMutableDictionary *_beacons;
    CLLocationManager *_locationManager;
    NSMutableArray *_rangedRegions;
    NSArray *_supportedProximityUUIDs;
    NSDictionary *_model;
}
@end

@implementation ViewController

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        
        // Estimote iBeacon
        NSString *UUIDString = [[NSUserDefaults standardUserDefaults] stringForKey:@"estimote_ibeacon_uuid_preference"];
        if (UUIDString && [UUIDString isEqualToString:@""] == NO) {
            _supportedProximityUUIDs = @[[[NSUUID alloc] initWithUUIDString:UUIDString]];
        }
        
        _beacons = [[NSMutableDictionary alloc] init];
        _model = @{};
        
        // This location manager will be used to demonstrate how to range beacons.
        _locationManager = [[CLLocationManager alloc] init];
        _locationManager.delegate = self;
        
        // GOM Client storing the beacon tracking data to the GOM
        _isGOMReady = NO;
        NSString *gomRootPath = [[NSUserDefaults standardUserDefaults] stringForKey:@"gom_address_preference"];
        if (gomRootPath && [gomRootPath isEqualToString:@""] == NO) {
            _gomRoot = [NSURL URLWithString:gomRootPath];
            _gomClient = [[GOMClient alloc] initWithGomURI:_gomRoot delegate:self];
        }
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Populate the regions we will range once.
    _rangedRegions = [NSMutableArray array];
    [_supportedProximityUUIDs enumerateObjectsUsingBlock:^(id uuidObj, NSUInteger uuidIdx, BOOL *uuidStop) {
        NSUUID *uuid = (NSUUID *)uuidObj;
        CLBeaconRegion *region = [[CLBeaconRegion alloc] initWithProximityUUID:uuid identifier:[uuid UUIDString]];
        
        [_rangedRegions addObject:region];
    }];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    
    self.consoleView = nil;
}

- (void)viewDidAppear:(BOOL)animated
{
    // Start ranging when the view appears.
    [_rangedRegions enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        CLBeaconRegion *region = obj;
        [_locationManager startRangingBeaconsInRegion:region];
    }];
}

- (void)viewDidDisappear:(BOOL)animated
{
    // Stop ranging when the view goes away.
    [_rangedRegions enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        CLBeaconRegion *region = obj;
        [_locationManager stopRangingBeaconsInRegion:region];
    }];
}

- (void)writeToConsole:(NSString *)message
{
    NSLog(@"%@", message);
    
    NSString *text = [NSString stringWithFormat:@"%@\n\n%@", message.description, self.consoleView.text];
    self.consoleView.text = text;
    NSRange range = NSMakeRange(0, 1);
    [self.consoleView scrollRangeToVisible:range];
}

#pragma mark - CLLocationManagerDelegate

- (void)locationManager:(CLLocationManager *)manager didEnterRegion:(CLRegion *)region
{
    NSLog(@"didEnterRegion: %@", region.identifier);
}

- (void)locationManager:(CLLocationManager *)manager didExitRegion:(CLRegion *)region
{
    NSLog(@"didExitRegion: %@", region.identifier);
}

- (void)locationManager:(CLLocationManager *)manager didStartMonitoringForRegion:(CLRegion *)region
{
    NSLog(@"didStartMonitoringForRegion: %@", region.identifier);
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    NSLog(@"CLLocationManager didFailWithError: %@", error.userInfo);
}

- (void)locationManager:(CLLocationManager *)manager rangingBeaconsDidFailForRegion:(CLBeaconRegion *)region withError:(NSError *)error
{
    NSLog(@"rangingBeaconsDidFailForRegion: %@ \n %@", region.identifier, error.userInfo);
}

- (void)locationManager:(CLLocationManager *)manager didRangeBeacons:(NSArray *)beacons inRegion:(CLBeaconRegion *)region
{
    // CoreLocation will call this delegate method at 1 Hz with updated range information.
    // Beacons will be categorized and displayed by proximity.
    [_beacons removeAllObjects];
    NSArray *unknownBeacons = [beacons filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"proximity = %d", CLProximityUnknown]];
    if ([unknownBeacons count]) {
        [_beacons setObject:unknownBeacons forKey:[NSNumber numberWithInt:CLProximityUnknown]];
    }
    NSArray *farBeacons = [beacons filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"proximity = %d", CLProximityFar]];
    if ([farBeacons count]) {
        [_beacons setObject:farBeacons forKey:[NSNumber numberWithInt:CLProximityFar]];
    }
    NSArray *nearBeacons = [beacons filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"proximity = %d", CLProximityNear]];
    if ([nearBeacons count]) {
        [_beacons setObject:nearBeacons forKey:[NSNumber numberWithInt:CLProximityNear]];
    }
    
    NSArray *immediateBeacons = [beacons filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"proximity = %d", CLProximityImmediate]];
    if ([immediateBeacons count]) {
        [_beacons setObject:immediateBeacons forKey:[NSNumber numberWithInt:CLProximityImmediate]];
        NSLog(@"immediate beacons: %@", immediateBeacons.description);
        
        [self updateColorForBeacon:immediateBeacons[0]];
    } else {
        [self updateColorForBeacon:nil];
    }
    [self writeBeaconDataToGOM:immediateBeacons];
}

- (void)updateColorForBeacon:(CLBeacon *)beacon
{
    if (beacon) {
        NSString *colorPath = [NSString stringWithFormat:@"%@/regions/%@/%@/%@:color", GOM_BEACON_PATH, beacon.proximityUUID.UUIDString, beacon.major, beacon.minor];
        [_gomClient retrieve:colorPath completionBlock:^(NSDictionary *data, NSError *error) {
            NSString *colorString = [data valueForKeyPath:@"attribute.value"];
            NSArray *rgb = [colorString componentsSeparatedByString:@","];
            CGFloat red = [rgb[0] floatValue];
            CGFloat green = [rgb[1] floatValue];
            CGFloat blue = [rgb[2] floatValue];
            CGFloat alpha = [rgb[3] floatValue];
            self.view.backgroundColor = [UIColor colorWithRed:red green:green blue:blue alpha:alpha];
        }];
    } else {
        self.view.backgroundColor = [UIColor whiteColor];
    }
}

- (void)writeBeaconDataToGOM:(NSArray *)beacons
{
    if (_isGOMReady) {
        NSDictionary *beaconData = nil;
        if ([beacons count]) {
            CLBeacon *beacon = beacons[0];
            beaconData = @{
                           @"UUID" : beacon.proximityUUID.UUIDString,
                           @"major" : beacon.major.stringValue,
                           @"minor" : beacon.minor.stringValue
                           };
        } else {
            beaconData = @{
                           @"UUID" : @"",
                           @"major" : @"",
                           @"minor" : @""
                           };
        }
        if ([beaconData isEqualToDictionary:_model] == NO) {
            _model = beaconData;
            [_gomClient updateNode:GOM_BEACON_IMMEDIATE_PATH withAttributes:_model completionBlock:nil];
        }
    }
}

#pragma  mark - GOMClientDelegate

- (void)gomClientDidBecomeReady:(GOMClient *)gomClient
{
    _isGOMReady = YES;
    [self writeToConsole:@"GOMClient is ready."];
    
    [_gomClient registerGOMObserverForPath:GOM_BEACON_IMMEDIATE_PATH options:nil clientCallback:^(NSDictionary *gnp) {
        [self writeToConsole:gnp.description];
    }];
}

- (void)gomClient:(GOMClient *)gomClient didFailWithError:(NSError *)error
{
    _isGOMReady = NO;
    [self writeToConsole:error.userInfo.description];
}

@end
