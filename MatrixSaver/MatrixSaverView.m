//
//  MatrixSaverView.m
//  MatrixSaver
//

#import "MatrixSaverView.h"
#import <CoreText/CoreText.h>

#undef DEBUG

/// Define static constant
static NSString *const kCharactersToRemove = @" \n\r\t>*|・。●（）()、#／/\"-一―.：～";

@interface MatrixSaverView ()
// Private vars
@property(nonatomic, assign) CGFloat width;  // Width of screen at `init`
@property(nonatomic, assign) CGFloat height; // Height of screen at `init`
@property(nonatomic, assign) CGFloat charW;  // char width
@property(nonatomic, assign) CGFloat charH;  // char height
@property(nonatomic, assign) CGFloat offsX;  // X offset
@property(nonatomic, assign) CGFloat offsY;  // Y offset
@property(nonatomic, strong) NSFont *font;   // Loaded font
@property(nonatomic, strong) NSString *content; // Holds the content of `content.md`
@property(nonatomic, assign) NSUInteger trailTimer; // Holds the loop count

// Private methods
- (void)loadFont;
- (void)loadContent;
- (void)initializeTrails;
- (void)internalInit;

- (BOOL)isMiniPreview;
- (NSInteger)maxWidth;
- (NSInteger)maxHeight;

- (void)writeCharXYC:(NSString *)s
                   x:(CGFloat)x
                   y:(CGFloat)y
                   c:(NSColor *)c;
- (void)writeCharXYRGBA:(NSString *)s
                      x:(CGFloat)x
                      y:(CGFloat)y
                      r:(CGFloat)r
                      g:(CGFloat)g
                      b:(CGFloat)b
                      a:(CGFloat)a;

- (NSString *)generateTrailContentWithLength:(NSUInteger)length;
- (NSUInteger)collisionDetection:(Trail *)trail;
- (void)startNewTrail:(NSUInteger)length;
- (void)updateTrail:(NSUInteger)nTrail;

#ifdef DEBUG
- (void)debugDumpScreen;
- (void)debugDumpScreen2;
- (void)debugTextXY:(NSColor *)color
                  x:(CGFloat)x 
                  y:(CGFloat)y 
         withFormat:(NSString *)format, ...;
#endif
@end

@implementation Trail
@end

@implementation MatrixSaverView

// =======================================
#pragma mark - Init methods
// =======================================

- (instancetype)initWithFrame:(NSRect)frame isPreview:(BOOL)isPreview {
  // NSLog(@"MatrixSaverView: initWithFrame");
  self = [super initWithFrame:frame isPreview:isPreview];
  if (self) {
    [self internalInit];
  }
  return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
  // NSLog(@"MatrixSaverView: initWithCoder");
  self = [super initWithCoder:coder];
  if (self) {
    [self internalInit];
  }
  return self;
}

