#import <UIKit/UIKit.h>
#import <MediaPlayer/MediaPlayer.h>
#import <AVFoundation/AVFoundation.h>

#pragma mark - Helpers

static NSString *AMStringOrFallback(id value, NSString *fallback) {
    if ([value isKindOfClass:[NSString class]] && [(NSString *)value length] > 0) {
        return value;
    }
    return fallback;
}

@interface AMPlayerViewController : UIViewController
@property (nonatomic, strong) UIImageView *backgroundImageView;
@property (nonatomic, strong) UIVisualEffectView *blurView;
@property (nonatomic, strong) UIView *dimView;
@property (nonatomic, strong) UIImageView *artworkView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *artistLabel;
@property (nonatomic, strong) UILabel *albumLabel;
@property (nonatomic, strong) UILabel *elapsedLabel;
@property (nonatomic, strong) UILabel *durationLabel;
@property (nonatomic, strong) UISlider *progressSlider;
@property (nonatomic, strong) UIButton *previousButton;
@property (nonatomic, strong) UIButton *playPauseButton;
@property (nonatomic, strong) UIButton *nextButton;
@property (nonatomic, strong) UILabel *hintLabel;
@property (nonatomic, strong) NSTimer *progressTimer;
@property (nonatomic, assign) BOOL isSeeking;
@property (nonatomic, strong) MPMusicPlayerController *musicPlayer;
@end

@implementation AMPlayerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];

    self.musicPlayer = [MPMusicPlayerController systemMusicPlayer];
    [self.musicPlayer beginGeneratingPlaybackNotifications];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(nowPlayingChanged:)
                                                 name:MPMusicPlayerControllerNowPlayingItemDidChangeNotification
                                               object:self.musicPlayer];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(playbackStateChanged:)
                                                 name:MPMusicPlayerControllerPlaybackStateDidChangeNotification
                                               object:self.musicPlayer];

    [self buildInterface];
    [self refreshTrackInfo];
    [self refreshPlaybackState];

    self.progressTimer = [NSTimer scheduledTimerWithTimeInterval:0.5
                                                          target:self
                                                        selector:@selector(updateProgress)
                                                        userInfo:nil
                                                         repeats:YES];
}

