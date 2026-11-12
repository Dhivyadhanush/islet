#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <dlfcn.h>

// IsletMedia is loaded by /usr/bin/perl (see islet-media.pl). On macOS 15.4+
// MediaRemote no longer answers the legacy C API from an ordinary app process,
// but it does answer an Apple-signed perl process. The app therefore reads
// now-playing data from this small, bundled dylib instead of the private
// framework directly. The dylib only talks to MediaRemote; it never touches
// the network or the filesystem.

typedef void (*GetInfoFn)(dispatch_queue_t, void (^)(NSDictionary *));
typedef void (*GetPIDFn)(dispatch_queue_t, void (^)(int));
typedef void (*RegisterFn)(dispatch_queue_t);
typedef Boolean (*SendFn)(int, NSDictionary *);
typedef void (*SeekFn)(double);

static dispatch_queue_t gQueue;
static GetInfoFn gGetInfo;
static GetPIDFn gGetPID;
static SendFn gSend;
static SeekFn gSeek;

static void loadMediaRemote(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        void *handle = dlopen(
            "/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote",
            RTLD_NOW | RTLD_GLOBAL
        );
        if (!handle) return;
        gGetInfo = (GetInfoFn)dlsym(handle, "MRMediaRemoteGetNowPlayingInfo");
        gGetPID = (GetPIDFn)dlsym(handle, "MRMediaRemoteGetNowPlayingApplicationPID");
        RegisterFn registerNotifications =
            (RegisterFn)dlsym(handle, "MRMediaRemoteRegisterForNowPlayingNotifications");
        gSend = (SendFn)dlsym(handle, "MRMediaRemoteSendCommand");
        gSeek = (SeekFn)dlsym(handle, "MRMediaRemoteSetElapsedTime");
        gQueue = dispatch_queue_create("dev.dhanuz.islet.media", DISPATCH_QUEUE_SERIAL);
        if (registerNotifications) registerNotifications(gQueue);
    });
}

static NSDictionary *queryOnce(void) {
    loadMediaRemote();
    if (!gGetInfo || !gQueue) return @{};

    __block NSDictionary *information = nil;
    __block int pid = 0;
    dispatch_group_t group = dispatch_group_create();

    dispatch_group_enter(group);
    if (gGetPID) {
        gGetPID(gQueue, ^(int processID) {
            pid = processID;
            dispatch_group_leave(group);
        });
    } else {
        dispatch_group_leave(group);
    }

    dispatch_group_enter(group);
    gGetInfo(gQueue, ^(NSDictionary *info) {
        information = [info copy];
        dispatch_group_leave(group);
    });

    dispatch_group_wait(group, dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC));

    NSMutableDictionary *output = [NSMutableDictionary dictionary];
    if (information) {
        for (NSString *key in information) {
            id value = information[key];
            if ([value isKindOfClass:[NSData class]]) {
                output[key] = [(NSData *)value base64EncodedStringWithOptions:0];
            } else if ([value isKindOfClass:[NSDate class]]) {
                output[key] = @([(NSDate *)value timeIntervalSince1970]);
            } else {
                output[key] = value;
            }
        }
    }
    output[@"_pid"] = @(pid);
    return output;
}

static void emit(NSDictionary *dictionary) {
    NSData *data = [NSJSONSerialization dataWithJSONObject:dictionary options:0 error:nil];
    if (!data) return;
    fwrite(data.bytes, 1, data.length, stdout);
    fputc('\n', stdout);
    fflush(stdout);
}

/// Streams one JSON object per line forever. The app starts this once and
/// reads stdout until it terminates the helper.
__attribute__((visibility("default"))) void islet_stream(void) {
    NSString *lastArtworkID = nil;
    NSUInteger lastArtworkFingerprint = 0;
    while (1) {
        @autoreleasepool {
            NSDictionary *information = queryOnce();
            NSString *identifier =
                information[@"kMRMediaRemoteNowPlayingInfoContentItemIdentifier"]
                ?: information[@"kMRMediaRemoteNowPlayingInfoArtworkIdentifier"];

            if (!identifier) {
                identifier = [NSString stringWithFormat:@"%@|%@|%@",
                    information[@"kMRMediaRemoteNowPlayingInfoTitle"] ?: @"",
                    information[@"kMRMediaRemoteNowPlayingInfoArtist"] ?: @"",
                    information[@"kMRMediaRemoteNowPlayingInfoAlbum"] ?: @""];
            }

            // Browsers fetch Media Session artwork asynchronously, so the first
            // poll for a new track often has the title but no cover. Compare the
            // artwork payload itself instead of only the track identifier, or
            // late-arriving cover art would be stripped forever.
            NSData *artworkData = information[@"kMRMediaRemoteNowPlayingInfoArtworkData"];
            NSUInteger fingerprint = artworkData
                ? (artworkData.length ^ artworkData.hash)
                : 0;
            BOOL sameArtwork = [identifier isEqual:lastArtworkID]
                && fingerprint == lastArtworkFingerprint;

            if (sameArtwork) {
                if (artworkData) {
                    NSMutableDictionary *trimmed = [information mutableCopy];
                    [trimmed removeObjectForKey:@"kMRMediaRemoteNowPlayingInfoArtworkData"];
                    information = trimmed;
                }
            } else {
                lastArtworkID = identifier;
                lastArtworkFingerprint = fingerprint;
            }

            emit(information);
        }
        usleep(1500 * 1000);
    }
}

// MediaRemote delivers commands asynchronously and only while the calling
// process is alive. The stream mode is long-lived, but the app's one-shot
// fallback launches this helper, calls a function and exits immediately, so
// pump the run loop briefly or the command is silently dropped.
static void pumpRunLoop(NSTimeInterval seconds) {
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:seconds]];
}

__attribute__((visibility("default"))) void islet_command(int command) {
    loadMediaRemote();
    if (gSend) gSend(command, nil);
    pumpRunLoop(0.8);
}

__attribute__((visibility("default"))) void islet_seek(double time) {
    loadMediaRemote();
    if (gSeek) gSeek(time);
    pumpRunLoop(0.8);
}
