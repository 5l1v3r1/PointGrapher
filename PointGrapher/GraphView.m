//
//  GraphView.m
//  PointGrapher
//
//  Created by Alex Nichol on 10/29/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "GraphView.h"

@interface GraphView (Drawing)

- (NSString *)numberStringFromDouble:(double)d;
- (void)drawAxisLines:(CGContextRef)context;
- (void)drawXAxisLabels:(double)increment xAxis:(CGFloat)xAxis yAxis:(CGFloat)yAxis;
- (void)drawYAxisLabels:(double)increment xAxis:(CGFloat)xAxis yAxis:(CGFloat)yAxis;
- (void)drawPoint:(GraphPoint *)aPoint context:(CGContextRef)context;

@end

@implementation GraphView

@synthesize zoomFactor;

- (id)initWithFrame:(NSRect)frame {
	if ((self = [super initWithFrame:frame])) {
		zoomFactor = 1;
		points = [[NSMutableArray alloc] init];
		labelRects = [[RectArray alloc] init];
	}
	return self;
}

#pragma mark Points

- (void)addPoint:(GraphPoint *)point {
	[points addObject:point];
	self.needsDisplay = YES;
}

- (void)removePoint:(GraphPoint *)point {
	[points removeObject:point];
	self.needsDisplay = YES;
}

- (NSArray *)allPoints {
	return (NSArray *)points;
}

#pragma mark Transforming

- (void)setZoomFactor:(CGFloat)factor {
	zoomFactor = factor;
	self.needsDisplay = YES;
}

- (void)centerOrigin {
	translateAxis.x = 0;
	translateAxis.y = 0;
	self.needsDisplay = YES;
}

#pragma mark Graph Points

- (CGPoint)pointForGraphPoint:(GraphPoint *)graphPoint {
	CGFloat xLocation = self.frame.size.width / 2 + translateAxis.x;
	CGFloat yLocation = self.frame.size.height / 2 + translateAxis.y;
	CGFloat pixelsPerPoint = kTickSpacing * zoomFactor;
	CGPoint point = graphPoint.point;
	point.x *= pixelsPerPoint;
	point.y *= pixelsPerPoint;
	point.x += xLocation;
	point.y += yLocation;
	return point;
}

#pragma mark Dragging

- (void)mouseDown:(NSEvent *)theEvent {
	startDrag = [theEvent locationInWindow];
	startTranslate = translateAxis;
}

- (void)mouseDragged:(NSEvent *)theEvent {
	NSPoint offset = [theEvent locationInWindow];
	translateAxis.x = startTranslate.x + (offset.x - startDrag.x);
	translateAxis.y = startTranslate.y + (offset.y - startDrag.y);
	self.needsDisplay = YES;
}

#pragma mark Drawing

- (void)drawRect:(NSRect)dirtyRect {
	CGContextRef context = (CGContextRef)[[NSGraphicsContext currentContext] graphicsPort];
	CGContextSetRGBFillColor(context, 1, 1, 1, 1);
	CGContextFillRect(context, self.bounds);
	// draw the axis
	[labelRects removeAllRects];
	[self drawAxisLines:context];
	CGContextSetRGBFillColor(context, 0, 0, 0, 1);
	for (GraphPoint * point in points) {
		[self drawPoint:point context:context];
	}
}

- (NSString *)numberStringFromDouble:(double)d {
	NSMutableString * doubleString = [NSMutableString stringWithFormat:@"%lf", d];
	while ([doubleString hasSuffix:@"0"]) {
		[doubleString deleteCharactersInRange:NSMakeRange([doubleString length] - 1, 1)];
	}
	if ([doubleString hasSuffix:@"."]) {
		[doubleString deleteCharactersInRange:NSMakeRange([doubleString length] - 1, 1)];
	}
	return doubleString;
}

