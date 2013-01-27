//
//  IPSWActions.h
//  HeaderGrabber
//
//  Created by Jack Willis on 27/01/2013.
//  Copyright (c) 2013 Jack Willis. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface IPSWActions : NSObject
{
    NSString *_ipswPath;
    NSString *_outputPath;
    
    NSString *_extractedPath;
    NSString *_rootFSDecryptedPath;
    NSString *_rootFSMountPoint;
    NSString *_rootFSDevPoint;
    
    NSString *buildTrain;
    NSString *deviceType;
    NSString *deviceReadable;
    NSString *buildNumber;
    NSString *rootFSName;
    
    NSString *decryptKey;
}

- (id)initWithIPSWAtPath:(NSString *)path andOutputPath:(NSString *)outputPath;

- (void)runActions;

- (void)extractIpsw;
- (void)loadIPSWInfo;

- (BOOL)getKeys;

- (void)decryptRootFS;

- (void)mountRootFS;
- (void)copySpringboard;
- (void)unmountRootFS;
- (void)dumpSpringboard;

- (void)cleanUp;
@end