- (void)loadFont {
  // NSLog(@"MatrixSaverView: loadFont");

  // Load the font file from the bundle
  NSBundle *screensaverBundle = [NSBundle bundleForClass:[self class]];
  NSString *fontPath = [[screensaverBundle resourcePath] stringByAppendingPathComponent:@FONT_FILE_NAME];
  NSURL *fontURL = [NSURL fileURLWithPath:fontPath];

  CFErrorRef error = NULL;
  if (!CTFontManagerRegisterFontsForURL((__bridge CFURLRef)fontURL, kCTFontManagerScopeProcess, &error)) {
    CFStringRef errorDescription = CFErrorCopyDescription(error);
    // NSLog(@"MatrixSaverView: Failed to register font: %@", (__bridge NSString *)errorDescription);
    CFRelease(errorDescription);
  }

  // ✅ Create font descriptor with font name and weight
  NSFontDescriptor *fontDescriptor = [[NSFontDescriptor fontDescriptorWithName:@FONT_NAME size:12.0]
    fontDescriptorByAddingAttributes:@{
      NSFontWeightTrait: @(FONT_WEIGHT / 1000.0) // Convert weight to trait format
    }];

  // ✅ Create the font using the descriptor
  self.font = [NSFont fontWithDescriptor:fontDescriptor size:12.0];

  // ✅ Fallback to system monospace font if font is not found
  if (!self.font) {
    // NSLog(@"MatrixSaverView: Failed to load font '%s', using system monospace", FONT_NAME);
    self.font = [NSFont monospacedSystemFontOfSize:12.0 weight:NSFontWeightRegular];
  }

  // Get initial text size with default font size
  NSDictionary *attributes = @{NSFontAttributeName : self.font};
  NSSize chr = [@"五" sizeWithAttributes:attributes];

  // ✅ Calculate target font size based on screen width
  CGFloat divisor = [self isMiniPreview] ? COLS_MINI : COLS_FULL;
  CGFloat targetWidth = self.width / divisor;
  CGFloat scaleFactor = round(targetWidth / chr.width);
  CGFloat finalFontSize = round(self.font.pointSize * scaleFactor);
  // NSLog(@"MatrixSaverView: FontSize: %.2f", finalFontSize);

  // ✅ Update font with the final size
  fontDescriptor = [fontDescriptor fontDescriptorWithSize:finalFontSize];
  self.font = [NSFont fontWithDescriptor:fontDescriptor size:finalFontSize];

  // ✅ Calculate character size with final font
  attributes = @{NSFontAttributeName : self.font};
  chr = [@"五" sizeWithAttributes:attributes];
  self.charW = ceil( chr.width ) + GAP;
  self.charH = floor( chr.height ) + GAP ;
  // self.charH = ceil( self.font.ascender + self.font.descender + self.font.leading ) + GAP;

  // NSLog(@"MatrixSaverView: Char size: Width = %.2f, Height = %.2f (ascender: %.2f, descender: %.2f, leading: %.2f) vs. Height = %.2f",
  //       self.charW, self.charH, self.font.ascender, self.font.descender, self.font.leading, chr.height);

  // ✅ Calculate offsets
  CGFloat usedWidth = [self maxWidth] * self.charW;
  CGFloat usedHeight = [self maxHeight] * self.charH;
  // NSLog(@"MatrixSaverView: realW = %.2f, usedW = %.2f, cW = %.2f, .. realH = %.2f, usedH = %.2f, cH = %.2f", self.width, usedWidth, self.charW, self.height, usedHeight, self.charH);

  self.offsX = round((self.width - usedWidth) / 2.0);
  self.offsY = round((self.height - usedHeight) / 2.0);

  // NSLog(@"MatrixSaverView: offsX = %.2f, offsY = %.2f", self.offsX, self.offsY);
}

- (void)loadContent {
  // NSLog(@"MatrixSaverView: loadContent");

  // Locate `content.md` in the bundle
  NSBundle *screensaverBundle = [NSBundle bundleForClass:[self class]];
  NSString *contentPath = [[screensaverBundle resourcePath]
    stringByAppendingPathComponent:@"content.md"];

  // Check if file exists
  if (![[NSFileManager defaultManager] fileExistsAtPath:contentPath]) {
    // NSLog(@"MatrixSaverView: ERROR: content.md not found at path: %@",
    //   contentPath);
    self.content = @"";
    return;
  }

  NSError *error = nil;
  NSString *fileContents =
    [NSString stringWithContentsOfFile:contentPath
                              encoding:NSUTF8StringEncoding
                                 error:&error];

  if (error) {
    // NSLog(@"MatrixSaverView: ERROR: Failed to read content.md: %@",
    //   [error localizedDescription]);
    self.content = @"";
    return;
  }

  // Strip unwanted characters using predefined constant
  NSCharacterSet *removeSet =
    [NSCharacterSet characterSetWithCharactersInString:kCharactersToRemove];
  self.content = [[fileContents componentsSeparatedByCharactersInSet:removeSet]
    componentsJoinedByString:@""];

  // NSLog(@"MatrixSaverView: Loaded and cleaned content.md successfully (Length: "
  //   @"%lu)",
  //   (unsigned long)[self.content length]);
}