- (void)drawAxisLines:(CGContextRef)context {
	CGFloat xLocation = floor(self.frame.size.width / 2 + translateAxis.x) + 0.5;
	CGFloat yLocation = floor(self.frame.size.height / 2 + translateAxis.y) + 0.5;
	
	// Grid lines
	CGContextSetLineWidth(context, 1);
	
	// draw vertical lines
	int endX = (int)floor((self.frame.size.width - xLocation) / kTickSpacing);
	int startX = (int)floor(-xLocation / kTickSpacing);
	for (int xTick = startX; xTick <= endX; xTick++) {
		CGFloat vxLocation = (CGFloat)xTick * (CGFloat)kTickSpacing + xLocation;
		const CGPoint segment[2] = {
			{vxLocation, 0},
			{vxLocation, self.frame.size.height}
		};
		CGContextSetRGBStrokeColor(context, 0.8, 0.8, 0.8, 1);
		CGContextStrokeLineSegments(context, segment, 2);
	}
	
	// draw horizontal lines
	int endY = (int)floor((self.frame.size.height - yLocation) / kTickSpacing);
	int startY = (int)floor(-yLocation / kTickSpacing);
	for (int yTick = startY; yTick <= endY; yTick++) {
		CGFloat vyLocation = (CGFloat)yTick * (CGFloat)kTickSpacing + yLocation;
		const CGPoint segment[2] = {
			{0, vyLocation},
			{self.frame.size.width, vyLocation}
		};
		CGContextSetRGBStrokeColor(context, 0.8, 0.8, 0.8, 1);
		CGContextStrokeLineSegments(context, segment, 2);
	}
	
	// Axis markers
	
	CGContextSetLineWidth(context, 2);
	// horizontal axis
	if (yLocation >= 0) {
		const CGPoint segment[2] = {
			{0, floor(yLocation)},
			{self.frame.size.width, floor(yLocation)}
		};
		CGContextSetRGBStrokeColor(context, 0, 0, 0, 1);
		CGContextStrokeLineSegments(context, segment, 2);
	}
	
	// vertical axis
	if (xLocation >= 0) {
		const CGPoint segment[2] = {
			{floor(xLocation), 0},
			{floor(xLocation), self.frame.size.height}
		};
		CGContextSetRGBStrokeColor(context, 0, 0, 0, 1);
		CGContextStrokeLineSegments(context, segment, 2);
	}
	
	[self drawXAxisLabels:(((CGFloat)1.0) / zoomFactor) 
					xAxis:xLocation yAxis:yLocation];
	[self drawYAxisLabels:(((CGFloat)1.0) / zoomFactor) 
					xAxis:xLocation yAxis:yLocation];
}

- (void)drawXAxisLabels:(double)increment xAxis:(CGFloat)xAxis yAxis:(CGFloat)yAxis {
	int backIncrement = 0 - (int)floor(xAxis / kTickSpacing);
	
	// label metrics
	NSDictionary * attributes = [NSDictionary dictionaryWithObject:[NSFont systemFontOfSize:14]
															forKey:NSFontAttributeName];
	
	for (int incrementNumber = backIncrement; 1; incrementNumber++) {
		CGFloat xCoordinate = xAxis + ((CGFloat)incrementNumber * kTickSpacing);
		if (xCoordinate > self.frame.size.width || xCoordinate < 0) break;
		NSString * numberString = [self numberStringFromDouble:(double)incrementNumber * increment];
		NSSize textSize = [numberString sizeWithAttributes:attributes];
		NSRect textFrame = NSMakeRect(0, 0, textSize.width, textSize.height);
		if (yAxis > textSize.height + 4 && yAxis < self.frame.size.height) {
			// draw under the axis
			textFrame.origin.x = xCoordinate + 4;
			textFrame.origin.y = yAxis - (textFrame.size.height + 2);
		} else if (yAxis > 0 && yAxis <= textSize.height + 4) {
			// draw above the axis
			textFrame.origin.x = xCoordinate + 4;
			textFrame.origin.y = yAxis + 2;
		} else if (yAxis <= 0) {
			// draw above the top of the screen
			textFrame.origin.x = xCoordinate + 4;
			textFrame.origin.y = 4;
		} else if (yAxis >= self.frame.size.height) {
			textFrame.origin.x = xCoordinate + 4;
			textFrame.origin.y = self.frame.size.height - (textFrame.size.height + 2);
		}
		[numberString drawInRect:textFrame withAttributes:attributes];
		[labelRects addRect:textFrame];
	}
}

- (void)drawYAxisLabels:(double)increment xAxis:(CGFloat)xAxis yAxis:(CGFloat)yAxis {
	int backIncrement = 0 - (int)floor(yAxis / kTickSpacing);
	
	// label metrics
	NSDictionary * attributes = [NSDictionary dictionaryWithObject:[NSFont systemFontOfSize:14]
															forKey:NSFontAttributeName];
	
	for (int incrementNumber = backIncrement; 1; incrementNumber++) {
		if (incrementNumber == 0) continue;
		CGFloat yCoordinate = yAxis + ((CGFloat)incrementNumber * kTickSpacing);
		if (yCoordinate > self.frame.size.height || yCoordinate < 0) break;
		NSString * numberString = [self numberStringFromDouble:(double)incrementNumber * increment];
		NSSize textSize = [numberString sizeWithAttributes:attributes];
		NSRect textFrame = NSMakeRect(0, 0, textSize.width, textSize.height);
		if (xAxis > textSize.width + 6 && xAxis < self.frame.size.width) {
			// draw under the axis
			textFrame.origin.y = yCoordinate + 4;
			textFrame.origin.x = xAxis - (textFrame.size.width + 6);
		} else if (xAxis > 0 && xAxis <= textSize.width + 6) {
			// draw above the axis
			textFrame.origin.y = yCoordinate + 4;
			textFrame.origin.x = xAxis + 6;
		} else if (xAxis <= 0) {
			// draw above the top of the screen
			textFrame.origin.y = yCoordinate + 4;
			textFrame.origin.x = 6;
		} else if (xAxis >= self.frame.size.width) {
			textFrame.origin.y = yCoordinate + 4;
			textFrame.origin.x = self.frame.size.width - (textFrame.size.width + 6);
		}
		[numberString drawInRect:textFrame withAttributes:attributes];
		[labelRects addRect:textFrame];
	}
}

