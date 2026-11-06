#import <UIKit/UIKit.h>

static UIWindow *menuWindow = nil;
static UIView *menuView = nil;
static UIButton *floatCaptureBtn = nil;
static UIView *resultContainer = nil;
static UITextView *resultTextView = nil;
static UITextField *apiKeyField = nil;

// Forward declarations
void createMenuUI();
void toggleMenu();
void toggleFloatButton(BOOL show);
void captureAndAnalyzeScreen();
void showResultPopup(NSString *text, BOOL isLoading);

// Helper lấy UIWindow an toàn trên iOS hiện đại
UIWindow *getSafestKeyWindow() {
    UIWindow *foundWindow = nil;
    for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if ([scene isKindOfClass:[UIWindowScene class]]) {
            for (UIWindow *win in scene.windows) {
                if (win.isKeyWindow) {
                    foundWindow = win;
                    break;
                }
            }
        }
    }
    if (!foundWindow) {
        foundWindow = [UIApplication sharedApplication].keyWindow;
    }
    return foundWindow;
}

// Gesture Helper cho 3 lần chạm màn hình
@interface TweakGestureHelper : NSObject
+ (instancetype)sharedInstance;
- (void)handleTripleTap:(UITapGestureRecognizer *)recognizer;
@end

@implementation TweakGestureHelper
+ (instancetype)sharedInstance {
    static TweakGestureHelper *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[TweakGestureHelper alloc] init];
    });
    return sharedInstance;
}
- (void)handleTripleTap:(UITapGestureRecognizer *)recognizer {
    if (recognizer.state == UIGestureRecognizerStateEnded) {
        toggleMenu();
    }
}
@end

// Pan Helper để kéo nút "Chụp" di chuyển
@interface FloatButtonPanHelper : NSObject
@property (nonatomic, assign) CGPoint startPoint;
@end
@implementation FloatButtonPanHelper
- (void)handlePan:(UIPanGestureRecognizer *)pan {
    UIView *btn = pan.view;
    CGPoint translation = [pan translationInView:btn.superview];
    if (pan.state == UIGestureRecognizerStateBegan) {
        self.startPoint = btn.center;
    } else if (pan.state == UIGestureRecognizerStateChanged) {
        btn.center = CGPointMake(self.startPoint.x + translation.x, self.startPoint.y + translation.y);
    }
}
@end

static FloatButtonPanHelper *panHelper = nil;

// Khai báo trước các hàm selector
void captureAction();
void switchChanged(UISwitch *sender);
void saveApiKeyAction();
void closeMenuAction();
void closeResultAction();

// Tạo Nút Chụp nổi
void toggleFloatButton(BOOL show) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *keyWindow = getSafestKeyWindow();
        if (!keyWindow) return;
        
        if (show) {
            if (!floatCaptureBtn) {
                floatCaptureBtn = [UIButton buttonWithType:UIButtonTypeCustom];
                floatCaptureBtn.frame = CGRectMake(keyWindow.bounds.size.width - 80, 150, 65, 65);
                floatCaptureBtn.backgroundColor = [UIColor colorWithRed:0.0 green:0.55 blue:1.0 alpha:0.9];
                [floatCaptureBtn setTitle:@"CHỤP" forState:UIControlStateNormal];
                [floatCaptureBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
                floatCaptureBtn.titleLabel.font = [UIFont boldSystemFontOfSize:14];
                floatCaptureBtn.layer.cornerRadius = 32.5;
                floatCaptureBtn.layer.shadowColor = [UIColor blackColor].CGColor;
                floatCaptureBtn.layer.shadowOffset = CGSizeMake(0, 3);
                floatCaptureBtn.layer.shadowOpacity = 0.4;
                floatCaptureBtn.layer.shadowRadius = 5;
                
                [floatCaptureBtn addTarget:nil action:@selector(captureAction) forControlEvents:UIControlEventTouchUpInside];
                
                panHelper = [[FloatButtonPanHelper alloc] init];
                UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:panHelper action:@selector(handlePan:)];
                [floatCaptureBtn addGestureRecognizer:pan];
                
                [keyWindow addSubview:floatCaptureBtn];
            }
            floatCaptureBtn.hidden = NO;
        } else {
            if (floatCaptureBtn) {
                floatCaptureBtn.hidden = YES;
            }
        }
    });
}