- (void)initializeTrails {
  self.trails = [NSMutableArray array];
  for (NSUInteger i = 0; i < MAX_TRAILS; i++) {
    Trail *trail = [[Trail alloc] init];
    trail.n = i;
    trail.active = NO;

    [self.trails addObject:trail];
  }
}

- (void)internalInit {
  // NSLog(@"MatrixSaverView: internalInit");

  // ----- Initialize RandomSeed -----

  // Use the current time to set a unique seed
  srand((unsigned int)time(NULL));   // used by `rand()`
  srandom((unsigned int)time(NULL)); // used by `random()`

  // ----- Get the size of the screen -----

  self.width = self.bounds.size.width;
  if (self.width <= 0) {
    self.width = 1;
  }
  self.height = self.bounds.size.height;
  if (self.height <= 0) {
    self.width = 1;
  }

  // NSLog(@"MaxtrixSaverView internalInit self.width = %ld, self.height = %ld",
  //   (long)self.width, (long)self.height);

  // ----- Load the font and content -----

  [self loadFont];
  [self loadContent];
  [self initializeTrails];

  // ----- Set the timer -----

  self.trailTimer = 0;
  NSTimeInterval interval = 1.0 / FRAMES_PER_SEC;
  [self setAnimationTimeInterval:interval];
}

// ==================================================
#pragma mark - Private Helper Methods
// ==================================================

/* ------------------------------
 * Assess if in System Preferences mini view
 * ------------------------------ */
- (BOOL)isMiniPreview {
  return self.isPreview && (self.bounds.size.width < 640);
}

- (NSInteger)maxWidth {
  if (self.width == 0 || self.charW == 0) { return 0; }
  return (NSInteger)floor(self.width / self.charW);
}

- (NSInteger)maxHeight {
  if (self.height == 0 || self.charH == 0) { return 0; }
  return (NSInteger)floor(self.height / self.charH);
}

- (void)writeCharXYC:(NSString *)s
                   x:(CGFloat)x
                   y:(CGFloat)y
                   c:(NSColor *)c {

  if (!self.font || s.length == 0) {
    // NSLog(@"MatrixSaverView: Font not set or invalid character.");
    return;
  }

  // Create text attributes dictionary
  NSDictionary *attributes = @{
    NSFontAttributeName: self.font,
    NSForegroundColorAttributeName: c
  };

  NSSize z = [s sizeWithAttributes:attributes];
  NSInteger wO = round(((self.charW - GAP) - z.width) / 2);

  CGFloat adjustedX = x * self.charW;
  CGFloat adjustedY = y * self.charH;  

  adjustedX += (self.offsX + wO);
  // adjustedY -= (self.offsY + GAP);

  // invert Y as maxOS has Y=0 at bottom, we want to draw from top
  adjustedY = self.bounds.size.height - adjustedY - z.height /* (self.charH - GAP) */;

  // Draw the character at the computed position
  [s drawAtPoint:NSMakePoint(adjustedX, adjustedY) withAttributes:attributes];
}

- (void)writeCharXYRGBA:(NSString *)s
                      x:(CGFloat)x
                      y:(CGFloat)y
                      r:(CGFloat)r
                      g:(CGFloat)g
                      b:(CGFloat)b
                      a:(CGFloat)a {
    
  if (!self.font || s.length == 0) {
    // NSLog(@"MatrixSaverView: Font not set or invalid character.");
    return;
  }

  // Create NSColor from RGB values
  NSColor *charColor = [[NSColor colorWithRed:r green:g blue:b alpha:a] colorUsingColorSpace:[NSColorSpace sRGBColorSpace]];

  [self writeCharXYC:s
                   x:x
                   y:y
                   c:charColor];
}

