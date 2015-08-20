//
//  PNDPathCreateWithElements.h
//
//  Created by Alexsander Akers on 11/29/13.
//  Copyright (c) 2013 Pandamonia LLC. All rights reserved.
//

@import CoreFoundation;
@import CoreGraphics;

#define PND_PATH_ELEMENT(_type, ...) \
((PNDPathElement){ \
	.type = _type, \
	.values = { __VA_ARGS__ } \
})

#define PND_PATH_ELEMENTS_COUNT(elements) (sizeof(elements)/sizeof(*elements))

typedef CF_ENUM(CFIndex, PNDPathElementType) {
	// A path element that calls CGPathMoveToPoint.
	PNDPathElementTypeMoveToPoint = kCGPathElementMoveToPoint,
	
	// A path element that calls CGPathAddLineToPoint.
	PNDPathElementTypeAddLineToPoint = kCGPathElementAddLineToPoint,
	
	// A path element that calls CGPathAddQuadCurveToPoint.
	PNDPathElementTypeAddQuadCurveToPoint = kCGPathElementAddQuadCurveToPoint,
	
	// A path element that calls CGPathAddCurveToPoint.
	PNDPathElementTypeAddCurveToPoint = kCGPathElementAddCurveToPoint,
	
	// A path element that calls CGPathCloseSubpath.
	PNDPathElementTypeCloseSubpath = kCGPathElementCloseSubpath,
	
	// A path element that calls CGPathAddRoundedRect.
	PNDPathElementTypeAddRoundedRect = 1000,
	
	// A path element that calls CGPathAddRect.
	PNDPathElementTypeAddRect,
	
	// A path element that calls CGPathAddEllipseInRect.
	PNDPathElementTypeAddEllipseInRect,
	
	// A path element that calls CGPathAddRelativeArc.
	PNDPathElementTypeAddRelativeArc,
	
	// A path element that calls CGPathAddArc with the clockwise argument set to true.
	PNDPathElementTypeAddArcClockwise,
	
	// A path element that calls CGPathAddArc with the clockwise argument set to false.
	PNDPathElementTypeAddArcCounterclockwise,
	
	// A path element that calls CGPathAddArcToPoint.
	PNDPathElementTypeAddArcToPoint
};

// A data structure that provides information about a path element.
typedef struct PNDPathElement {
	PNDPathElementType type;
	CGFloat values[6];
} PNDPathElement;

CG_EXTERN CGPathRef PNDPathCreateWithElements(const PNDPathElement elements[], size_t count, const CGAffineTransform *transform);

CG_EXTERN void PNDPathLogDescription(CGPathRef path);
