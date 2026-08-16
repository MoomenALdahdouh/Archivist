#!/usr/bin/env swift
import AppKit
import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : FileManager.default.currentDirectoryPath)
let resources = root.appendingPathComponent("Resources")
try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)

let sizes: [(Int, String)] = [
    (16, "16x16"), (32, "16x16@2x"),
    (32, "32x32"), (64, "32x32@2x"),
    (128, "128x128"), (256, "128x128@2x"),
    (256, "256x256"), (512, "256x256@2x"),
    (512, "512x512"), (1024, "512x512@2x"),
]

func bitmap(_ dimension: Int, draw: (CGFloat) -> Void) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: dimension,
        pixelsHigh: dimension,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    rep.size = NSSize(width: dimension, height: dimension)
    NSGraphicsContext.saveGraphicsState()
    guard let context = NSGraphicsContext(bitmapImageRep: rep) else {
        fatalError("Unable to create graphics context")
    }
    context.imageInterpolation = .high
    context.shouldAntialias = true
    NSGraphicsContext.current = context
    draw(CGFloat(dimension))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

func roundedRect(_ rect: NSRect, radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

func drawAppIcon(in size: CGFloat) {
    let canvas = NSRect(x: 0, y: 0, width: size, height: size)
    let top = NSColor(calibratedRed: 0.18, green: 0.62, blue: 0.78, alpha: 1)
    let bottom = NSColor(calibratedRed: 0.07, green: 0.22, blue: 0.42, alpha: 1)
    NSGradient(starting: top, ending: bottom)?.draw(in: canvas, angle: 270)

    let shine = NSBezierPath(rect: NSRect(x: 0, y: size * 0.55, width: size, height: size * 0.45))
    NSColor.white.withAlphaComponent(0.10).setFill()
    shine.fill()

    let boxWidth = size * 0.52
    let boxHeight = size * 0.38
    let boxX = (size - boxWidth) / 2
    let boxY = size * 0.18
    let body = NSRect(x: boxX, y: boxY, width: boxWidth, height: boxHeight)
    let lid = NSRect(x: boxX - size * 0.04, y: body.maxY - size * 0.02, width: boxWidth + size * 0.08, height: size * 0.14)

    NSColor.white.withAlphaComponent(0.22).setFill()
    roundedRect(body.offsetBy(dx: size * 0.04, dy: size * 0.06), radius: size * 0.05).fill()

    NSColor.white.setFill()
    roundedRect(body, radius: size * 0.06).fill()
    roundedRect(lid, radius: size * 0.045).fill()

    let zipper = NSRect(
        x: body.midX - size * 0.045,
        y: body.minY + size * 0.02,
        width: size * 0.09,
        height: lid.maxY - body.minY - size * 0.04
    )
    bottom.setFill()
    roundedRect(zipper, radius: size * 0.03).fill()

    let toothHeight = max(2, size * 0.035)
    var toothY = zipper.minY + size * 0.03
    NSColor.white.withAlphaComponent(0.85).setFill()
    while toothY < zipper.maxY - size * 0.04 {
        NSRect(x: zipper.midX - size * 0.012, y: toothY, width: size * 0.024, height: toothHeight * 0.45).fill()
        toothY += toothHeight
    }
}

func drawRARIcon(in size: CGFloat) {
    NSColor.clear.setFill()
    NSRect(x: 0, y: 0, width: size, height: size).fill()

    let page = NSRect(x: size * 0.16, y: size * 0.08, width: size * 0.68, height: size * 0.84)
    NSColor.white.setFill()
    NSColor(calibratedWhite: 0.78, alpha: 1).setStroke()
    let path = roundedRect(page, radius: size * 0.08)
    path.lineWidth = max(1, size * 0.015)
    path.fill()
    path.stroke()

    let fold = NSBezierPath()
    let foldSize = size * 0.18
    fold.move(to: NSPoint(x: page.maxX - foldSize, y: page.maxY))
    fold.line(to: NSPoint(x: page.maxX, y: page.maxY - foldSize))
    fold.line(to: NSPoint(x: page.maxX - foldSize, y: page.maxY - foldSize))
    fold.close()
    NSColor(calibratedRed: 0.82, green: 0.90, blue: 0.95, alpha: 1).setFill()
    fold.fill()

    let badge = NSRect(x: page.minX + size * 0.08, y: page.minY + size * 0.12, width: page.width - size * 0.16, height: size * 0.22)
    NSColor(calibratedRed: 0.07, green: 0.22, blue: 0.42, alpha: 1).setFill()
    roundedRect(badge, radius: size * 0.04).fill()

    let text = "RAR" as NSString
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size * 0.12, weight: .heavy),
        .foregroundColor: NSColor.white,
    ]
    let textSize = text.size(withAttributes: attrs)
    text.draw(
        at: NSPoint(x: badge.midX - textSize.width / 2, y: badge.midY - textSize.height / 2),
        withAttributes: attrs
    )

    let box = NSRect(x: page.midX - size * 0.16, y: page.minY + size * 0.42, width: size * 0.32, height: size * 0.22)
    NSColor(calibratedRed: 0.07, green: 0.22, blue: 0.42, alpha: 1).setStroke()
    let boxPath = roundedRect(box, radius: size * 0.03)
    boxPath.lineWidth = max(1.5, size * 0.025)
    boxPath.stroke()
}

func writeIconset(name: String, draw: @escaping (CGFloat) -> Void) throws -> URL {
    let iconset = resources.appendingPathComponent("\(name).iconset")
    try? FileManager.default.removeItem(at: iconset)
    try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
    for (dimension, label) in sizes {
        let data = bitmap(dimension, draw: draw)
        try data.write(to: iconset.appendingPathComponent("icon_\(label).png"))
    }
    let icns = resources.appendingPathComponent("\(name).icns")
    try? FileManager.default.removeItem(at: icns)
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
    process.arguments = ["-c", "icns", iconset.path, "-o", icns.path]
    try process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0, FileManager.default.fileExists(atPath: icns.path) else {
        throw NSError(domain: "generate-icons", code: 1, userInfo: [NSLocalizedDescriptionKey: "iconutil failed for \(name)"])
    }
    try? FileManager.default.removeItem(at: iconset)
    return icns
}

let app = try writeIconset(name: "AppIcon", draw: drawAppIcon)
let rar = try writeIconset(name: "RAR", draw: drawRARIcon)
try bitmap(1024, draw: drawAppIcon).write(to: resources.appendingPathComponent("AppIcon.png"))
print("Wrote \(app.path)")
print("Wrote \(rar.path)")