- (NSString *)generateTrailContentWithLength:(NSUInteger)length {
  // If content is empty, return a string of "E" characters
  if (self.content.length == 0) {
    // NSLog(@"MatrixSaverView: WARNING: Content is empty, filling with 'E'");
    return [@"" stringByPaddingToLength:length
                             withString:@"E"
                        startingAtIndex:0];
  }

  // Generate a random substring of `length` characters
  NSMutableString *trailString = [NSMutableString stringWithCapacity:length];
  for (NSUInteger i = 0; i < length; i++) {
    NSUInteger randomIndex = arc4random_uniform((uint32_t)self.content.length);
    NSString *randomChar =
      [self.content substringWithRange:NSMakeRange(randomIndex, 1)];
    [trailString appendString:randomChar];
  }

  return [trailString copy]; // Return an immutable copy to ensure proper memory handling
}

- (NSUInteger)collisionDetection:(Trail *)trail {
  NSUInteger result = 0;
  for (NSUInteger i = 0; i < MAX_TRAILS; i++) {
    Trail *victim = self.trails[i];
    if (victim && victim.active && (victim.column == trail.column)) {
      
      NSUInteger trailNextRow = trail.rowsDrawn + trail.speed;
      NSUInteger victimEndRow = victim.rowsDrawn - victim.length;  // bottom of victim trail
      NSUInteger victimStartRow = victim.rowsDrawn; // top of victim trail
      
      if (
        // ✅ Case 1: New trail is being created and starts in the middle of an existing trail
        ((trail.rowsDrawn == 0) && (victimStartRow >= 0) && (trail.rowsDrawn <= victimEndRow))
        ||
        // ✅ Case 2: Trail is moving faster and might catch up
        ((trail.speed > victim.speed) && (trailNextRow >= victimEndRow))
      ) {
        if (result == 0 || victim.speed < result) {
          result = victim.speed; // Track slowest victim speed
        }
      }
    }
  }
  return result;
}

- (void)startNewTrail:(NSUInteger)length {
  Trail *newTrail = nil;

  // Find an inactive trail
  for (NSUInteger i = 0; i < MAX_TRAILS; i++) {
    if (!self.trails[i].active) {
      newTrail = self.trails[i];
      break;
    }
  }

  // No available trail slot
  if (!newTrail) { return; } 

  newTrail.speed = arc4random_uniform(SPEED_MAX) + 1;
  newTrail.rowsDrawn = 0; // Start with no rows drawn, MUST set for collision detection

  NSUInteger maxTries = 5;
  for (NSUInteger attempt = 0; attempt < maxTries; attempt++) {
    newTrail.column = arc4random_uniform( (uint32_t)[self maxWidth] );

    if (0 == [self collisionDetection:newTrail]) {
      newTrail.length = (length / 2) + arc4random_uniform((uint32_t)((length / 2) + 1));
      newTrail.content = [self generateTrailContentWithLength:newTrail.length];
      // NSLog(@"MatrixSaverView: Content = %s", newTrail.content);
      newTrail.active = YES;
      return; // Successfully created, exit function
    }
  }
}

#ifdef DEBUG
- (void)debugDumpScreen {
  NSRect rect = NSMakeRect(0, 0, self.width, self.height);
  [[NSColor colorWithRed:0.3 green:0.3 blue:0.3 alpha:1.0] setFill]; // NOT BLACK !!
  NSRectFill(rect);

  NSUInteger rows = [self maxHeight];
  NSUInteger cols = [self maxWidth];

  NSString *charToDraw = @"撲";
  for (NSUInteger y = 0; y < rows; y++) {
    for (NSUInteger x = 0; x < cols; x++) {
      if ((x == y) && (x < 10)) {
        NSString *tempChar = [NSString stringWithFormat:@"%ld", (long)x]; // If `x` is an integer
        [self writeCharXYRGBA:tempChar 
                            x:x
                            y:y
                            r:0.0
                            g:(183 / 255.0)
                            b:(235 / 255.0)
                            a:1.0];
      } else {
        [self writeCharXYRGBA:charToDraw
                            x:x
                            y:y
                            r:(127 / 255.0)
                            g:1.0
                            b:0.0
                            a:1.0];
      }
    }
  }
}
#endif

