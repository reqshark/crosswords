//
//  MPWAbstractCGContext.m
//  EGOS
//
//  Created by Marcel Weiher on 1/2/13.
//
//

#import "MPWAbstractCGContext.h"
#import "MPWDrawingContext.h"
#import <CoreText/CoreText.h>
#include <objc/runtime.h>


@protocol DrawingContextRealArray <NSObject>

-(void)getReals:(float*)reals length:(int)arrayLength;
-(float)realAtIndex:(int)anIndex;

@end


#if NS_BLOCKS_AVAILABLE

@implementation MPWDrawingCommands


-(id)initWithBlock:(DrawingBlock)aBlock
{
    self=[super init];
    block=[aBlock retain];
    return self;
}

-(void)setSize:(NSSize)newSize
{
    size=newSize;
}

-(void)drawOnContext:(id)aContext
{
    [block drawOnContext:aContext];
}

-(void)dealloc
{
    [block release];
    [super dealloc];
}

@end

#endif


@implementation MPWAbstractCGContext

#if NS_BLOCKS_AVAILABLE
+(void)initialize
{
    static int initialized=NO;
    if  ( !initialized) {
        Class blockClass=NSClassFromString(@"NSBlock");
        IMP theImp=imp_implementationWithBlock( ^(id blockSelf, id aContext){ ((DrawingBlock)blockSelf)(aContext); } );
        class_addMethod(blockClass, @selector(drawOnContext:), theImp, "v@:@");
        initialized=YES;
    }
}
#endif

-(int)object:inArray toFloats:(float *)floatArray maxCount:(int)maxCount
{
    int arrayLength = 1;
    int numConverted=arrayLength;
    if ( [inArray respondsToSelector:@selector(count)]) {
        arrayLength=[(NSArray*)inArray count];
        arrayLength=MIN(arrayLength,maxCount);
        numConverted=arrayLength;
        if ( [inArray respondsToSelector:@selector(getReals:length:)] ) {
            float reals[arrayLength];
            [inArray getReals:reals length:arrayLength];
            for (int i=0;i<arrayLength; i++) {
                floatArray[i]=reals[i];
            }
        } else if ( [inArray respondsToSelector:@selector(realAtIndex:)] ) {
            for (int i=0;i<arrayLength; i++) {
                floatArray[i]=[inArray realAtIndex:i];
            }
        } else if ( [inArray respondsToSelector:@selector(objectAtIndex:)] &&
                   [[inArray objectAtIndex:0] respondsToSelector:@selector(floatValue)]) {
            for (int i=0;i<arrayLength; i++) {
                floatArray[i]=[[inArray objectAtIndex:i] floatValue];
            }
        } else {
            numConverted=0;
        }
    } else {
        floatArray[0]=[inArray floatValue];
    }
    return numConverted;
}

-color:(CGFloat*)components count:(int)numComponents
{
    CGColorSpaceRef colorSpace=NULL;
    switch (numComponents) {
        case 2:
            colorSpace=CGColorSpaceCreateDeviceGray();
            break;
        case 4:
            colorSpace=CGColorSpaceCreateDeviceRGB();
            break;
        case 5:
            colorSpace=CGColorSpaceCreateDeviceCMYK();
            break;
        default:
            break;
    }
    return [(id)CGColorCreate(colorSpace,components) autorelease];
    
}

-(id)colorRed:(float)r green:(float)g blue:(float)b alpha:(float)alpha
{
    CGFloat components[]={r,g,b,alpha};
    return [self color:components count:4];
}

-(id)colorCyan:(float)c magenta:(float)m yellow:(float)y black:(float)k alpha:(float)alpha
{
    CGFloat components[]={c,m,y,k,alpha};
    return [self color:components count:5];
}

-(id)colorGray:(float)gray alpha:(float)alpha
{
    CGFloat components[]={gray,alpha};
    return [self color:components count:2];
}

-colors:(NSArray*)arrayOfComponentArrays
{
    NSMutableArray *colorArray=[NSMutableArray array];
    int numColors=0;
    int numComponents=[arrayOfComponentArrays count];
    
    for ( id colorComponentArrayOrNumber in arrayOfComponentArrays ) {
        int thisCount = [colorComponentArrayOrNumber respondsToSelector:@selector(count)] ? [(NSArray*)colorComponentArrayOrNumber count]:1 ;
        numColors=MAX(numColors,thisCount);
    }
    for ( int i=0;i<numColors;i++){
        CGFloat components[5]={0,0,0,0,0};
        for (int componentIndex = 0;componentIndex < numComponents; componentIndex++ ) {
            id currentComponent=[arrayOfComponentArrays objectAtIndex:componentIndex];
            if ( [currentComponent respondsToSelector:@selector(count)] ) {
                int sourceIndex=MIN([(NSArray*)currentComponent count]-1,i);
                if ( [currentComponent respondsToSelector:@selector(realAtIndex:)] ) {
                    components[componentIndex]=[currentComponent realAtIndex:sourceIndex];
                } else {
                    components[componentIndex]=[[currentComponent objectAtIndex:sourceIndex] doubleValue];
                }
            } else {
                components[componentIndex]=[currentComponent doubleValue];
            }
        }
        [colorArray addObject:[self color:components count:numComponents]];
    }
    return colorArray;
}

-(NSArray*)colorsRed:red green:green blue:blue alpha:alpha
{
    return [self colors:[NSArray arrayWithObjects:red,green,blue,alpha, nil]];
}

-(NSArray*)colorsCyan:(id)c magenta:(id)m yellow:(id)y black:(id)k alpha:(id)alpha
{
    return [self colors:[NSArray arrayWithObjects:c,m,y,k,alpha, nil]];
}

