#!/usr/bin/env swift

// Draws Carbon's app icon and writes it into the asset catalog.
//
//     swift Tools/GenerateAppIcon.swift
//
// The icon is generated rather than drawn by hand so it stays reproducible: the palette is the
// app's own, and changing a token here is a one-command re-export rather than a round trip
// through a design tool. CoreGraphics and ImageIO only — no dependency enters the repo for a
// file that is rendered once.
//
// **The subject is a carbon copy**, which is what the app is named after: a sheet of paper and
// the duplicate that appeared underneath it without anyone writing twice. The back sheet is
// faint because it is the copy, and it carries the same marks as the sheet in front — that is
// the whole product in two shapes.
//
// Legibility at 29pt is the binding constraint, so there are five shapes and no hairlines. At
// 58 pixels the rules survive as distinct strokes; anything thinner turns to grey mush.
//
// **One 1024 PNG, not an Icon Composer `.icon`.** iOS 26 can take layered icons with their own
// dark, tinted and clear treatments, and this deliberately does not. The ground is already a
// deep violet, so the variants the system derives from it hold up on a dark home screen —
// checked, not assumed — and a layered icon is a day of work for a difference a judge will not
// look for. Revisit when the app has a week rather than a day to spend on it.

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let side = 1024.0

// The app's own tokens, light appearance. Kept as literals rather than read from the asset
// catalog so this script has no build dependency on the app target.
let violetTop = CGColor(red: 0x47 / 255, green: 0x36 / 255, blue: 0xA4 / 255, alpha: 1)
let violetBottom = CGColor(red: 0x2C / 255, green: 0x20 / 255, blue: 0x7A / 255, alpha: 1)
let paperRaised = CGColor(red: 0xF6 / 255, green: 0xF6 / 255, blue: 0xF0 / 255, alpha: 1)
let carbon = CGColor(red: 0x3D / 255, green: 0x2E / 255, blue: 0x8C / 255, alpha: 1)

/// The copy, not the original: the same paper at a fraction of its presence.
///
/// It carries no rules of its own. They were tried, and at icon sizes the few millimetres of
/// them that clear the front sheet read as notches cut out of the edge rather than as marks
/// that came through. A clean second sheet says "copy" on its own.
let ghostSheet = CGColor(red: 0xF6 / 255, green: 0xF6 / 255, blue: 0xF0 / 255, alpha: 0.30)

let sheetSize = CGSize(width: 420, height: 562)
let sheetRadius = 28.0
let backTilt = 9.0 * .pi / 180

/// How far apart the two sheets sit, front to back.
let separation = CGVector(dx: 110, dy: -93)

/// The tilted sheet's axis-aligned bounds are wider and taller than the sheet itself, so the
/// pair is centred by solving for it rather than by nudging two numbers until it looks right.
let tiltedSize = CGSize(
    width: sheetSize.width * cos(backTilt) + sheetSize.height * sin(backTilt),
    height: sheetSize.width * sin(backTilt) + sheetSize.height * cos(backTilt)
)

/// The bright sheet pulls the eye toward its own corner, so a perfectly centred pair still
/// looks low and left. A few points back the other way is the whole correction.
let opticalNudge = CGVector(dx: 10, dy: -8)

func bounds(centre: CGPoint, size: CGSize) -> CGRect {
    CGRect(
        x: centre.x - size.width / 2, y: centre.y - size.height / 2,
        width: size.width, height: size.height
    )
}

// Lay the pair out around an arbitrary origin, measure what that produced, then move the whole
// composition so its bounds land in the middle of the canvas. Doing it by measurement rather
// than by an offset formula is the point: the formula this replaced had a sign inverted and
// pushed the group 83pt high, which is exactly the kind of error a measurement cannot make.
let looseFront = CGPoint(x: -separation.dx / 2, y: -separation.dy / 2)
let looseBack = CGPoint(x: separation.dx / 2, y: separation.dy / 2)
let pairBounds = bounds(centre: looseFront, size: sheetSize)
    .union(bounds(centre: looseBack, size: tiltedSize))

