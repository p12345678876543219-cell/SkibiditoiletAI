#import <UIKit/UIKit.h>

@interface GeminiMenuWindow : UIWindow
@property (nonatomic, strong) UIView *mainContainer;
@property (nonatomic, strong) UITextField *apiKeyField;
@property (nonatomic, strong) UITextView *resultTextView;
@property (nonatomic, strong) UIButton *camSpawnButton;
@property (nonatomic, strong) UIButton *camFloatingButton;
@property (nonatomic, assign) BOOL isCamActive;
@end

static GeminiMenuWindow *sharedMenuWindow = nil;
static UIButton *heartButton = nil;

// MARK: - Nút Trái Tim (❤️) - Giữ 1s để di chuyển & Chạm để ẩn/hiện Menu
@interface FloatingHeartButton : UIButton
@end

@implementation FloatingHeartButton {
    BOOL _isDraggable;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setTitle:@"❤️" forState:UIControlStateNormal];
        self.titleLabel.font = [UIFont systemFontOfSize:28];
        self.backgroundColor = [UIColor colorWithRed:0.85 green:0.10 blue:0.35 alpha:0.9]; // Đỏ hoa hồng
        self.layer.cornerRadius = frame.size.width / 2;
        self.layer.shadowColor = [UIColor blackColor].CGColor;
        self.layer.shadowOffset = CGSizeMake(0, 4);
        self.layer.shadowOpacity = 0.4;
        self.layer.shadowRadius = 6;
        
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        [self addGestureRecognizer:pan];
        
        UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
        longPress.minimumPressDuration = 1.0;
        [self addGestureRecognizer:longPress];
        
        _isDraggable = NO;
        [self addTarget:self action:@selector(heartTapped) forControlEvents:UIControlEventTouchUpInside];
    }
    return self;
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        _isDraggable = YES;
        UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
        [generator impactOccurred];
        [UIView animateWithDuration:0.2 animations:^{
            self.transform = CGAffineTransformMakeScale(1.2, 1.2);
        }];
    } else if (gesture.state == UIGestureRecognizerStateEnded || gesture.state == UIGestureRecognizerStateCancelled) {
        [UIView animateWithDuration:0.2 animations:^{
            self.transform = CGAffineTransformIdentity;
        }];
    }
}

- (void)handlePan:(UIPanGestureRecognizer *)gesture {
    if (!_isDraggable) return;
    UIView *superview = self.superview;
    CGPoint translation = [gesture translationInView:superview];
    CGPoint center = self.center;
    center.x += translation.x;
    center.y += translation.y;
    self.center = center;
    [gesture setTranslation:CGPointZero inView:superview];
    
    if (gesture.state == UIGestureRecognizerStateEnded || gesture.state == UIGestureRecognizerStateCancelled) {
        _isDraggable = NO;
    }
}

- (void)heartTapped {
    if (!_isDraggable) {
        if (sharedMenuWindow) {
            sharedMenuWindow.hidden = !sharedMenuWindow.hidden;
        }
    }
}
@end

// MARK: - Nút Camera (📷) - Có thể di chuyển & Chụp màn hình gửi Gemini
@interface FloatingCamButton : UIButton
@end

@implementation FloatingCamButton
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setTitle:@"📷" forState:UIControlStateNormal];
        self.titleLabel.font = [UIFont systemFontOfSize:24];
        self.backgroundColor = [UIColor colorWithRed:0.90 green:0.15 blue:0.40 alpha:0.95];
        self.layer.cornerRadius = frame.size.width / 2;
        self.layer.shadowColor = [UIColor blackColor].CGColor;
        self.layer.shadowOffset = CGSizeMake(0, 3);
        self.layer.shadowOpacity = 0.5;
        self.layer.shadowRadius = 4;
        
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        [self addGestureRecognizer:pan];
        [self addTarget:self action:@selector(captureAndSendToGemini) forControlEvents:UIControlEventTouchUpInside];
    }
    return self;
}

