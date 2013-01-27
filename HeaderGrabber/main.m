//
//  main.m
//  HeaderGrabber
//
//  Created by Jack Willis on 27/01/2013.
//  Copyright (c) 2013 Jack Willis. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "IPSWActions.h"

int main(int argc, const char * argv[])
{

    @autoreleasepool {
        
        // insert code here...
        
        if (strcmp(argv[1], "--help") == 0)
        {
            printf("Usage: sudo ./HeaderGrabber <input ipsw> <header output directory>\r");
            
            return 0;
        }
        
        
        if (argc == 3)
        {
            NSString *inputString = [NSString stringWithCString:argv[1] encoding:NSStringEncodingConversionAllowLossy];
            NSString *outputString = [NSString stringWithCString:argv[2] encoding:NSStringEncodingConversionAllowLossy];
        
            if (inputString == nil)
            {
                printf("Please provide a valid ipsw\r");
            }
            else if (outputString == nil)
            {
                printf("Please provide a valid output directory\r");
            }
            else
            {
                IPSWActions *actions = [[IPSWActions alloc] initWithIPSWAtPath:inputString andOutputPath:outputString];
                [actions runActions];
                [actions release];
            }
        }
        else
        {
            printf("Not enough parameters given\r");
        }
    }
    return 0;
}