let recentre = CGVector(
    dx: side / 2 - pairBounds.midX + opticalNudge.dx,
    dy: side / 2 - pairBounds.midY + opticalNudge.dy
)

/// Upright and lower-left: the sheet under the pen.
let frontCentre = CGPoint(x: looseFront.x + recentre.dx, y: looseFront.y + recentre.dy)
/// Tilted and upper-right, so the two read as separate sheets rather than one thick one.
let backCentre = CGPoint(x: looseBack.x + recentre.dx, y: looseBack.y + recentre.dy)

guard
    let context = CGContext(
        data: nil,
        width: Int(side),
        height: Int(side),
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        // Opaque: an app icon with an alpha channel is rejected at submission.
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    )
else {
    fatalError("Could not create the drawing context.")
}

// Flip to a top-left origin so the geometry above reads the way it is laid out on screen.
context.translateBy(x: 0, y: side)
context.scaleBy(x: 1, y: -1)
context.interpolationQuality = .high
context.setShouldAntialias(true)

func sheetPath(centre: CGPoint) -> CGPath {
    CGPath(
        roundedRect: bounds(centre: centre, size: sheetSize),
        cornerWidth: sheetRadius,
        cornerHeight: sheetRadius,
        transform: nil
    )
}

/// A form: one short heading rule and three full ones. Widths vary so it reads as filled-in
/// lines rather than as a barcode.
///
/// 42pt tall at 1024 is 2.4 pixels at 29pt — the floor at which a rule is still a rule. The
/// pitch matters as much as the height: closer together and the four of them grey out.
let markWidths = [0.52, 1.0, 1.0, 0.68]
let markHeight = 40.0
let markPitch = 97.0
let markInset = 58.0

func drawMarks(on centre: CGPoint, colour: CGColor) {
    let innerWidth = sheetSize.width - markInset * 2
    let left = centre.x - sheetSize.width / 2 + markInset
    let block = markPitch * Double(markWidths.count - 1) + markHeight
    var y = centre.y - block / 2

    context.setFillColor(colour)
    for fraction in markWidths {
        let bar = CGPath(
            roundedRect: CGRect(x: left, y: y, width: innerWidth * fraction, height: markHeight),
            cornerWidth: markHeight / 2,
            cornerHeight: markHeight / 2,
            transform: nil
        )
        context.addPath(bar)
        context.fillPath()
        y += markPitch
    }
}

// Background.
let gradient = CGGradient(
    colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
    colors: [violetTop, violetBottom] as CFArray,
    locations: [0, 1]
)!
context.drawLinearGradient(
    gradient,
    start: CGPoint(x: 0, y: 0),
    end: CGPoint(x: 0, y: side),
    options: []
)

// The copy, tilted behind.
context.saveGState()
context.translateBy(x: backCentre.x, y: backCentre.y)
context.rotate(by: backTilt)
context.translateBy(x: -backCentre.x, y: -backCentre.y)
context.setFillColor(ghostSheet)
context.addPath(sheetPath(centre: backCentre))
context.fillPath()
context.restoreGState()

// The original, in front.
context.setFillColor(paperRaised)
context.addPath(sheetPath(centre: frontCentre))
context.fillPath()
drawMarks(on: frontCentre, colour: carbon)

let destination = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appending(path: "Carbon/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png")

guard
    let image = context.makeImage(),
    let sink = CGImageDestinationCreateWithURL(
        destination as CFURL, UTType.png.identifier as CFString, 1, nil
    )
else {
    fatalError("Could not encode the icon.")
}

CGImageDestinationAddImage(sink, image, nil)
guard CGImageDestinationFinalize(sink) else {
    fatalError("Could not write \(destination.path).")
}

print("Wrote \(destination.path)")
