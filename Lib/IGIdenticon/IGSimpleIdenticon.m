//
//  IGSimpleIdenticon.m
//  IGIdenticon
//
//  Created by Evgeniy Yurtaev on 7/20/13.
//  Copyright (c) 2013 Evgeniy Yurtaev. All rights reserved.
//

#import <CoreGraphics/CGBase.h>

#import "IGSimpleIdenticon.h"

static const NSInteger IGNumberOfRows = 4;
static const NSInteger IGNumberOfColumns = 4;

static char const IGCellTypes[][7] =  {
    {0, 4, 24, 20, CHAR_MAX, CHAR_MAX},
    {0, 4, 20, CHAR_MAX, CHAR_MAX},
    {2, 24, 20, CHAR_MAX, CHAR_MAX},
    {0, 2, 20, 22, CHAR_MAX, CHAR_MAX},
    {2, 14, 22, 10, CHAR_MAX, CHAR_MAX},
    {0, 14, 24, 22, CHAR_MAX, CHAR_MAX},
    {2, 24, 22, 13, 11, 22, 2},
    {0, 14, 22, CHAR_MAX, CHAR_MAX, CHAR_MAX, CHAR_MAX},
    {6, 8, 18, 16, CHAR_MAX, CHAR_MAX, CHAR_MAX},
    {4, 20, 10, 12, 2, CHAR_MAX, CHAR_MAX},
    {0, 2, 12, 10, CHAR_MAX, CHAR_MAX},
    {10, 14, 22, CHAR_MAX, CHAR_MAX, CHAR_MAX, CHAR_MAX},
    {20, 12, 24, CHAR_MAX, CHAR_MAX, CHAR_MAX, CHAR_MAX},
    {10, 2, 12, CHAR_MAX, CHAR_MAX, CHAR_MAX, CHAR_MAX},
    {0, 2, 10, CHAR_MAX, CHAR_MAX, CHAR_MAX, CHAR_MAX},
    {0, 4, 24, 20, CHAR_MAX, CHAR_MAX, CHAR_MAX}
};

static char const IGCellCenterType[] = {0, 4, 8, 15};

static void IGDrawIdenticonCell(CGContextRef context, UIColor *color, CGPoint position, CGSize size, char cellTypeIndex, NSUInteger turn, BOOL inverted)
{
    size_t cellTypesCount = sizeof(IGCellTypes) / sizeof(IGCellTypes[0]);
    cellTypeIndex = cellTypeIndex % cellTypesCount;
    if (cellTypeIndex == 15) {
        inverted = !inverted;
    }

    char numberOfVertices = 0;
    while (numberOfVertices < cellTypesCount && IGCellTypes[cellTypeIndex][numberOfVertices] != CHAR_MAX) {
        ++numberOfVertices;
    }

    CGMutablePathRef path = CGPathCreateMutable();

    char point = IGCellTypes[cellTypeIndex][0];
    CGPoint vertice;
    vertice.x = (point % 5) * (size.width / IGNumberOfColumns);
    vertice.y = (point / 5) * (size.height / IGNumberOfRows);
    CGPathMoveToPoint(path, NULL, vertice.x, vertice.y);

    for (char i = 0; (i < cellTypesCount && IGCellTypes[cellTypeIndex][i] != CHAR_MAX); ++i){
        char point = IGCellTypes[cellTypeIndex][i];

        vertice.x = (point % 5) * size.width / IGNumberOfColumns;
        vertice.y = (point / 5) * size.height / IGNumberOfRows;
        CGPathAddLineToPoint(path, NULL, vertice.x, vertice.y);
    }
    CGPathCloseSubpath(path);

    CGContextSaveGState(context);
    CGContextSetFillColorWithColor(context, color.CGColor);
    if (inverted) {
        CGContextFillRect(context, CGRectMake(position.x, position.y, size.width, size.height));
        CGContextSetBlendMode(context, kCGBlendModeClear);
    }

    CGContextTranslateCTM(context, position.x + size.width * 0.5, position.y + size.height * 0.5);
    CGContextRotateCTM(context, (turn % 4) * M_PI_2);
    CGContextTranslateCTM(context, -size.width * 0.5, -size.height * 0.5);

    CGContextAddPath(context, path);
    CGContextDrawPath(context, kCGPathFill);
    CGPathRelease(path);

    CGContextRestoreGState(context);
}