void captureAction() {
    captureAndAnalyzeScreen();
}

// Tạo Menu Cài đặt GUI
void createMenuUI() {
    if (menuWindow) return;
    
    UIWindow *keyWindow = getSafestKeyWindow();
    if (!keyWindow) return;
    
    menuWindow = [[UIWindow alloc] initWithFrame:keyWindow.bounds];
    menuWindow.windowLevel = UIWindowLevelAlert + 100;
    menuWindow.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.5];
    menuWindow.hidden = NO;
    
    menuView = [[UIView alloc] initWithFrame:CGRectMake(40, 100, keyWindow.bounds.size.width - 80, 360)];
    menuView.backgroundColor = [UIColor colorWithRed:0.12 green:0.12 blue:0.15 alpha:0.95];
    menuView.layer.cornerRadius = 20;
    menuView.layer.borderWidth = 1;
    menuView.layer.borderColor = [UIColor colorWithRed:0.3 green:0.3 blue:0.3 alpha:1.0].CGColor;
    [menuWindow addSubview:menuView];
    
    UILabel *titleLbl = [[UILabel alloc] initWithFrame:CGRectMake(20, 20, menuView.bounds.size.width - 40, 30)];
    titleLbl.text = @"Cốc Cốc AI Assistant";
    titleLbl.textColor = [UIColor whiteColor];
    titleLbl.font = [UIFont boldSystemFontOfSize:18];
    titleLbl.textAlignment = NSTextAlignmentCenter;
    [menuView addSubview:titleLbl];
    
    apiKeyField = [[UITextField alloc] initWithFrame:CGRectMake(20, 70, menuView.bounds.size.width - 40, 44)];
    apiKeyField.backgroundColor = [UIColor colorWithRed:0.2 green:0.2 blue:0.25 alpha:1.0];
    apiKeyField.textColor = [UIColor whiteColor];
    apiKeyField.placeholder = @" Nhập Gemini API Key...";
    apiKeyField.font = [UIFont systemFontOfSize:14];
    apiKeyField.layer.cornerRadius = 10;
    apiKeyField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 44)];
    apiKeyField.leftViewMode = UITextFieldViewModeAlways;
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *savedKey = [defaults stringForKey:@"GeminiAPIKey"];
    if (savedKey) apiKeyField.text = savedKey;
    [menuView addSubview:apiKeyField];
    
    UILabel *switchLbl = [[UILabel alloc] initWithFrame:CGRectMake(20, 130, menuView.bounds.size.width - 100, 30)];
    switchLbl.text = @"Hiện nút nổi 'CHỤP'";
    switchLbl.textColor = [UIColor whiteColor];
    switchLbl.font = [UIFont systemFontOfSize:15];
    [menuView addSubview:switchLbl];
    
    UISwitch *toggleSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(menuView.bounds.size.width - 80, 130, 50, 30)];
    [toggleSwitch setOn:YES];
    [toggleSwitch addTarget:nil action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
    [menuView addSubview:toggleSwitch];
    
    UIButton *saveBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    saveBtn.frame = CGRectMake(20, 185, menuView.bounds.size.width - 40, 44);
    saveBtn.backgroundColor = [UIColor colorWithRed:0.0 green:0.47 blue:1.0 alpha:1.0];
    [saveBtn setTitle:@"Lưu API Key" forState:UIControlStateNormal];
    [saveBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    saveBtn.titleLabel.font = [UIFont boldSystemFontOfSize:15];
    saveBtn.layer.cornerRadius = 10;
    [saveBtn addTarget:nil action:@selector(saveApiKeyAction) forControlEvents:UIControlEventTouchUpInside];
    [menuView addSubview:saveBtn];
    
    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.frame = CGRectMake(20, 245, menuView.bounds.size.width - 40, 44);
    closeBtn.backgroundColor = [UIColor colorWithRed:0.8 green:0.2 blue:0.2 alpha:1.0];
    [closeBtn setTitle:@"Đóng Menu" forState:UIControlStateNormal];
    [closeBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    closeBtn.titleLabel.font = [UIFont boldSystemFontOfSize:15];
    closeBtn.layer.cornerRadius = 10;
    [closeBtn addTarget:nil action:@selector(closeMenuAction) forControlEvents:UIControlEventTouchUpInside];
    [menuView addSubview:closeBtn];
}

void switchChanged(UISwitch *sender) {
    toggleFloatButton(sender.isOn);
}

void saveApiKeyAction() {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:apiKeyField.text forKey:@"GeminiAPIKey"];
    [defaults synchronize];
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Thành công" message:@"Đã lưu Gemini API Key!" preferredStyle:UIAlertControllerStyleAlert];
    UIWindow *rootWin = getSafestKeyWindow();
    [rootWin.rootViewController presentViewController:alert animated:YES completion:nil];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [alert dismissViewControllerAnimated:YES completion:nil];
    });
}