#ifdef DEBUG
- (void)debugDumpScreen2 {
  NSUInteger rows = [self maxHeight];
  NSUInteger cols = [self maxWidth];

  NSString *s;

  CGFloat sz = self.font.pointSize;
  s = [NSString stringWithFormat:@"%f", sz];
  [self writeCharXYC:s
                   x:3
                   y:3
                   c:[NSColor whiteColor]];
  
  // over the top
  for (NSUInteger x = 0; x < cols; x++) {
    s = [NSString stringWithFormat:@"%lu", (x % 100) / 10];
    [self writeCharXYC:s
                     x:x
                     y:0
                     c:[NSColor redColor]];
    s = [NSString stringWithFormat:@"%lu", x % 10];
    [self writeCharXYC:s
                     x:x
                     y:1
                     c:[NSColor redColor]];
  }
  // down the side
  for (NSUInteger y = 0; y < rows; y++) {
    s = [NSString stringWithFormat:@"%lu", y % 10];
    [self writeCharXYC:s
                     x:0
                     y:y
                     c:[NSColor redColor]];
  }
}
#endif

#ifdef DEBUG
- (void)debugTextXY:(NSColor *)color
                  x:(CGFloat)x 
                  y:(CGFloat)y 
         withFormat:(NSString *)format, ... {
  if (!format || !color) { return; }

  NSString *formattedString;

  // Process variable arguments (for formatted string)
  va_list args;
  va_start(args, format);
  if ([format containsString:@"%"]) { 
    formattedString = [[NSString alloc] initWithFormat:format arguments:args];
  } else {
    formattedString = format;
  }
  va_end(args);

  // Define text attributes (system monospace font & given color)
  NSDictionary *attributes = @{
      NSFontAttributeName: [NSFont monospacedSystemFontOfSize:18 weight:NSFontWeightRegular],
      NSForegroundColorAttributeName: color
  };

  // Measure text size
  NSSize tSz = [formattedString sizeWithAttributes:attributes];
  y = self.bounds.size.height - y - tSz.height;

  // Draw the text at the computed position
  [formattedString drawAtPoint:NSMakePoint(x, y) withAttributes:attributes];
}
#endif

/** ----------------------------------------
 * Main work horse!!
 * ---------------------------------------- */
- (void)updateTrail:(NSUInteger)nTrail {
  Trail *trail = self.trails[nTrail];

  if (!trail.active) { return; }

  NSUInteger len = MIN(trail.content.length, trail.length);
  // NSLog(@"MatrixSaverView: Content length 1 = %d", len);

  /* Loop over the content and draw it */
  for (NSUInteger i = 0; i < len; i++) {
    // if (i >= len) { break; }

    NSInteger yy = trail.rowsDrawn - i;
    // not visible, so don't draw it
    if (yy < 0 || yy > [self maxHeight]) { continue; }  // todo : use `break` for invisible tails 

    // Extract character
    NSString *s = [trail.content substringWithRange:NSMakeRange(i, 1)];

    // Determine color based on position in the trail
    NSColor *c;
    if (i == 0) {
      c = [NSColor colorWithRed:(0xD6 / 255.0) green:(0xEB / 255.0) blue:(0xDF / 255.0)  // white from icon
      alpha:1.0];
    } else {
      CGFloat a = 1.0;
      if (i >= len - 6) { a = 0.15 * (len - i); }  // dim last 6 chars
      c = [NSColor colorWithRed:(0x25 / 255.0) green:(0xFC / 255.0) blue:(0xB3 / 255.0)  // green from icon
      alpha:a];
    }

    [self writeCharXYC:s
                     x:trail.column
                     y:yy
                     c:c];
  }

  /* 1 in SWAP_CHANCE chance of resetting `trail.content` */
  if (arc4random_uniform(SWAP_CHANCE) == 0) {
    trail.content = [self generateTrailContentWithLength:trail.length];
    // NSLog(@"MatrixSaverView: Reset content for trail %lu", (unsigned long)nTrail);
  }

  NSUInteger collisionSpeed = [self collisionDetection:trail];
  if (collisionSpeed > 0) {
    trail.speed = collisionSpeed;
  }

  trail.rowsDrawn += trail.speed;  // move it by 1 to 3 (speed dependant)

  if (trail.rowsDrawn > ([self maxHeight] + len)) {
  //   // beyond printable area ... kill it
     trail.active = NO;
  }
}

