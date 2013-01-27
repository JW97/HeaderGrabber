//
//  IPSWActions.m
//  HeaderGrabber
//
//  Created by Jack Willis on 27/01/2013.
//  Copyright (c) 2013 Jack Willis. All rights reserved.
//

#import "IPSWActions.h"

@implementation IPSWActions

- (id)initWithIPSWAtPath:(NSString *)path andOutputPath:(NSString *)outputPath;
{
    if ((self = [super init]))
    {
        _ipswPath = path;
        _outputPath = outputPath;
    }
    return self;
}

- (void)runActions
{
    _extractedPath = @"/tmp/HeaderGrabber/";
    
    [self extractIpsw];
    [self loadIPSWInfo];
    if ([self getKeys])
    {
        [self decryptRootFS];
        [self mountRootFS];
        [self copySpringboard];
        [self unmountRootFS];
        [self dumpSpringboard];
    }
    [self cleanUp];
}

- (void)extractIpsw
{
    [[NSFileManager defaultManager] removeItemAtPath:_extractedPath error:nil];
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:_extractedPath isDirectory:YES])
    {
        [[NSFileManager defaultManager] createDirectoryAtPath:[NSString stringWithFormat:@"%@Firmware/", _extractedPath] withIntermediateDirectories:YES attributes:nil error:nil];
        [[NSFileManager defaultManager] createDirectoryAtPath:[NSString stringWithFormat:@"%@SpringBoard/", _extractedPath] withIntermediateDirectories:YES attributes:nil error:nil];
    }
    
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/usr/bin/unzip";
    task.arguments = @[_ipswPath, @"-d", [NSString stringWithFormat:@"%@Firmware/", _extractedPath]];
    
    NSLog(@"Extracting IPSW...\r");
    [task launch];
    [task waitUntilExit];
    [task release];
    NSLog(@"Finished Extracting IPSW\r");
}

- (void)loadIPSWInfo
{
    NSLog(@"Loading IPSW Info...\r");
    NSMutableDictionary *infoDict = [[NSMutableDictionary alloc] initWithContentsOfFile:[NSString stringWithFormat:@"%@BuildManifest.plist", [NSString stringWithFormat:@"%@Firmware/", _extractedPath]]];
    
    buildTrain = [[[[infoDict objectForKey:@"BuildIdentities"] objectAtIndex:0] objectForKey:@"Info"] objectForKey:@"BuildTrain"];
    deviceType = [[infoDict objectForKey:@"SupportedProductTypes"] objectAtIndex:0];
    buildNumber = [infoDict objectForKey:@"ProductBuildVersion"];
    
    deviceReadable = [NSString stringWithContentsOfURL:[NSURL URLWithString:[NSString stringWithFormat:@"http://api.ios.icj.me/v2/%@/latest/device", deviceType]] encoding:NSStringEncodingConversionAllowLossy error:nil];
    deviceReadable = [[deviceReadable stringByReplacingOccurrencesOfString:@"[" withString:@""] stringByReplacingOccurrencesOfString:@"]" withString:@""];
    deviceReadable = [[deviceReadable stringByReplacingOccurrencesOfString:@"(" withString:@""] stringByReplacingOccurrencesOfString:@")" withString:@""];
    
    rootFSName = [[[[[[infoDict objectForKey:@"BuildIdentities"] objectAtIndex:0] objectForKey:@"Manifest"] objectForKey:@"OS"] objectForKey:@"Info"] objectForKey:@"Path"];
    
    NSLog(@"Finished Loading IPSW Info\r");
}