- (void)buildInterface {
    CGRect bounds = self.view.bounds;
    self.backgroundImageView = [[UIImageView alloc] initWithFrame:bounds];
    self.backgroundImageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.backgroundImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.backgroundImageView.image = [self placeholderArtwork];
    [self.view addSubview:self.backgroundImageView];

    if ([UIBlurEffect class]) {
        self.blurView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]];
        self.blurView.frame = bounds;
        self.blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self.view addSubview:self.blurView];
    }

    self.dimView = [[UIView alloc] initWithFrame:bounds];
    self.dimView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.24];
    self.dimView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.dimView];

    UIView *panel = [[UIView alloc] initWithFrame:CGRectZero];
    panel.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.09];
    panel.layer.cornerRadius = 22.0;
    panel.layer.borderWidth = 1.0;
    panel.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.16].CGColor;
    panel.clipsToBounds = YES;
    panel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:panel];

    self.artworkView = [[UIImageView alloc] initWithFrame:CGRectZero];
    self.artworkView.contentMode = UIViewContentModeScaleAspectFill;
    self.artworkView.clipsToBounds = YES;
    self.artworkView.layer.cornerRadius = 12.0;
    self.artworkView.translatesAutoresizingMaskIntoConstraints = NO;
    [panel addSubview:self.artworkView];

    self.titleLabel = [self labelWithSize:30 weight:UIFontWeightSemibold];
    self.titleLabel.numberOfLines = 2;
    self.artistLabel = [self labelWithSize:20 weight:UIFontWeightRegular];
    self.artistLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.82];
    self.albumLabel = [self labelWithSize:15 weight:UIFontWeightRegular];
    self.albumLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.62];

    self.elapsedLabel = [self labelWithSize:13 weight:UIFontWeightMedium];
    self.durationLabel = [self labelWithSize:13 weight:UIFontWeightMedium];
    self.elapsedLabel.textColor = self.durationLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.78];

    self.progressSlider = [[UISlider alloc] initWithFrame:CGRectZero];
    self.progressSlider.minimumValue = 0;
    self.progressSlider.maximumValue = 1;
    self.progressSlider.tintColor = [UIColor whiteColor];
    [self.progressSlider addTarget:self action:@selector(sliderTouchDown) forControlEvents:UIControlEventTouchDown];
    [self.progressSlider addTarget:self action:@selector(sliderChanged:) forControlEvents:UIControlEventValueChanged];
    [self.progressSlider addTarget:self action:@selector(sliderTouchUp) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];

    self.previousButton = [self buttonWithTitle:@"|◀" fontSize:28 action:@selector(previousTrack)];
    self.playPauseButton = [self buttonWithTitle:@"▶" fontSize:34 action:@selector(togglePlayback)];
    self.nextButton = [self buttonWithTitle:@"▶|" fontSize:28 action:@selector(nextTrack)];

    self.hintLabel = [self labelWithSize:12 weight:UIFontWeightRegular];
    self.hintLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.58];
    self.hintLabel.textAlignment = NSTextAlignmentCenter;
    self.hintLabel.text = @"控制当前系统音乐播放器";

    NSArray *views = @[self.titleLabel, self.artistLabel, self.albumLabel,
                       self.elapsedLabel, self.durationLabel, self.progressSlider,
                       self.previousButton, self.playPauseButton, self.nextButton, self.hintLabel];
    for (UIView *v in views) {
        v.translatesAutoresizingMaskIntoConstraints = NO;
        [panel addSubview:v];
    }

    NSDictionary *v = @{
        @"panel": panel, @"art": self.artworkView, @"title": self.titleLabel,
        @"artist": self.artistLabel, @"album": self.albumLabel, @"elapsed": self.elapsedLabel,
        @"duration": self.durationLabel, @"slider": self.progressSlider,
        @"prev": self.previousButton, @"play": self.playPauseButton, @"next": self.nextButton,
        @"hint": self.hintLabel
    };
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-34-[panel]-34-|" options:0 metrics:nil views:v]];
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-28-[panel]-28-|" options:0 metrics:nil views:v]];

    [panel addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-28-[art(==art.height)]-30-[title]-28-|" options:0 metrics:nil views:v]];
    [panel addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-28-[art]-28-|" options:0 metrics:nil views:v]];
    [panel addConstraint:[NSLayoutConstraint constraintWithItem:self.artworkView attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:panel attribute:NSLayoutAttributeHeight multiplier:0.72 constant:-40]];

    [panel addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-34-[title(>=36)]-8-[artist(26)]-4-[album(20)]-(>=12)-[slider(30)]-2-[elapsed(18)]-18-[play(54)]-18-[hint(16)]-20-|" options:0 metrics:nil views:v]];
    [panel addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:[art]-30-[title]-28-|" options:0 metrics:nil views:v]];
    [panel addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:[art]-30-[artist]-28-|" options:0 metrics:nil views:v]];
    [panel addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:[art]-30-[album]-28-|" options:0 metrics:nil views:v]];
    [panel addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:[art]-30-[slider]-28-|" options:0 metrics:nil views:v]];
    [panel addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:[art]-30-[elapsed(45)]" options:0 metrics:nil views:v]];
    [panel addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:[duration(45)]-28-|" options:0 metrics:nil views:v]];
    [panel addConstraint:[NSLayoutConstraint constraintWithItem:self.durationLabel attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:self.elapsedLabel attribute:NSLayoutAttributeCenterY multiplier:1 constant:0]];
    [panel addConstraint:[NSLayoutConstraint constraintWithItem:self.durationLabel attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:panel attribute:NSLayoutAttributeTrailing multiplier:1 constant:-28]];

    [panel addConstraint:[NSLayoutConstraint constraintWithItem:self.previousButton attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:self.playPauseButton attribute:NSLayoutAttributeCenterY multiplier:1 constant:0]];
    [panel addConstraint:[NSLayoutConstraint constraintWithItem:self.nextButton attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:self.playPauseButton attribute:NSLayoutAttributeCenterY multiplier:1 constant:0]];
    [panel addConstraint:[NSLayoutConstraint constraintWithItem:self.previousButton attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:self.playPauseButton attribute:NSLayoutAttributeCenterX multiplier:1 constant:-100]];
    [panel addConstraint:[NSLayoutConstraint constraintWithItem:self.nextButton attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:self.playPauseButton attribute:NSLayoutAttributeCenterX multiplier:1 constant:100]];
    [panel addConstraint:[NSLayoutConstraint constraintWithItem:self.playPauseButton attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:panel attribute:NSLayoutAttributeCenterX multiplier:1 constant:0]];
    [panel addConstraint:[NSLayoutConstraint constraintWithItem:self.hintLabel attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:panel attribute:NSLayoutAttributeCenterX multiplier:1 constant:0]];
}

- (UILabel *)labelWithSize:(CGFloat)size weight:(CGFloat)weight {
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
    label.textColor = [UIColor whiteColor];
    label.font = [UIFont systemFontOfSize:size weight:weight];
    label.adjustsFontSizeToFitWidth = YES;
    label.minimumScaleFactor = 0.75;
    return label;
}

- (UIButton *)buttonWithTitle:(NSString *)title fontSize:(CGFloat)size action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:size weight:UIFontWeightLight];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (UIImage *)placeholderArtwork {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(320, 320), YES, 1.0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    [[UIColor colorWithRed:0.10 green:0.18 blue:0.30 alpha:1] setFill];
    CGContextFillRect(ctx, CGRectMake(0, 0, 320, 320));
    [[UIColor colorWithRed:0.30 green:0.48 blue:0.64 alpha:0.8] setFill];
    CGContextFillEllipseInRect(ctx, CGRectMake(74, 55, 172, 172));
    [[UIColor colorWithRed:0.08 green:0.13 blue:0.22 alpha:0.9] setFill];
    CGContextFillRect(ctx, CGRectMake(0, 210, 320, 110));
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

- (void)refreshTrackInfo {
    MPMediaItem *item = self.musicPlayer.nowPlayingItem;
    if (!item) {
        self.titleLabel.text = @"暂无正在播放的歌曲";
        self.artistLabel.text = @"请先在「音乐」应用中播放歌曲";
        self.albumLabel.text = @"支持系统音乐播放器";
        self.artworkView.image = [self placeholderArtwork];
        self.backgroundImageView.image = self.artworkView.image;
        self.hintLabel.text = @"此版本读取系统音乐资料库";
        [self updateProgress];
        return;
    }

    self.titleLabel.text = AMStringOrFallback([item valueForProperty:MPMediaItemPropertyTitle], @"未知歌曲");
    self.artistLabel.text = AMStringOrFallback([item valueForProperty:MPMediaItemPropertyArtist], @"未知艺人");
    self.albumLabel.text = AMStringOrFallback([item valueForProperty:MPMediaItemPropertyAlbumTitle], @"");
    MPMediaItemArtwork *artwork = [item valueForProperty:MPMediaItemPropertyArtwork];
    UIImage *image = artwork ? [artwork imageWithSize:CGSizeMake(600, 600)] : nil;
    if (!image) image = [self placeholderArtwork];
    self.artworkView.image = image;
    self.backgroundImageView.image = image;
    self.hintLabel.text = @"AmbientMusic · iOS 8";
    [self updateProgress];
}

- (void)refreshPlaybackState {
    self.playPauseButton.enabled = YES;
    NSString *symbol = (self.musicPlayer.playbackState == MPMusicPlaybackStatePlaying) ? @"Ⅱ" : @"▶";
    [self.playPauseButton setTitle:symbol forState:UIControlStateNormal];
}

- (void)updateProgress {
    if (self.isSeeking) return;
    MPMediaItem *item = self.musicPlayer.nowPlayingItem;
    NSTimeInterval duration = [[item valueForProperty:MPMediaItemPropertyPlaybackDuration] doubleValue];
    NSTimeInterval elapsed = self.musicPlayer.currentPlaybackTime;
    if (duration <= 0 || !isfinite(duration)) duration = 0;
    if (elapsed < 0 || !isfinite(elapsed)) elapsed = 0;
    self.progressSlider.maximumValue = duration > 0 ? (float)duration : 1.0f;
    self.progressSlider.value = duration > 0 ? (float)MIN(elapsed, duration) : 0;
    self.elapsedLabel.text = [self timeString:elapsed];
    self.durationLabel.text = [self timeString:duration];
}

- (NSString *)timeString:(NSTimeInterval)time {
    NSInteger seconds = (NSInteger)MAX(0, time);
    return [NSString stringWithFormat:@"%ld:%02ld", (long)(seconds / 60), (long)(seconds % 60)];
}

- (void)sliderTouchDown { self.isSeeking = YES; }

- (void)sliderChanged:(UISlider *)slider {
    self.elapsedLabel.text = [self timeString:slider.value];
}

- (void)sliderTouchUp {
    self.musicPlayer.currentPlaybackTime = self.progressSlider.value;
    self.isSeeking = NO;
    [self updateProgress];
}

- (void)togglePlayback {
    if (self.musicPlayer.playbackState == MPMusicPlaybackStatePlaying) {
        [self.musicPlayer pause];
    } else {
        [self.musicPlayer play];
    }
    [self refreshPlaybackState];
}

- (void)previousTrack {
    [self.musicPlayer skipToPreviousItem];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self refreshTrackInfo];
        [self refreshPlaybackState];
    });
}

- (void)nextTrack {
    [self.musicPlayer skipToNextItem];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self refreshTrackInfo];
        [self refreshPlaybackState];
    });
}

- (void)nowPlayingChanged:(NSNotification *)notification {
    [self refreshTrackInfo];
    [self refreshPlaybackState];
}

- (void)playbackStateChanged:(NSNotification *)notification {
    [self refreshPlaybackState];
    [self refreshTrackInfo];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    self.backgroundImageView.frame = self.view.bounds;
    self.blurView.frame = self.view.bounds;
    self.dimView.frame = self.view.bounds;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskLandscape;
}

- (BOOL)shouldAutorotate { return YES; }

- (void)dealloc {
    [self.progressTimer invalidate];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.musicPlayer endGeneratingPlaybackNotifications];
}

@end

@interface AMAppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation AMAppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    AMPlayerViewController *controller = [[AMPlayerViewController alloc] init];
    self.window.rootViewController = controller;
    [self.window makeKeyAndVisible];
    return YES;
}
@end

int main(int argc, char *argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AMAppDelegate class]));
    }
}