- (void)handlePan:(UIPanGestureRecognizer *)gesture {
    UIView *superview = self.superview;
    CGPoint translation = [gesture translationInView:superview];
    CGPoint center = self.center;
    center.x += translation.x;
    center.y += translation.y;
    self.center = center;
    [gesture setTranslation:CGPointZero inView:superview];
}

- (void)captureAndSendToGemini {
    // 1. Chụp màn hình
    UIWindow *keyWindow = [[UIApplication sharedApplication] keyWindow];
    UIGraphicsBeginImageContextWithOptions(keyWindow.bounds.size, NO, [UIScreen mainScreen].scale);
    [keyWindow.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *screenshot = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    NSData *imageData = UIImageJPEGRepresentation(screenshot, 0.7);
    NSString *base64Image = [imageData base64EncodedStringWithOptions:0];
    
    // Lấy API Key từ NSUserDefaults hoặc ô nhập
    NSString *apiKey = [[NSUserDefaults standardUserDefaults] stringForKey:@"GeminiApiKey"];
    if (!apiKey || apiKey.length == 0) {
        if (sharedMenuWindow && sharedMenuWindow.resultTextView) {
            sharedMenuWindow.resultTextView.text = @"⚠️ Lỗi: Vui lòng nhập Gemini API Key ở Tab 1 trước!";
        }
        return;
    }
    
    if (sharedMenuWindow && sharedMenuWindow.resultTextView) {
        sharedMenuWindow.resultTextView.text = @"⏳ Đang gửi ảnh và phân tích với Gemini AI...";
    }
    
    // 2. Gửi request đến Gemini API (gemini-1.5-flash)
    NSString *urlString = [NSString stringWithFormat:@"https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=%@", apiKey];
    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    
    NSDictionary *payload = @{
        @"contents": @[
            @{
                @"parts": @[
                    @{@"text": @"Hãy phân tích hình ảnh này, đọc bất kỳ câu hỏi hoặc nội dung nào có trong đó và đưa ra câu trả lời chi tiết bằng tiếng Việt."},
                    @{
                        @"inline_data": @{
                            @"mime_type": @"image/jpeg",
                            @"data": base64Image
                        }
                    }
                ]
            }
        ]
    };
    
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:payload options:0 error:&error];
    [request setHTTPBody:jsonData];
    
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                sharedMenuWindow.resultTextView.text = [NSString stringWithFormat:@"❌ Lỗi kết nối: %@", error.localizedDescription];
                return;
            }
            
            NSError *jsonError;
            NSDictionary *jsonResponse = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
            
            NSArray *candidates = jsonResponse[@"candidates"];
            if (candidates && candidates.count > 0) {
                NSDictionary *content = candidates[0][@"content"];
                NSArray *parts = content[@"parts"];
                if (parts && parts.count > 0) {
                    NSString *responseText = parts[0][@"text"];
                    sharedMenuWindow.resultTextView.text = responseText;
                } else {
                    sharedMenuWindow.resultTextView.text = @"⚠️ Không nhận được phản hồi hợp lệ từ AI.";
                }
            } else {
                sharedMenuWindow.resultTextView.text = [NSString stringWithFormat:@"❌ Phản hồi API lỗi: %@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]];
            }
        });
    }];
    [task resume];
}
@end

// MARK: - Menu Chính (Chủ đề Đỏ Hoa Hồng, Có thể di chuyển)
@implementation GeminiMenuWindow

