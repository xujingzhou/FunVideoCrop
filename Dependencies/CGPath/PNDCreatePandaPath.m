//
//  PNDCreatePandaPath.m
//
//  Created by Alexsander Akers on 11/29/13.
//  Copyright (c) 2013 Pandamonia LLC. All rights reserved.
//

#import "PNDPathCreateWithElements.h"

CGPathRef PNDCreatePandaPath(CGSize size)
{
	static PNDPathElement elements[] =
    {
		PND_PATH_ELEMENT(PNDPathElementTypeMoveToPoint, 0.99242, 0.39676),
		PND_PATH_ELEMENT(PNDPathElementTypeAddCurveToPoint, 0.98536, 0.33900, 0.97266, 0.28893, 0.95382, 0.24485),
		PND_PATH_ELEMENT(PNDPathElementTypeAddCurveToPoint, 0.98069, 0.21900, 0.99742, 0.18267, 0.99742, 0.14244),
		PND_PATH_ELEMENT(PNDPathElementTypeAddCurveToPoint, 0.99743, 0.06401, 0.93384, 0.00032, 0.85532, 0.00032),
		PND_PATH_ELEMENT(PNDPathElementTypeAddCurveToPoint, 0.81483, 0.00032, 0.77830, 0.01725, 0.75241, 0.04442),
		PND_PATH_ELEMENT(PNDPathElementTypeAddCurveToPoint, 0.72266, 0.03175, 0.69013, 0.02173, 0.65529, 0.01453),
		PND_PATH_ELEMENT(PNDPathElementTypeAddCurveToPoint, 0.60863, 0.00489, 0.55640, -0.00002, 0.49997, 0.00000),
		PND_PATH_ELEMENT(PNDPathElementTypeAddCurveToPoint, 0.44356, 0.00000, 0.39132, 0.00487, 0.34471, 0.01447),
		PND_PATH_ELEMENT(PNDPathElementTypeAddCurveToPoint, 0.30982, 0.02165, 0.27724, 0.03167, 0.24746, 0.04436),
		PND_PATH_ELEMENT(PNDPathElementTypeAddCurveToPoint, 0.22159, 0.01715, 0.18510, 0.00031, 0.14462, 0.00031),
		PND_PATH_ELEMENT(PNDPathElementTypeAddCurveToPoint, 0.06612, 0.00031, 0.00249, 0.06394, 0.00249, 0.14244),
		PND_PATH_ELEMENT(PNDPathElementTypeAddCurveToPoint, 0.00249, 0.18259, 0.01911, 0.21883, 0.04599, 0.24471),
		PND_PATH_ELEMENT(PNDPathElementTypeAddCurveToPoint, 0.02722, 0.28868, 0.01457, 0.33865, 0.00753, 0.39628),
		PND_PATH_ELEMENT(PNDPathElementTypeAddCurveToPoint, 0.00000, 0.45791, 0.00000, 0.51939, 0.00000, 0.56880),
		PND_PATH_ELEMENT(PNDPathElementTypeAddCurveToPoint, 0.00000, 0.61721, 0.00000, 0.67197, 0.00825, 0.72261),
		PND_PATH_ELEMENT(PNDPathElementTypeAddCurveToPoint, 0.01810, 0.78328, 0.03892, 0.83191, 0.07194, 0.87118),
		PND_PATH_ELEMENT(PNDPathElementTypeAddCurveToPoint, 0.09083, 0.89371, 0.11410, 0.91334, 0.14098, 0.92964),
		PND_PATH_ELEMENT(PNDPathElementTypeAddCurveToPoint, 0.16756, 0.94569, 0.19875, 0.95919, 0.23377, 0.96956),
		PND_PATH_ELEMENT(PNDPathElementTypeAddCurveToPoint, 0.30298, 0.99009, 0.39003, 1.00001, 0.50001, 1.00000),
		PND_PATH_ELEMENT(PNDPathElementTypeAddCurveToPoint, 0.60996, 1.00000, 0.69709, 0.98998, 0.76637, 0.96938),
		PND_PATH_ELEMENT(PNDPathElementTypeAddCurveToPoint, 0.80139, 0.95897, 0.83262, 0.94550, 0.85922, 0.92933),
		PND_PATH_ELEMENT(PNDPathElementTypeAddCurveToPoint, 0.88610, 0.91298, 0.90929, 0.89327, 0.92818, 0.87074),
		PND_PATH_ELEMENT(PNDPathElementTypeAddCurveToPoint, 0.96113, 0.83142, 0.98194, 0.78283, 0.99179, 0.72219),
		PND_PATH_ELEMENT(PNDPathElementTypeAddCurveToPoint, 1.00000, 0.67165, 1.00000, 0.61704, 1.00000, 0.56886),
		PND_PATH_ELEMENT(PNDPathElementTypeAddCurveToPoint, 0.99995, 0.51962, 0.99997, 0.45839, 0.99239, 0.39676),
		PND_PATH_ELEMENT(PNDPathElementTypeAddLineToPoint, 0.99242, 0.39676),
		PND_PATH_ELEMENT(PNDPathElementTypeAddLineToPoint, 0.99242, 0.39676),
		PND_PATH_ELEMENT(PNDPathElementTypeCloseSubpath),
//		PND_PATH_ELEMENT(PNDPathElementTypeMoveToPoint, 0.49996, 0.92858),
//		PND_PATH_ELEMENT(PNDPathElementTypeAddCurveToPoint, 0.07555, 0.92858, 0.07136, 0.77301, 0.07136, 0.56882),
//		PND_PATH_ELEMENT(PNDPathElementTypeAddCurveToPoint, 0.07136, 0.47892, 0.07179, 0.37177, 0.10865, 0.27996),
//		PND_PATH_ELEMENT(PNDPathElementTypeAddCurveToPoint, 0.13780, 0.20735, 0.18976, 0.14435, 0.28235, 0.10711),
//		PND_PATH_ELEMENT(PNDPathElementTypeAddCurveToPoint, 0.33858, 0.08449, 0.40979, 0.07137, 0.49998, 0.07137),
//		PND_PATH_ELEMENT(PNDPathElementTypeAddCurveToPoint, 0.59015, 0.07137, 0.66137, 0.08453, 0.71758, 0.10722),
//		PND_PATH_ELEMENT(PNDPathElementTypeAddCurveToPoint, 0.79114, 0.13689, 0.83904, 0.18284, 0.87027, 0.23693),
//		PND_PATH_ELEMENT(PNDPathElementTypeAddCurveToPoint, 0.84175, 0.22324, 0.80980, 0.21558, 0.77606, 0.21558),
//		PND_PATH_ELEMENT(PNDPathElementTypeAddCurveToPoint, 0.65562, 0.21558, 0.55799, 0.31319, 0.55799, 0.43361),
//		PND_PATH_ELEMENT(PNDPathElementTypeAddCurveToPoint, 0.55799, 0.55407, 0.65558, 0.65165, 0.77604, 0.65164),
//		PND_PATH_ELEMENT(PNDPathElementTypeAddCurveToPoint, 0.83542, 0.65164, 0.88925, 0.62790, 0.92858, 0.58940),
//		PND_PATH_ELEMENT(PNDPathElementTypeAddCurveToPoint, 0.92780, 0.78239, 0.90996, 0.92861, 0.49996, 0.92858),
//		PND_PATH_ELEMENT(PNDPathElementTypeAddLineToPoint, 0.49996, 0.92858),
//		PND_PATH_ELEMENT(PNDPathElementTypeAddLineToPoint, 0.49996, 0.92858),
//		PND_PATH_ELEMENT(PNDPathElementTypeCloseSubpath),
//		PND_PATH_ELEMENT(PNDPathElementTypeMoveToPoint, 0.78422, 0.49776),
//		PND_PATH_ELEMENT(PNDPathElementTypeAddCurveToPoint, 0.78422, 0.53701, 0.75240, 0.56883, 0.71315, 0.56881),
//		PND_PATH_ELEMENT(PNDPathElementTypeAddCurveToPoint, 0.67390, 0.56881, 0.64209, 0.53699, 0.64209, 0.49774),
//		PND_PATH_ELEMENT(PNDPathElementTypeAddCurveToPoint, 0.64209, 0.45850, 0.67390, 0.42668, 0.71315, 0.42668),
//		PND_PATH_ELEMENT(PNDPathElementTypeAddCurveToPoint, 0.75242, 0.42671, 0.78427, 0.45850, 0.78427, 0.49777),
//		PND_PATH_ELEMENT(PNDPathElementTypeAddLineToPoint, 0.78422, 0.49776),
//		PND_PATH_ELEMENT(PNDPathElementTypeAddLineToPoint, 0.78422, 0.49776),
//		PND_PATH_ELEMENT(PNDPathElementTypeCloseSubpath),
//		PND_PATH_ELEMENT(PNDPathElementTypeMoveToPoint, 0.49996, 0.56880),
//		PND_PATH_ELEMENT(PNDPathElementTypeAddCurveToPoint, 0.53920, 0.56880, 0.57101, 0.58473, 0.57101, 0.60437),
//		PND_PATH_ELEMENT(PNDPathElementTypeAddCurveToPoint, 0.57101, 0.62402, 0.53920, 0.63995, 0.49996, 0.63995),
//		PND_PATH_ELEMENT(PNDPathElementTypeAddCurveToPoint, 0.46073, 0.63995, 0.42892, 0.62402, 0.42892, 0.60437),
//		PND_PATH_ELEMENT(PNDPathElementTypeAddCurveToPoint, 0.42892, 0.58473, 0.46073, 0.56880, 0.49996, 0.56880),
//		PND_PATH_ELEMENT(PNDPathElementTypeAddLineToPoint, 0.49996, 0.56880),
//		PND_PATH_ELEMENT(PNDPathElementTypeCloseSubpath),
//		PND_PATH_ELEMENT(PNDPathElementTypeMoveToPoint, 0.28682, 0.42671),
//		PND_PATH_ELEMENT(PNDPathElementTypeAddCurveToPoint, 0.32606, 0.42671, 0.35787, 0.45851, 0.35787, 0.49775),
//		PND_PATH_ELEMENT(PNDPathElementTypeAddCurveToPoint, 0.35787, 0.53699, 0.32606, 0.56880, 0.28682, 0.56880),
//		PND_PATH_ELEMENT(PNDPathElementTypeAddCurveToPoint, 0.24758, 0.56880, 0.21577, 0.53699, 0.21577, 0.49775),
//		PND_PATH_ELEMENT(PNDPathElementTypeAddCurveToPoint, 0.21577, 0.45851, 0.24758, 0.42671, 0.28682, 0.42671),
//		PND_PATH_ELEMENT(PNDPathElementTypeAddLineToPoint, 0.28682, 0.42671),
//		PND_PATH_ELEMENT(PNDPathElementTypeCloseSubpath)
	};
    
    CGAffineTransform transformTranslate = CGAffineTransformMakeTranslation(size.width, size.height);
    CGAffineTransform rotateTransform = CGAffineTransformRotate(transformTranslate, M_PI);
	CGAffineTransform transform = CGAffineTransformScale(rotateTransform, size.width, size.height);
    CGAffineTransform final = transform;
	return PNDPathCreateWithElements(elements, PND_PATH_ELEMENTS_COUNT(elements), &final);
    
//    CGAffineTransform transform = CGAffineTransformMakeScale(size.width, size.height);
//    return PNDPathCreateWithElements(elements, PND_PATH_ELEMENTS_COUNT(elements), &transform);
}
