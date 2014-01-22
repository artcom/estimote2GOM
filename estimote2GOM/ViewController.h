//
//  ViewController.h
//  estimote2GOM
//
//  Created by Julian Krumow on 16.01.14.
//  Copyright (c) 2014 ART+COM AG. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>

#import "GOMClient.h"

@interface ViewController : UIViewController <CLLocationManagerDelegate, GOMClientDelegate>

@property (weak, nonatomic) IBOutlet UITextView *consoleView;

@end