-(NSArray*)colorsGray:gray alpha:alpha
{
    return [self colors:[NSArray arrayWithObjects:gray,alpha, nil]];
}



#define POINTARGMETHOD( methodName ) \
-methodName:(float)x :(float)y {return self; }\
-methodName:aPoint \
{\
float coords[2];\
int numCoords=[self object:aPoint toFloats:coords maxCount:2];\
if ( numCoords==1 ) {\
     coords[1]=coords[0];\
}\
return [self methodName:coords[0] :coords[1]];\
}\

POINTARGMETHOD(translate)
POINTARGMETHOD(scale)
POINTARGMETHOD(moveto)
POINTARGMETHOD(lineto)

-concat:(float)m11 :(float)m12  :(float)m21  :(float)m22  :(float)tx  :(float)ty { return self; }

-concat:someArray
{
    float a[6];
    NSAssert2( [someArray count] == 6, @"concat %@ expects 6-element array, got %d",someArray,(int)[someArray count] );
    [self object:someArray toFloats:a maxCount:6];
    [self concat:a[0] :a[1] :a[2] :a[3] :a[4] :a[5]];
    return self;
}

-(void)drawBitmapImage:anImage
{
}

-(void*)context { return NULL; }

-drawImage:(id)anImage
{
    if ( [anImage respondsToSelector:@selector(CGImage)] ){
        [self drawBitmapImage:anImage];
    } else if ( [anImage respondsToSelector:@selector(drawOnContext:) ] ) {
        [anImage drawOnContext:self];
    } else if ( [anImage respondsToSelector:@selector(renderInContext:)]) {
        [anImage renderInContext:[self context]];
    }
    return self;
}

-currentFont  { return nil; }
-(void)drawTextLine:(CTLineRef)l {}

-showAttributedString:(NSAttributedString*)someText
{
    CTLineRef line = CTLineCreateWithAttributedString((CFAttributedStringRef) someText);
    [self drawTextLine:line];
    if ( line) {
        CFRelease(line);
    }
    return self;
}

-show:(NSAttributedString*)someText
{
    if ( [someText isKindOfClass:[NSString class]]) {
        NSMutableDictionary *attrs=[NSMutableDictionary dictionaryWithCapacity:4];
        if ( [self currentFont] ) {
            id  ctFont=[self currentFont];           // assumes current font is a CTFont/NSFont
            [attrs setObject:ctFont forKey:@"NSFont"];
            [attrs setObject:ctFont forKey:@"CTFont"];
        }
        [attrs setObject:[NSNumber numberWithBool:YES] forKey:(id)kCTForegroundColorFromContextAttributeName];
        someText=[[[NSAttributedString alloc] initWithString:(NSString*)someText attributes:attrs] autorelease];
    }
    [self showAttributedString:someText];
    return self;
}

-fontWithName:(NSString*)name size:(float)size
{
    return (id) CTFontCreateWithName ( (CFStringRef) name,(CGFloat) size, NULL );
}





#if NS_BLOCKS_AVAILABLE

-(id)setShadowOffset:(NSSize)offset blur:(float)blur color:aColor
{
    return self;
}

-(id)clearShadow
{
    return self;
}

-withShadowOffset:(NSSize)offset blur:(float)blur color:aColor draw:(DrawingBlock)commands
{
    @try {
        [self setShadowOffset:offset blur:blur color:aColor];
        [commands drawOnContext:self];
    }
    @finally {
        [self clearShadow];
    }
    return self;
}



-(id)drawLater:(DrawingBlock)commands
{
    return [[[MPWDrawingCommands alloc] initWithBlock:commands] autorelease];
}

-(void)gsave {}
-(void)grestore {}

-ingsave:(DrawingBlock)block
{
    @try {
        [self gsave];
        [block drawOnContext:self];
    } @finally {
        [self grestore];
    }
    return self;
}


-laterWithSize:(NSSize)size content:(DrawingBlock)drawingCommands
{
    MPWDrawingCommands* later = [self drawLater:drawingCommands];
    [later setSize:size];
    return later;
}



-page:(NSDictionary*)parameters content:(DrawingBlock)drawingCommands
{
    [drawingCommands drawOnContext:self];
    return self;
}

-(void)beginTransparencyLayer {}
-(void)endTransparencyLayer {}
-(void)setAlpha:(float)newAlpha {}

-alpha:(float)alpha forTransparencyLayer:(DrawingBlock)drawingCommands
{
    [self gsave];
    [self setAlpha:alpha];
    [self beginTransparencyLayer];
    @try {
        [drawingCommands drawOnContext:self];
    }
    @finally {
        [self endTransparencyLayer];
        [self grestore];
    }
    return self;
}

#endif

@end

#if 0
#import <MPWFoundation/MPWFoundation.h>

@implementation MPWAbstractCGContext(testing)

+(void)testGetFloats
{
    MPWAbstractCGContext *c=[[[self alloc] init] autorelease];
    MPWPoint *p = [MPWPoint pointWithX:20 y:30];
    NSArray *a=@[ @1, @10, @"3", @42 ];
    NSNumber *b=@22;
    float f[20];
    [c object:p toFloats:f maxCount:10];
    FLOATEXPECT(f[0], 20, @"x");
    FLOATEXPECT(f[1], 30, @"y");
    [c object:a toFloats:f maxCount:10];
    FLOATEXPECT(f[0],1, @"first");
    FLOATEXPECT(f[1], 10, @"second");
    FLOATEXPECT(f[2], 3, @"second");
    FLOATEXPECT(f[3], 42, @"second");
    INTEXPECT( [c object:b toFloats:f maxCount:10], 1, @"only number" );
    FLOATEXPECT(f[0],22, @"first");
 }


+testSelectors {
    return @[
        @"testGetFloats",
    ];
}

@end
#endif
