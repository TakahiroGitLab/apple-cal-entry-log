#!/usr/bin/env swift
//
// Draws the app icon and writes an .iconset.
//
//   swift Scripts/make-icon.swift build/AppIcon.iconset
//
// Kept as code rather than a folder of PNGs: every dimension here is
// a fraction of the canvas, so the same drawing renders at 16 points
// and at 1024 without a second thought, and the day the colour needs
// to change it is one number rather than ten files.
//
// The subject: a month, dimmed, with a lens over the day something
// was written on. What is under the glass is drawn a second time,
// brighter and heavier -- not scaled. A scaled copy lands beside the
// dim one underneath it and reads as a smudge; the same geometry at a
// greater weight covers it exactly and still says "magnified".

import AppKit
import Foundation

let accent = NSColor(srgbRed: 0.46, green: 0.80, blue: 1.00, alpha: 1)

func squircle(_ r: CGRect) -> NSBezierPath {
    NSBezierPath(roundedRect: r, xRadius: r.width * 0.2237, yRadius: r.width * 0.2237)
}

func stroked(
    _ path: NSBezierPath, _ width: CGFloat, _ colour: NSColor,
    glow: CGFloat, glowAlpha: CGFloat, canvas S: CGFloat
) {
    path.lineWidth = width
    path.lineCapStyle = .round
    path.lineJoinStyle = .round

    if glow > 0 {
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = accent.withAlphaComponent(glowAlpha)
        shadow.shadowOffset = .zero
        shadow.shadowBlurRadius = S * glow
        shadow.set()
        colour.setStroke()
        path.stroke()
        NSGraphicsContext.restoreGraphicsState()
    }

    colour.setStroke()
    path.stroke()
}

func plate(_ rect: CGRect, canvas S: CGFloat) {
    let path = squircle(rect)

    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.30)
    shadow.shadowOffset = NSSize(width: 0, height: -S * 0.012)
    shadow.shadowBlurRadius = S * 0.035
    shadow.set()
    NSColor.black.setFill()
    path.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGradient(colors: [NSColor(srgbRed: 0.13, green: 0.16, blue: 0.22, alpha: 1),
                        NSColor(srgbRed: 0.04, green: 0.05, blue: 0.08, alpha: 1)])!
        .draw(in: path, angle: -90)

    // A hair of light along the top edge, the way a real object has.
    NSGraphicsContext.saveGraphicsState()
    path.addClip()
    let rim = squircle(rect.insetBy(dx: S * 0.004, dy: S * 0.004))
    rim.lineWidth = S * 0.006
    NSColor(white: 1, alpha: 0.16).setStroke()
    rim.stroke()
    NSGraphicsContext.restoreGraphicsState()
}

/// Below this the drawing is pared back. Sixteen points is eleven
/// pixels of artwork: the rings, the rule and eight days become four
/// smudges, and a smudge is worse than an absence.
let detailed: (CGFloat) -> Bool = { $0 >= 96 }