// =======================================
#pragma mark - Key Screen Saver Methods
// =======================================

- (void)startAnimation {
  // NSLog(@"MatrixSaverView: startAnimation");
  [super startAnimation];

  self.isRunning = YES;
  [self setNeedsDisplay:YES];
}

- (void)stopAnimation {
  // NSLog(@"MatrixSaverView: stopAnimation");
  [super stopAnimation];
}

- (void)drawRect:(NSRect)rect {
  [super drawRect:rect];

  //  NSLog(@"MatrixSaverView: drawRect (%ld, %ld, %ld, %ld)",
  //     (long)rect.origin.x,
  //     (long)rect.origin.y,
  //     (long)rect.size.width,
  //     (long)rect.size.height );

  // Ensure a visible background color
  [[NSColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:1.0] setFill]; // BLACK !!
  NSRectFill(rect);

  // Ensure font and content are valid
  if (!self.font || self.content.length == 0) {
    // NSLog(@"MatrixSaverView: No font or empty content, skipping draw");
    return;
  }

  #ifdef DEBUG
  /* [self debugDumpScreen]; */
  [self debugDumpScreen2];

  /* [self debugTextXY:[NSColor redColor]
                    x:20
                    y:20
           withFormat:@"MaxHeight = %3d", self.maxHeight]; */
  #endif

  for (NSUInteger i = 0; i < self.trails.count; i++) {
    #ifdef DEBUG
    // vvvvvvvvvvvvv TODO : DEBUG vvvvvvvvvvvvvvvvv
    Trail *debug = self.trails[i];
    NSUInteger xx = (debug.column * self.charW);
    NSUInteger yy = (debug.rowsDrawn * self.charH);
    if (!debug.active) {
      xx = 20;
      yy = ceil( self.height / MAX_TRAILS ) * i;
    }
    [self debugTextXY:[NSColor redColor]
                    x:xx
                    y:yy
           withFormat:@"Trail %3d col=%3d rows=%3d len=%2d spd=%1d act=%1d str=%@",
             debug.n, debug.column, debug.rowsDrawn, debug.length, debug.speed, debug.active, debug.content];
    // ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    #endif
    
    if (self.trails[i].active) {
      [self updateTrail:i]; // Call updateTrail if active
    }
  }

  // NSLog(@"MatrixSaverView: Finished drawing content");
}

- (void)animateOneFrame {
  // NSLog(@"MatrixSaverView: animateOneFrame");

  if (self.trailTimer % SPAWN_RATE == 0) {
    [self startNewTrail:TRAIL_LENGTH];
  }

  self.trailTimer += 1;
  if (self.trailTimer > SPAWN_RATE * 1000) {
    self.trailTimer = 0;
  }

  [self setNeedsDisplay:YES];
  return;
}

- (BOOL)hasConfigureSheet {
  return NO;
}

- (NSWindow *)configureSheet {
  return nil;
}

@end