- (BOOL)getKeys
{
    NSLog(@"Scraping For VFDecrypt Keys...\r");
    NSString *requestURLString = [[NSString stringWithFormat:@"http://theiphonewiki.com/wiki/index.php?title=%@_%@_(%@)", buildTrain, buildNumber, deviceReadable] stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding];
    
    NSURL *url = [NSURL URLWithString:requestURLString];    
    NSError *error = nil;
    NSXMLDocument *page = [[NSXMLDocument alloc] initWithContentsOfURL:url options:NSXMLDocumentTidyHTML error:&error];
    
    decryptKey = nil;
    NSArray *objects = [page.rootElement nodesForXPath:@"//li//code" error:nil];
    
    for (NSXMLElement *element in objects)
    {
        NSString *key = element.objectValue;
        if (key.length >= 72)
        {
            decryptKey = key;
            break;
        }
    }
    
    NSLog(@"Finished Scraping For VFDecrypt Keys\r");
    return (decryptKey != nil);
}

- (void)decryptRootFS
{
    NSString *rootFSPath = [NSString stringWithFormat:@"%@%@", [NSString stringWithFormat:@"%@Firmware/", _extractedPath], rootFSName];
    _rootFSDecryptedPath = [NSString stringWithFormat:@"%@DecryptedFS.dmg", [NSString stringWithFormat:@"%@Firmware/", _extractedPath]];
    
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/usr/local/bin/vfdecrypt";
    task.arguments = @[@"-i", rootFSPath, @"-k", decryptKey, @"-o", _rootFSDecryptedPath];
    
    NSLog(@"Decrypting RootFS...\r");
    [task launch];
    [task waitUntilExit];
    [task release];
    NSLog(@"Finished Decrypting RootFS\r");
}

- (void)mountRootFS
{
    //Mounting RootFS
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/usr/bin/hdiutil";
    task.arguments = @[@"attach", _rootFSDecryptedPath];
    
    NSPipe *output = [NSPipe pipe];
    task.standardOutput = output;
    
    NSLog(@"Mounting DMG...\r");
    [task launch];
    [task waitUntilExit];
    [task release];
    NSLog(@"Finished Mounting DMG\r");
    
    NSFileHandle * read = [output fileHandleForReading];
    NSData * dataRead = [read readDataToEndOfFile];
    NSString * stringRead = [[[NSString alloc] initWithData:dataRead encoding:NSUTF8StringEncoding] autorelease];
    
    NSArray *lines = [stringRead componentsSeparatedByString:@"/dev"];
    NSArray *parts = [[lines objectAtIndex:[lines count] - 1] componentsSeparatedByString:@" "];
    
    NSString *mountPointTemp = [[(NSString *)[parts objectAtIndex:[parts count] - 1] stringByReplacingOccurrencesOfString:@"\t" withString:@""] stringByReplacingOccurrencesOfString:@"\n" withString:@""];
    _rootFSMountPoint = mountPointTemp;
    _rootFSDevPoint = [NSString stringWithFormat:@"/dev%@", [parts objectAtIndex:0]];
}

- (void)copySpringboard
{
    //Copying to Temp
    [[NSFileManager defaultManager] copyItemAtPath:[NSString stringWithFormat:@"%@/System/Library/CoreServices/SpringBoard.app/SpringBoard", _rootFSMountPoint] toPath:[NSString stringWithFormat:@"%@SpringBoard/SpringBoard", _extractedPath] error:nil];
}

- (void)unmountRootFS
{
    //Unmounting RootFS
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/usr/bin/hdiutil";
    task.arguments = @[@"detach", _rootFSDevPoint];
    
    NSLog(@"Unmounting DMG...\r");
    [task launch];
    [task waitUntilExit];
    [task release];
    NSLog(@"Finished Unmounting DMG\r");
}

- (void)dumpSpringboard
{    
    //Dumping SpringBoard
    
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/opt/local/bin/class-dump";
    task.arguments = @[@"-H", @"-o", [NSString stringWithFormat:@"%@/", _outputPath], [NSString stringWithFormat:@"%@SpringBoard/SpringBoard", _extractedPath]];
    
    NSLog(@"Dumping SpringBoard Headers...\r");
    [task launch];
    [task waitUntilExit];
    [task release];
    NSLog(@"Finished Dumping SpringBoard Headers\r");
}

- (void)cleanUp
{
    [[NSFileManager defaultManager] removeItemAtPath:_extractedPath error:nil];
}

@end