void closeMenuAction() {
    if (menuWindow) {
        menuWindow.hidden = YES;
        menuWindow = nil;
        menuView = nil;
    }
}

void toggleMenu() {
    if (menuWindow) {
        closeMenuAction();
    } else {
        createMenuUI();
    }
}

void showResultPopup(NSString *text, BOOL isLoading) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *keyWindow = getSafestKeyWindow();
        if (!keyWindow) return;
        
        if (!resultContainer) {
            resultContainer = [[UIView alloc] initWithFrame:CGRectMake(20, 120, keyWindow.bounds.size.width - 40, keyWindow.bounds.size.height - 240)];
            resultContainer.backgroundColor = [UIColor colorWithRed:0.1 green:0.1 blue:0.12 alpha:0.95];
            resultContainer.layer.cornerRadius = 16;
            resultContainer.layer.borderWidth = 1.5;
            resultContainer.layer.borderColor = [UIColor colorWithRed:0.0 green:0.55 blue:1.0 alpha:1.0].CGColor;
            
            resultTextView = [[UITextView alloc] initWithFrame:CGRectMake(15, 15, resultContainer.bounds.size.width - 30, resultContainer.bounds.size.height - 75)];
            resultTextView.backgroundColor = [UIColor clearColor];
            resultTextView.textColor = [UIColor whiteColor];
            resultTextView.font = [UIFont systemFontOfSize:16];
            resultTextView.editable = NO;
            [resultContainer addSubview:resultTextView];
            
            UIButton *closeResBtn = [UIButton buttonWithType:UIButtonTypeSystem];
            closeResBtn.frame = CGRectMake(15, resultContainer.bounds.size.height - 50, resultContainer.bounds.size.width - 30, 40);
            closeResBtn.backgroundColor = [UIColor colorWithRed:0.2 green:0.2 blue:0.25 alpha:1.0];
            [closeResBtn setTitle:@"Đóng kết quả" forState:UIControlStateNormal];
            [closeResBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            closeResBtn.titleLabel.font = [UIFont boldSystemFontOfSize:15];
            closeResBtn.layer.cornerRadius = 10;
            [closeResBtn addTarget:nil action:@selector(closeResultAction) forControlEvents:UIControlEventTouchUpInside];
            [resultContainer addSubview:closeResBtn];
            
            [keyWindow addSubview:resultContainer];
        }
        
        resultContainer.hidden = NO;
        resultTextView.text = text;
    });
}

