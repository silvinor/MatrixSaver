//
//  MatrixSaverView.h
//  MatrixSaver
//

#import <ScreenSaver/ScreenSaver.h>
#import <Cocoa/Cocoa.h>

#define GAP 2
#define FONT_NAME "M PLUS 1 Code" // this the font name
#define FONT_FILE_NAME "font.ttf" // the font file to load file 
#define FONT_WEIGHT 700 // font weight to load / set self.font to
#define TRAIL_LENGTH 24
#define SPAWN_RATE 1
#define SPEED_MAX 3
#define FRAMES_PER_SEC 8 // 10.0
#define COLS_MINI 25
#define COLS_FULL 110
#define MAX_TRAILS 120
#define SWAP_CHANCE 20

@interface Trail : NSObject 
  @property (nonatomic, assign) NSInteger n;         // Item index, only used in debugging
  @property (nonatomic, assign) NSInteger column;    // Column where the trail is active
  @property (nonatomic, assign) NSInteger rowsDrawn; // Number of rows drawn so far
  @property (nonatomic, assign) NSInteger length;    // Length of the trail
  @property (nonatomic, assign) NSInteger speed;     // Increment by, a.k.a. Speed
  @property (nonatomic, assign) BOOL active;         // Whether the trail is active
  @property (nonatomic, strong) NSString *content;   // content of the trail
@end

@interface MatrixSaverView : ScreenSaverView
  @property (nonatomic, strong) NSMutableArray<Trail *> *trails;  // Array of trails
  @property (nonatomic, assign) BOOL isRunning;             // Controls animation
@end
