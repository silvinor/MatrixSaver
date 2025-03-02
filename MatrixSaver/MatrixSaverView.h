//
//  MatrixSaverView.h
//  MatrixSaver
//

#import <Cocoa/Cocoa.h>
#import <ScreenSaver/ScreenSaver.h>

#define GAP 2
#define FONT_NAME "M PLUS 1 Code" // this the font name
#define FONT_FILE_NAME "font.ttf" // the font file to load file
#define FONT_WEIGHT 700           // font weight to load / set self.font to
#define TRAIL_LENGTH 24
#define SPAWN_RATE 4
#define SPAWN_COUNT 2
#define SPEED_MIN 3
#define SPEED_MAX 7
#define SPEED_MULTIPLIER 2
#define FRAMES_PER_SEC 60
#define FONT_SIZE_MINI 6
#define FONT_SIZE_FULL 18
#define MAX_TRAILS 150
#define CHAR_SWAP_CHANCE 50
#define CHAR_SWAP_RATIO 3

@interface Trail : NSObject
  @property (nonatomic, assign) NSInteger n;         // Item index, only used in debugging
  @property (nonatomic, assign) NSInteger column;    // Column where the trail is active
  //// @property (nonatomic, assign) NSInteger rowsDrawn; // Number of rows drawn so far  // TODO : DELETE !!
  @property (nonatomic, assign) NSInteger atRow;     // Y position of begining of trail
  @property (nonatomic, assign) NSInteger length;    // Length of the trail
  @property (nonatomic, assign) NSInteger speed;     // Increment by, a.k.a. Speed
  @property (nonatomic, assign) BOOL active;         // Whether the trail is active
  @property (nonatomic, strong) NSString *content;   // content of the trail
@end

@interface MatrixSaverView : ScreenSaverView
  @property (nonatomic, strong) NSMutableArray<Trail *> *trails; // Array of trails
  @property (nonatomic, assign) BOOL isRunning;                  // Controls animation
@end