-િન - (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.windowLevel = UIWindowLevelAlert + 100;
        self.backgroundColor = [UIColor clearColor];
        
        UIViewController *vc = [[UIViewController alloc] init];
        self.rootViewController = vc;
        
        // Khung menu chính màu đỏ hoa hồng / tối sang trọng
        _mainContainer = [[UIView alloc] initWithFrame:CGRectMake(40, 100, 320, 480)];
        _mainContainer.backgroundColor = [UIColor colorWithRed:0.12 green:0.12 blue:0.14 alpha:0.95];
        _mainContainer.layer.cornerRadius = 16;
        _mainContainer.layer.borderWidth = 2.0;
        _mainContainer.layer.borderColor = [UIColor colorWithRed:0.91 green:0.12 blue:0.39 alpha:1.0]; // Viền đỏ hoa hồng
        _mainContainer.clipsToBounds = YES;
        [vc.view addSubview:_mainContainer];
        
        // Header kéo di chuyển menu
        UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 44]);
        headerView.backgroundColor = [UIColor colorWithRed:0.91 green:0.12 blue:0.39 alpha:1.0];
        UILabel *titleLabel = [[UILabel alloc] initWithFrame:headerView.bounds];
        titleLabel.text = @"❤️ Gemini AI Menu ❤️";
        titleLabel.textColor = [UIColor whiteColor];
        titleLabel.textAlignment = NSTextAlignmentCenter;
        titleLabel.font = [UIFont boldSystemFontOfSize:16];
        [headerView addSubview:titleLabel];
        [_mainContainer addSubview:headerView];
        
        UIPanGestureRecognizer *menuPan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleMenuPan:)];
        [headerView addGestureRecognizer:menuPan];
        
        // Tab Bar giả lập (Tab1 / Tab2)
        UIView *tabBar = [[UIView alloc] initWithFrame:CGRectMake(10, 54, 300, 36]);
        tabBar.backgroundColor = [UIColor colorWithRed:0.20 green:0.20 blue:0.22 alpha:1.0];
        tabBar.layer.cornerRadius = 8;
        
        UIButton *tab1Btn = [UIButton buttonWithType:UIButtonTypeSystem];
        tab1Btn.frame = CGRectMake(0, 0, 150, 36);
        [tab1Btn setTitle:@"Tab 1: Tính Năng" forState:UIControlStateNormal];
        [tab1Btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [tab1Btn.titleLabel setFont:[UIFont boldSystemFontOfSize:13]];
        [tabBar addSubview:tab1Btn];
        
        UIButton *tab2Btn = [UIButton buttonWithType:UIButtonTypeSystem];
        tab2Btn.frame = CGRectMake(150, 0, 150, 36);
        [tab2Btn setTitle:@"Tab 2: Thông Tin" forState:UIControlStateNormal];
        [tab2Btn setTitleColor:[UIColor lightGrayColor] forState:UIControlStateNormal];
        [tab2Btn.titleLabel setFont:[UIFont systemFontOfSize:13]];
        [tabBar addSubview:tab2Btn];
        
        [_mainContainer addSubview:tabBar];
        
        // Ô nhập API Key Gemini
        _apiKeyField = [[UITextField alloc] initWithFrame:CGRectMake(15, 100, 290, 36]);
        _apiKeyField.placeholder = @"Dán API Key Gemini vào đây...";
        _apiKeyField.backgroundColor = [UIColor colorWithRed:0.25 green:0.25 blue:0.28 alpha:1.0];
        _apiKeyField.textColor = [UIColor whiteColor];
        _apiKeyField.font = [UIFont systemFontOfSize:13];
        _apiKeyField.borderStyle = UITextBorderStyleRoundedRect;
        _apiKeyField.clearButtonMode = UITextFieldViewModeWhileEditing;
        
        // Tải API Key đã lưu trước đó nếu có
        NSString *savedKey = [[NSUserDefaults standardUserDefaults] stringForKey:@"GeminiApiKey"];
        if (savedKey) _apiKeyField.text = savedKey;
        
        [_apiKeyField addTarget:self action:@selector(apiKeyChanged:) forControlEvents:UIControlEventEditingChanged];
        [_mainContainer addSubview:_apiKeyField];
        
        // Nút bật/tắt nút Camera 📷
        _camSpawnButton = [UIButton buttonWithType:UIButtonTypeSystem];
        _camSpawnButton.frame = CGRectMake(15, 146, 290, 40];
        [_camSpawnButton setTitle:@"📷 Bật nút chụp ảnh nổi" forState:UIControlStateNormal];
        [_camSpawnButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        _camSpawnButton.backgroundColor = [UIColor colorWithRed:0.91 green:0.12 blue:0.39 alpha:1.0];
        _camSpawnButton.layer.cornerRadius = 8;
        [_camSpawnButton addTarget:self action:@selector(toggleCamButton) forControlEvents:UIControlEventTouchUpInside];
        [_mainContainer addSubview:_camSpawnButton];
        
        // Khung màu trắng hiển thị kết quả từ AI
        _resultTextView = [[UITextView alloc] initWithFrame:CGRectMake(15, 196, 290, 230)];
        _resultTextView.backgroundColor = [UIColor whiteColor];
        _resultTextView.textColor = [UIColor blackColor];
        _resultTextView.font = [UIFont systemFontOfSize:14];
        _resultTextView.layer.cornerRadius = 8;
        _resultTextView.editable = NO;
        _resultTextView.text = @"Kết quả phân tích từ AI Gemini sẽ hiển thị ở đây...";
        [_mainContainer addSubview:_resultTextView];
        
        // Nút Đóng Menu nhỏ góc dưới
        UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        closeBtn.frame = CGRectMake(15, 436, 135, 32];
        [closeBtn setTitle:@"Ẩn Menu" forState:UIControlStateNormal];
        [closeBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        closeBtn.backgroundColor = [UIColor darkGrayColor];
        closeBtn.layer.cornerRadius = 6;
        [closeBtn addTarget:self action:@selector(hideMenu) forControlEvents:UIControlEventTouchUpInside];
        [_mainContainer addSubview:closeBtn];
    }
    return self;
}

- (void)handleMenuPan:(UIPanGestureRecognizer *)gesture {
    UIView *superview = self.rootViewController.view;
    CGPoint translation = [gesture translationInView:superview];
    CGPoint center = _mainContainer.center;
    center.x += translation.x;
    center.y += translation.y;
    _mainContainer.center = center;
    [gesture setTranslation:CGPointZero inView:superview];
}

- (void)apiKeyChanged:(UITextField *)sender {
    [[NSUserDefaults standardUserDefaults] setObject:sender.text forKey:@"GeminiApiKey"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)toggleCamButton {
    _isCamActive = !_isCamActive;
    if (_isCamActive) {
        [_camSpawnButton setTitle:@"❌ Tắt nút chụp ảnh nổi" forState:UIControlStateNormal];
        if (!_camFloatingButton) {
            _camFloatingButton = [[FloatingCamButton alloc] initWithFrame:CGRectMake(50, 200, 50, 50)];
        }
        [self addSubview:_camFloatingButton];
    } else {
        [_camSpawnButton setTitle:@"📷 Bật nút chụp ảnh nổi" forState:UIControlStateNormal];
        [_camFloatingButton removeFromSuperview];
    }
}

- (void)hideMenu {
    self.hidden = YES;
}
@end

// MARK: - Khởi tạo Tweak khi ứng dụng khởi chạy
static void loadUI() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *keyWindow = [[UIApplication sharedApplication] keyWindow];
        if (keyWindow) {
            // Tạo nút Trái tim ❤️ ở góc màn hình
            if (!heartButton) {
                heartButton = [[FloatingHeartButton alloc] initWithFrame:CGRectMake(20, 100, 50, 50)];
                [keyWindow addSubview:heartButton];
            }
            // Khởi tạo sẵn cửa sổ menu chính (ẩn lúc đầu)
            if (!sharedMenuWindow) {
                sharedMenuWindow = [[GeminiMenuWindow alloc] initWithFrame:keyWindow.bounds];
                sharedMenuWindow.hidden = YES;
            }
        }
    });
}

%ctor {
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        loadUI();
    }];
}
