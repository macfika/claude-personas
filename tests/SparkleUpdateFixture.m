// Isolated integration fixture: no production data or updater preferences are used.
#import <Cocoa/Cocoa.h>
#import <Sparkle/Sparkle.h>
#import <unistd.h>

static void record(NSString *event) {
    NSString *path = [NSBundle.mainBundle objectForInfoDictionaryKey:@"FixtureLogPath"];
    NSString *line = [NSString stringWithFormat:@"%@ pid=%d version=%@\n", event, getpid(), [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleVersion"]];
    NSFileHandle *file = [NSFileHandle fileHandleForWritingAtPath:path];
    if (!file) { [line writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil]; }
    else { [file seekToEndOfFile]; [file writeData:[line dataUsingEncoding:NSUTF8StringEncoding]]; [file closeFile]; }
}

@interface Fixture : NSObject <NSApplicationDelegate, SPUUserDriver>
@property(nonatomic, strong) SPUUpdater *updater;
@end
@implementation Fixture
- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    record(@"launched");
    if ([[NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleVersion"] isEqual:@"2"]) {
        NSDictionary *marker = @{ @"version": @"2", @"pid": @(getpid()), @"bundlePath": NSBundle.mainBundle.bundlePath };
        NSData *data = [NSJSONSerialization dataWithJSONObject:marker options:0 error:nil];
        [data writeToFile:[NSBundle.mainBundle objectForInfoDictionaryKey:@"FixtureMarkerPath"] atomically:YES];
        [NSApp terminate:nil];
        return;
    }
    self.updater = [[SPUUpdater alloc] initWithHostBundle:NSBundle.mainBundle applicationBundle:NSBundle.mainBundle userDriver:self delegate:nil];
    NSError *error = nil;
    if (![self.updater startUpdater:&error]) { record([@"start-error " stringByAppendingString:error.description]); [NSApp terminate:nil]; return; }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC), dispatch_get_main_queue(), ^{ [self.updater checkForUpdates]; });
}
- (void)applicationWillTerminate:(NSNotification *)notification { record(@"terminating"); }
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender { return NO; }
- (void)showUpdatePermissionRequest:(SPUUpdatePermissionRequest *)request reply:(void (^)(SUUpdatePermissionResponse *))reply { reply([[SUUpdatePermissionResponse alloc] initWithAutomaticUpdateChecks:NO sendSystemProfile:NO]); }
- (void)showUserInitiatedUpdateCheckWithCancellation:(void (^)(void))cancellation { record(@"checking"); }
- (void)showUpdateFoundWithAppcastItem:(SUAppcastItem *)item state:(SPUUserUpdateState *)state reply:(void (^)(SPUUserUpdateChoice))reply { record(@"found-update"); reply(SPUUserUpdateChoiceInstall); }
- (void)showUpdateReleaseNotesWithDownloadData:(SPUDownloadData *)data {}
- (void)showUpdateReleaseNotesFailedToDownloadWithError:(NSError *)error {}
- (void)showUpdateNotFoundWithError:(NSError *)error acknowledgement:(void (^)(void))ack { record([@"no-update " stringByAppendingString:error.description]); ack(); [NSApp terminate:nil]; }
- (void)showUpdaterError:(NSError *)error acknowledgement:(void (^)(void))ack { record([@"update-error " stringByAppendingString:error.description]); ack(); [NSApp terminate:nil]; }
- (void)showDownloadInitiatedWithCancellation:(void (^)(void))cancellation { record(@"downloading"); }
- (void)showDownloadDidReceiveExpectedContentLength:(uint64_t)length {}
- (void)showDownloadDidReceiveDataOfLength:(uint64_t)length {}
- (void)showDownloadDidStartExtractingUpdate { record(@"extracting"); }
- (void)showExtractionReceivedProgress:(double)progress {}
- (void)showReadyToInstallAndRelaunch:(void (^)(SPUUserUpdateChoice))reply { record(@"install-and-relaunch"); reply(SPUUserUpdateChoiceInstall); }
- (void)showInstallingUpdateWithApplicationTerminated:(BOOL)terminated retryTerminatingApplication:(void (^)(void))retry { record(@"installing"); }
- (void)showUpdateInstalledAndRelaunched:(BOOL)relaunched acknowledgement:(void (^)(void))ack { record(@"installed"); ack(); }
- (void)dismissUpdateInstallation {}
@end

int main(void) {
    @autoreleasepool {
        NSApplication *app = NSApplication.sharedApplication;
        Fixture *fixture = [Fixture new];
        app.delegate = fixture;
        [app setActivationPolicy:NSApplicationActivationPolicyAccessory];
        [app run];
    }
    return 0;
}