void closeResultAction() {
    if (resultContainer) {
        resultContainer.hidden = YES;
    }
}

void captureAndAnalyzeScreen() {
    UIWindow *keyWindow = getSafestKeyWindow();
    if (!keyWindow) return;
    
    UIGraphicsBeginImageContextWithOptions(keyWindow.bounds.size, NO, [UIScreen mainScreen].scale);
    [keyWindow drawViewHierarchyInRect:keyWindow.bounds afterScreenUpdates:YES];
    UIImage *screenshot = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    if (!screenshot) return;
    
    NSData *imageData = UIImageJPEGRepresentation(screenshot, 0.7);
    NSString *base64Image = [imageData base64EncodedStringWithOptions:0];
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *apiKey = [defaults stringForKey:@"GeminiAPIKey"];
    if (!apiKey || apiKey.length == 0) {
        showResultPopup(@"Lỗi: Chưa nhập Gemini API Key!\nHãy chạm 3 lần vào màn hình để mở menu cài đặt.", NO);
        return;
    }
    
    showResultPopup(@"Đang gửi ảnh màn hình cho AI Gemini phân tích...", YES);
    
    NSString *urlString = [NSString stringWithFormat:@"https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=%@", apiKey];
    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    
    NSDictionary *jsonBody = @{
        @"contents": @[
            @{
                @"parts": @[
                    @{@"text": @"Hãy phân tích bức ảnh này (đây là màn hình trình duyệt chứa câu hỏi trắc nghiệm hoặc bài tập). Hãy tìm câu hỏi và đưa ra ĐÁP ÁN ĐÚNG chính xác nhất, kèm giải thích cực kỳ ngắn gọn, dễ hiểu bằng tiếng Việt."},
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
    NSData *bodyData = [NSJSONSerialization dataWithJSONObject:jsonBody options:0 error:&error];
    if (error) {
        showResultPopup([NSString stringWithFormat:@"Lỗi tạo JSON: %@", error.localizedDescription], NO);
        return;
    }
    [request setHTTPBody:bodyData];
    
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                showResultPopup([NSString stringWithFormat:@"Lỗi kết nối mạng: %@", error.localizedDescription], NO);
                return;
            }
            
            NSError *jsonError;
            NSDictionary *jsonRes = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
            if (jsonError) {
                showResultPopup(@"Lỗi đọc dữ liệu phản hồi từ server.", NO);
                return;
            }
            
            NSArray *candidates = jsonRes[@"candidates"];
            if (candidates && candidates.count > 0) {
                NSDictionary *firstCandidate = candidates[0];
                NSDictionary *content = firstCandidate[@"content"];
                NSArray *parts = content[@"parts"];
                if (parts && parts.count > 0) {
                    NSString *answerText = parts[0][@"text"];
                    if (answerText) {
                        showResultPopup(answerText, NO);
                        return;
                    }
                }
            }
            
            NSDictionary *errDict = jsonRes[@"error"];
            if (errDict) {
                showResultPopup([NSString stringWithFormat:@"Gemini API Error: %@", errDict[@"message"]], NO);
            } else {
                showResultPopup(@"Không tìm thấy đáp án hoặc phản hồi trống.", NO);
            }
        });
    }];
    [task resume];
}

// Lắng nghe thông báo app chạy xong để gắn gesture an toàn tuyệt đối
__attribute__((constructor)) static void entry() {
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = getSafestKeyWindow();
            if (keyWindow) {
                UITapGestureRecognizer *tripleTap = [[UITapGestureRecognizer alloc] initWithTarget:[TweakGestureHelper sharedInstance] action:@selector(handleTripleTap:)];
                tripleTap.numberOfTapsRequired = 3;
                tripleTap.numberOfTouchesRequired = 1;
                [keyWindow addGestureRecognizer:tripleTap];
                
                toggleFloatButton(YES);
            }
        });
    }];
}