- (void)drawPoint:(GraphPoint *)aPoint context:(CGContextRef)context {
	__block CGFloat xLocation = self.frame.size.width / 2 + translateAxis.x;
	__block CGFloat yLocation = self.frame.size.height / 2 + translateAxis.y;
	
	__block CGPoint drawPoint = [self pointForGraphPoint:aPoint];
	if (!CGRectContainsPoint(CGRectMake(0, 0, self.frame.size.width, self.frame.size.height), drawPoint)) {
		return;
	}
	
	NSDictionary * attributes = [NSDictionary dictionaryWithObject:[NSFont systemFontOfSize:14]
															forKey:NSFontAttributeName];
	NSSize letterSize = [[aPoint pointName] sizeWithAttributes:attributes];
	
	__block NSRect rect = NSZeroRect;
	rect.size = letterSize;
	
	rect.origin.x = drawPoint.x + 4;
	rect.origin.y = drawPoint.y + 4;
	
	
#define flipXCoord flippedOnX = !flippedOnX;\
if (flippedOnX) {\
rect.origin.x = drawPoint.x - rect.size.width - 4;\
} else {\
rect.origin.x = drawPoint.x + 4;\
}
	
#define flipYCoord flippedOnY = !flippedOnY;\
if (flippedOnY) {\
rect.origin.y = drawPoint.y - rect.size.height;\
} else {\
rect.origin.y = drawPoint.y;\
}
	
	// Here we go through a number of different scenarios for where the label
	// should be. By doing this, we can place the label at a point where it is
	// least likely to interfere with things around it.
	
	BOOL flippedOnX = NO;
	BOOL flippedOnY = NO;
	
	__block BOOL (^doesLabelIntersectVertical)(void) = ^{
		int startLineIndexX = (int)floor(xLocation / kTickSpacing);
		int endIndexX = (int)floor((self.frame.size.width - xLocation) / kTickSpacing);
		for (int lineIndex = -startLineIndexX; lineIndex <= endIndexX; lineIndex++) {
			CGFloat lineX = xLocation + ((CGFloat)lineIndex * kTickSpacing);
			if (lineX > rect.origin.x && lineX < rect.origin.x + rect.size.width) {
				return YES;
			}
		}
		return NO;
	};
	
	__block BOOL (^doesLabelIntersectHorizontall)(void) = ^{
		int startLineIndexY = (int)floor(yLocation / kTickSpacing);
		int endIndexY = (int)floor((self.frame.size.height - yLocation) / kTickSpacing);
		for (int lineIndex = -startLineIndexY; lineIndex <= endIndexY; lineIndex++) {
			CGFloat lineY = yLocation + ((CGFloat)lineIndex * kTickSpacing);
			if (lineY > rect.origin.y && lineY < rect.origin.y + rect.size.height) {
				return YES;
			}
		}
		return NO;
	};
	
	__block BOOL (^doesLabelIntersectLabel)(void) = ^{
		for (NSUInteger rectIndex = 0; rectIndex < [labelRects numberOfRects]; rectIndex++) {
			NSRect textRect = [labelRects rectAtIndex:rectIndex];
			CGRect textCG = NSRectToCGRect(textRect);
			if (CGRectIntersectsRect(textCG, NSRectToCGRect(rect))) {
				return YES;
			}
		}
		return NO;
	};
	
	BOOL (^doesLabelOverlapElements)(void) = ^{
		if (doesLabelIntersectLabel() || doesLabelIntersectHorizontall() || doesLabelIntersectVertical()) {
			return YES;
		}
		return NO;
	};
	
	BOOL flipCoordinatesNoLines = NO;
	
	if (doesLabelOverlapElements()) {
		flipXCoord;
		if (doesLabelOverlapElements()) {
			flipYCoord;
			if (doesLabelOverlapElements()) {
				flipXCoord;
				if (doesLabelOverlapElements()) {
					flipCoordinatesNoLines = YES;
				}
			}
		}
	}
	
	if (flipCoordinatesNoLines) {
		if (doesLabelIntersectLabel()) {
			flipXCoord;
			if (doesLabelIntersectLabel()) {
				flipYCoord;
				if (doesLabelIntersectLabel()) {
					flipXCoord;
				}
			}
		}
	}
	
	CGContextFillEllipseInRect(context, CGRectMake(drawPoint.x - 3, drawPoint.y - 3, 6, 6));
	[[aPoint pointName] drawInRect:rect withAttributes:attributes];
	[labelRects addRect:rect];
}

@end