func month(in rect: CGRect, lit: Bool, canvas S: CGFloat) {

    let ink = NSColor(white: 1, alpha: lit ? 1.0 : 0.26)
    let width = S * (lit ? 0.030 : 0.018) * (detailed(S) ? 1 : 1.5)
    let glow = lit ? 0.045 : 0.0

    let page = CGRect(x: rect.minX + rect.width * 0.135,
                      y: rect.minY + rect.height * 0.175,
                      width: rect.width * 0.73, height: rect.height * 0.60)

    stroked(NSBezierPath(roundedRect: page, xRadius: S * 0.042, yRadius: S * 0.042),
            width, ink, glow: glow, glowAlpha: 0.5, canvas: S)

    if detailed(S) {
        let rule = NSBezierPath()
        let ruleY = page.maxY - page.height * 0.25
        rule.move(to: CGPoint(x: page.minX, y: ruleY))
        rule.line(to: CGPoint(x: page.maxX, y: ruleY))
        stroked(rule, width, NSColor(white: 1, alpha: lit ? 0.85 : 0.22),
                glow: glow, glowAlpha: 0.4, canvas: S)

        for x in [page.minX + page.width * 0.27, page.maxX - page.width * 0.27] {
            let ring = NSBezierPath()
            ring.move(to: CGPoint(x: x, y: page.maxY - page.height * 0.02))
            ring.line(to: CGPoint(x: x, y: page.maxY + rect.height * 0.05))
            stroked(ring, width, ink, glow: glow, glowAlpha: 0.5, canvas: S)
        }
    }

    // Small, only the one day survives, and it goes under the lens.
    guard detailed(S) else {
        guard lit else { return }

        let radius = rect.width * 0.055
        let x = page.minX + page.width * 0.30
        let y = page.minY + page.height * 0.34

        let dot = NSBezierPath(ovalIn: CGRect(
            x: x - radius, y: y - radius, width: radius * 2, height: radius * 2
        ))

        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = accent.withAlphaComponent(0.95)
        shadow.shadowOffset = .zero
        shadow.shadowBlurRadius = S * 0.05
        shadow.set()
        accent.setFill()
        dot.fill()
        NSGraphicsContext.restoreGraphicsState()
        return
    }

    let columns = 4, rows = 2
    let area = CGRect(x: page.minX + page.width * 0.14,
                      y: page.minY + page.height * 0.15,
                      width: page.width * 0.72, height: page.height * 0.44)
    let cellWidth = area.width / CGFloat(columns)
    let cellHeight = area.height / CGFloat(rows)
    let radius = min(cellWidth, cellHeight) * (lit ? 0.27 : 0.19)

    for row in 0..<rows {
        for column in 0..<columns {
            let x = area.minX + cellWidth * (CGFloat(column) + 0.5)
            let y = area.maxY - cellHeight * (CGFloat(row) + 0.5)

            let dot = NSBezierPath(ovalIn: CGRect(
                x: x - radius, y: y - radius,
                width: radius * 2, height: radius * 2
            ))

            // The day the entry was written on.
            guard row == 1, column == 1 else {
                NSColor(white: 1, alpha: lit ? 0.80 : 0.20).setFill()
                dot.fill()
                continue
            }

            NSGraphicsContext.saveGraphicsState()
            let shadow = NSShadow()
            shadow.shadowColor = accent.withAlphaComponent(lit ? 0.95 : 0.30)
            shadow.shadowOffset = .zero
            shadow.shadowBlurRadius = S * (lit ? 0.05 : 0.02)
            shadow.set()
            accent.withAlphaComponent(lit ? 1.0 : 0.45).setFill()
            dot.fill()
            NSGraphicsContext.restoreGraphicsState()
        }
    }
}

func icon(size S: CGFloat) -> Data? {

    let image = NSImage(size: NSSize(width: S, height: S))
    image.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .high

    // macOS leaves a margin around the artwork.
    let rect = CGRect(x: S * 0.055, y: S * 0.055, width: S * 0.89, height: S * 0.89)

    plate(rect, canvas: S)
    month(in: rect, lit: false, canvas: S)

    let diameter = rect.width * 0.44
    let lens = CGRect(x: rect.minX + rect.width * 0.20,
                      y: rect.minY + rect.height * 0.16,
                      width: diameter, height: diameter)
    let glass = NSBezierPath(ovalIn: lens)

    NSGraphicsContext.saveGraphicsState()
    glass.addClip()
    NSColor(white: 1, alpha: 0.05).setFill()
    glass.fill()
    month(in: rect, lit: true, canvas: S)
    NSGraphicsContext.restoreGraphicsState()

    stroked(glass, S * (detailed(S) ? 0.040 : 0.055), .white,
            glow: 0.05, glowAlpha: 0.7, canvas: S)

    let handle = NSBezierPath()
    let angle = CGFloat.pi * 1.25
    handle.move(to: CGPoint(x: lens.midX + cos(angle) * diameter / 2,
                            y: lens.midY + sin(angle) * diameter / 2))
    handle.line(to: CGPoint(x: lens.midX + cos(angle) * diameter * 0.86,
                            y: lens.midY + sin(angle) * diameter * 0.86))
    stroked(handle, S * (detailed(S) ? 0.046 : 0.062), .white,
            glow: 0.05, glowAlpha: 0.7, canvas: S)

    image.unlockFocus()

    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff)
    else { return nil }

    return rep.representation(using: .png, properties: [:])
}


let arguments = CommandLine.arguments

guard arguments.count == 2 else {
    FileHandle.standardError.write(
        Data("usage: make-icon.swift <output.iconset>\n".utf8)
    )
    exit(2)
}

let directory = URL(fileURLWithPath: arguments[1])

try? FileManager.default.removeItem(at: directory)
try FileManager.default.createDirectory(
    at: directory, withIntermediateDirectories: true
)

// What iconutil expects, and nothing it does not.
let wanted: [(points: Int, scale: Int)] = [
    (16, 1), (16, 2), (32, 1), (32, 2), (128, 1),
    (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)
]

for (points, scale) in wanted {
    let suffix = scale == 1 ? "" : "@2x"
    let name = "icon_\(points)x\(points)\(suffix).png"

    guard let png = icon(size: CGFloat(points * scale)) else {
        FileHandle.standardError.write(Data("could not draw \(name)\n".utf8))
        exit(1)
    }

    try png.write(to: directory.appendingPathComponent(name))
}

print("drew \(wanted.count) sizes into \(directory.path)")