static UIImage *IGScaleImageToSize(UIImage *image, CGSize size)
{
    UIGraphicsBeginImageContextWithOptions(size, NO, 0);

    [image drawInRect:CGRectMake(0, 0, size.width, size.height)];
    UIImage *scaledImage = UIGraphicsGetImageFromCurrentImageContext();

    UIGraphicsEndImageContext();

    return scaledImage;
}

@implementation IGSimpleIdenticon

- (UIImage *)imageFromNumber:(uint32_t)number size:(CGSize)size
{
    NSInteger blue = (number >> 16) & 31;
    NSInteger green = (number >> 21) & 31;
    NSInteger red = (number >> 27) & 31;
    UIColor *color = [UIColor colorWithRed:(red * 8) / 255.0f green:(green * 8) / 255.0f blue:(blue * 8) / 255.0f alpha:1];

    CGSize cellSize = CGSizeMake(ceilf(size.width / IGNumberOfColumns), ceilf(size.height / IGNumberOfRows));
    CGSize normalizedSize = CGSizeMake(cellSize.width * IGNumberOfColumns, cellSize.height * IGNumberOfColumns);

    UIGraphicsBeginImageContextWithOptions(normalizedSize, NO, 0);
    CGContextRef context = UIGraphicsGetCurrentContext();

    NSInteger middleCellType = IGCellCenterType[number & 3];
    BOOL middleIsInvert = ((number >> 2) & 1) != 0;
    IGDrawIdenticonCell(context, color, CGPointMake(cellSize.width, cellSize.height), cellSize, middleCellType, 0, middleIsInvert);
    IGDrawIdenticonCell(context, color, CGPointMake(cellSize.width, cellSize.height * 2), cellSize, middleCellType, 0, middleIsInvert);
    IGDrawIdenticonCell(context, color, CGPointMake(cellSize.width * 2, cellSize.height * 2), cellSize, middleCellType, 0, middleIsInvert);
    IGDrawIdenticonCell(context, color, CGPointMake(cellSize.width * 2, cellSize.height), cellSize, middleCellType, 0, middleIsInvert);

    NSInteger cornerCellType = (number >> 3) & 15;
    BOOL cornerIsInvert = ((number >> 7) & 1) != 0;
    NSUInteger cornerTurn = (number >> 8) & 3;
    IGDrawIdenticonCell(context, color, CGPointMake(0, 0), cellSize, cornerCellType, cornerTurn++, cornerIsInvert);
    IGDrawIdenticonCell(context, color, CGPointMake(cellSize.width * 3, 0), cellSize, cornerCellType, cornerTurn++, cornerIsInvert);
    IGDrawIdenticonCell(context, color, CGPointMake(cellSize.width * 3, cellSize.height * 3), cellSize, cornerCellType, cornerTurn++, cornerIsInvert);
    IGDrawIdenticonCell(context, color, CGPointMake(0, cellSize.height * 3), cellSize, cornerCellType, cornerTurn++, cornerIsInvert);

    NSInteger sideCellType = (number >> 10) & 15;
    BOOL sideIsInvert = ((number >> 14) & 1) != 0;
    NSUInteger sideTurn = (number >> 15) & 3;
    IGDrawIdenticonCell(context, color, CGPointMake(cellSize.width, 0), cellSize, sideCellType, sideTurn++, sideIsInvert);
    IGDrawIdenticonCell(context, color, CGPointMake(cellSize.width * 3, cellSize.height), cellSize, sideCellType, sideTurn++, sideIsInvert);
    IGDrawIdenticonCell(context, color, CGPointMake(cellSize.width * 2, cellSize.height * 3), cellSize, sideCellType, sideTurn++, sideIsInvert);
    IGDrawIdenticonCell(context, color, CGPointMake(0, cellSize.height * 2), cellSize, sideCellType, sideTurn++, sideIsInvert);
    IGDrawIdenticonCell(context, color, CGPointMake(0, cellSize.height), cellSize, sideCellType, sideTurn++, sideIsInvert);
    IGDrawIdenticonCell(context, color, CGPointMake(cellSize.width * 2, 0), cellSize, sideCellType, sideTurn++, sideIsInvert);
    IGDrawIdenticonCell(context, color, CGPointMake(cellSize.width * 3, cellSize.height * 2), cellSize, sideCellType, sideTurn++, sideIsInvert);
    IGDrawIdenticonCell(context, color, CGPointMake(cellSize.width, cellSize.height * 3), cellSize, sideCellType, sideTurn++, sideIsInvert);

    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    UIImage *scaledImage = IGScaleImageToSize(image, size);

    return scaledImage;
}

@end
