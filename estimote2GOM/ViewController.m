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
NSString* const BEACON_PROXIMITY_UUID = @"B9407F30-F5F8-466E-AFF9-25556B57FE6D";

@interface ViewController ()

@property (nonatomic, assign, getter = isGomReady) BOOL gomReady;
@property (nonatomic, strong) NSURL *gomRoot;
@property (nonatomic, strong) GOMClient *gomClient;
@property (nonatomic, strong) CLLocationManager *locationManager;
@property (nonatomic, strong) NSMutableArray *rangedRegions;
@property (nonatomic, strong) NSArray *supportedProximityUUIDs;
@property (nonatomic, strong) NSDictionary *model;

@end

@implementation ViewController

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        
        _model = @{};
        
        // Beacon UUID will be the same on all beacons in a given region.
        _supportedProximityUUIDs = @[[[NSUUID alloc] initWithUUIDString:BEACON_PROXIMITY_UUID]];
        
        // This location manager will be used to demonstrate how to range beacons.
        _locationManager = [[CLLocationManager alloc] init];
        self.locationManager.delegate = self;
        
        // GOM Client storing the beacon tracking data to the GOM
        self.gomReady = NO;
        NSString *gomRootPath = [[NSUserDefaults standardUserDefaults] stringForKey:@"gom_address_preference"];
        if (gomRootPath && [gomRootPath isEqualToString:@""] == NO) {
            _gomRoot = [NSURL URLWithString:gomRootPath];
            _gomClient = [[GOMClient alloc] initWithGomURI:self.gomRoot delegate:self];
        }
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _rangedRegions = [NSMutableArray array];
    [self.supportedProximityUUIDs enumerateObjectsUsingBlock:^(id uuidObj, NSUInteger uuidIdx, BOOL *uuidStop) {
        NSUUID *uuid = (NSUUID *)uuidObj;
        CLBeaconRegion *region = [[CLBeaconRegion alloc] initWithProximityUUID:uuid identifier:[uuid UUIDString]];
        
        [self.rangedRegions addObject:region];
    }];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    
    self.consoleView = nil;
}

- (void)viewDidAppear:(BOOL)animated
{
    [self.rangedRegions enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        CLBeaconRegion *region = obj;
        [self.locationManager startRangingBeaconsInRegion:region];
    }];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [self.rangedRegions enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        CLBeaconRegion *region = obj;
        [self.locationManager stopRangingBeaconsInRegion:region];
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
    NSArray *immediateBeacons = [beacons filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"proximity = %d", CLProximityImmediate]];
    if ([immediateBeacons count]) {
        NSLog(@"immediate beacons: %@", immediateBeacons.description);
        
        [self updateColorForBeacon:immediateBeacons[0]];
        [self writeBeaconDataToGOM:immediateBeacons[0]];
    } else {
        [self updateColorForBeacon:nil];
        [self writeBeaconDataToGOM:nil];
    }
}

- (void)updateColorForBeacon:(CLBeacon *)beacon
{
    if (beacon) {
        NSString *colorPath = [NSString stringWithFormat:@"%@/regions/%@/%@/%@:color", GOM_BEACON_PATH, beacon.proximityUUID.UUIDString, beacon.major, beacon.minor];
        [self.gomClient retrieve:colorPath completionBlock:^(NSDictionary *data, NSError *error) {
            NSString *colorString = [data valueForKeyPath:@"attribute.value"];
            NSArray *rgb = [colorString componentsSeparatedByString:@","];
            if ([rgb count] == 4) {
                CGFloat red = [rgb[0] floatValue];
                CGFloat green = [rgb[1] floatValue];
                CGFloat blue = [rgb[2] floatValue];
                CGFloat alpha = [rgb[3] floatValue];
                self.view.backgroundColor = [UIColor colorWithRed:red green:green blue:blue alpha:alpha];
            }
        }];
    } else {
        self.view.backgroundColor = [UIColor whiteColor];
    }
}

- (void)writeBeaconDataToGOM:(CLBeacon *)beacon
{
    if (self.isGomReady) {
        NSDictionary *beaconData = nil;
        if (beacon) {
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
        if ([beaconData isEqualToDictionary:self.model] == NO) {
            self.model = beaconData;
            [self.gomClient updateNode:GOM_BEACON_IMMEDIATE_PATH withAttributes:self.model completionBlock:nil];
        }
    }
}


#pragma  mark - GOMClientDelegate

- (void)gomClientDidBecomeReady:(GOMClient *)gomClient
{
    self.gomReady = YES;
    [self writeToConsole:@"GOMClient is ready."];
    
    [self.gomClient registerGOMObserverForPath:GOM_BEACON_IMMEDIATE_PATH options:nil clientCallback:^(NSDictionary *gnp) {
        [self writeToConsole:gnp.description];
    }];
}

- (void)gomClient:(GOMClient *)gomClient didFailWithError:(NSError *)error
{
    self.gomReady = NO;
    [self writeToConsole:error.userInfo.description];
}

@end
