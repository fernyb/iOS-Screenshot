//
//  main.m
//  WindowScreenshot
//
//  Created by Fernando Barajas on 5/26/14.
//  Copyright (c) 2014 Fernando Barajas. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Quartz/Quartz.h>

NSString *kAppNameKey = @"applicationName";	// Application Name & PID
NSString *kWindowOriginKey = @"windowOrigin";	// Window Origin as a string
NSString *kWindowSizeKey = @"windowSize";		// Window Size as a string
NSString *kWindowIDKey = @"windowID";			// Window ID
NSString *kWindowLevelKey = @"windowLevel";	// Window Level
NSString *kWindowOrderKey = @"windowOrder";	// The overall front-to-back ordering of the windows as returned by the window server


@interface NSString (Base64)
+ (NSString*)base64forData:(NSData*)theData;
@end

@implementation NSString (Base64)
+ (NSString*)base64forData:(NSData*)theData
{
  const uint8_t* input = (const uint8_t*)[theData bytes];
  NSInteger length = [theData length];
  
  static char table[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=";
  
  NSMutableData* data = [NSMutableData dataWithLength:((length + 2) / 3) * 4];
  uint8_t* output = (uint8_t*)data.mutableBytes;
  
  NSInteger i;
  for (i=0; i < length; i += 3) {
    NSInteger value = 0;
    NSInteger j;
    for (j = i; j < (i + 3); j++) {
      value <<= 8;
      
      if (j < length) {
        value |= (0xFF & input[j]);
      }
    }
    
    NSInteger theIndex = (i / 3) * 4;
    output[theIndex + 0] =                    table[(value >> 18) & 0x3F];
    output[theIndex + 1] =                    table[(value >> 12) & 0x3F];
    output[theIndex + 2] = (i + 1) < length ? table[(value >> 6)  & 0x3F] : '=';
    output[theIndex + 3] = (i + 2) < length ? table[(value >> 0)  & 0x3F] : '=';
  }
  
  return [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
}
@end



void takeScreenshot(NSDictionary * simulatorWindow);

void takeScreenshot(NSDictionary * simulatorWindow) {
  CGWindowID windowID = [[simulatorWindow objectForKey:kWindowIDKey] intValue];
 
  //NSLog(@"%i", [[simulatorWindow objectForKey:kWindowIDKey] intValue]);
  
  CGWindowImageOption imageOptions = kCGWindowImageDefault;
  CGWindowListOption singleWindowListOptions = kCGWindowListOptionIncludingWindow;
  singleWindowListOptions = kCGWindowListOptionIncludingWindow;
  
  CGRect imageBounds = CGRectNull;
  
  CGImageRef windowImage = CGWindowListCreateImage(imageBounds, singleWindowListOptions, windowID, imageOptions);
  if(windowImage != NULL)
  {
    NSBitmapImageRep *bitmapRep = [[NSBitmapImageRep alloc] initWithCGImage:windowImage];
    
    NSData * data = [bitmapRep representationUsingType:NSPNGFileType properties:nil];
    
    NSTimeInterval timeStamp = [[NSDate date] timeIntervalSince1970];
    NSNumber * timeStampObj = [NSNumber numberWithDouble: timeStamp];
    
    NSString * path = [[NSString stringWithFormat:@"/tmp/ios_screenshot_%d_%i.png", [timeStampObj intValue], windowID] stringByExpandingTildeInPath];
    NSArray *arguments = [[NSProcessInfo processInfo] arguments];
    if([arguments count] > 1) {
      path = [arguments objectAtIndex:1];
    }
    
    [data writeToFile:path atomically:YES];
    printf("%s", [path UTF8String]);
  }
  CGImageRelease(windowImage);
  //NSLog(@"%@", simulatorWindow);
}




int main(int argc, const char * argv[])
{
  @autoreleasepool {
    CGWindowListOption listOptions;
    CFArrayRef windowListRef = CGWindowListCopyWindowInfo(listOptions, kCGNullWindowID);
    NSMutableArray * allWindows = [NSMutableArray array];
    
    NSArray * windowList = (__bridge NSArray*)windowListRef;
    NSDictionary * entry;
    NSEnumerator * e = [windowList objectEnumerator];
    int orderNum = 0;
    while(entry = [e nextObject])
    {
      int sharingState = [[entry objectForKey:(id)kCGWindowSharingState] intValue];
      if(sharingState == kCGWindowSharingNone)
      {
        continue;
      }
      
      NSMutableDictionary *outputEntry = [NSMutableDictionary dictionary];
      //NSLog(@"Item: %@", entry);
      
      // Grab the application name, but since it's optional we need to check before we can use it.
      NSString *applicationName = [entry objectForKey:(id)kCGWindowOwnerName];
      NSString * nameAndPID;
      if(applicationName != NULL)
      {
        // PID is required so we assume it's present.
        nameAndPID = [NSString stringWithFormat:@"%@ (%@)", applicationName, [entry objectForKey:(id)kCGWindowOwnerPID]];
        [outputEntry setObject:nameAndPID forKey:kAppNameKey];
      }
      else
      {
        // The application name was not provided, so we use a fake application name to designate this.
        // PID is required so we assume it's present.
        nameAndPID = [NSString stringWithFormat:@"((unknown)) (%@)", [entry objectForKey:(id)kCGWindowOwnerPID]];
        [outputEntry setObject:nameAndPID forKey:kAppNameKey];
      }
      
      if([nameAndPID hasPrefix:@"iOS Simulator"] == NO) {
        continue;
      }
      
      CGRect bounds;
      CGRectMakeWithDictionaryRepresentation((CFDictionaryRef)[entry objectForKey:(id)kCGWindowBounds], &bounds);
      if(bounds.origin.y <= 20) {
        continue;
      }
      
      NSString *originString = [NSString stringWithFormat:@"%.0f/%.0f", bounds.origin.x, bounds.origin.y];
      [outputEntry setObject:originString forKey:kWindowOriginKey];
      NSString *sizeString = [NSString stringWithFormat:@"%.0f*%.0f", bounds.size.width, bounds.size.height];
      [outputEntry setObject:sizeString forKey:kWindowSizeKey];
      
      // Grab the Window ID & Window Level. Both are required, so just copy from one to the other
      [outputEntry setObject:[entry objectForKey:(id)kCGWindowNumber] forKey:kWindowIDKey];
      [outputEntry setObject:[entry objectForKey:(id)kCGWindowLayer] forKey:kWindowLevelKey];
      [outputEntry setObject:[NSNumber numberWithInt:orderNum] forKey:kWindowOrderKey];
      orderNum++;
      
      //takeScreenshot(outputEntry);
      //NSLog(@"%@", outputEntry);
      
      [allWindows addObject:outputEntry];
    }// end while

    
    if([allWindows count] > 0) {
      NSDictionary * simulatorWindow = [allWindows firstObject];
      takeScreenshot(simulatorWindow);
      //NSLog(@"%@", simulatorWindow);
    }
    else
    {
      printf("no screenshot");
    }
    
  }
    return 0;
}