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
    let scale = 1
    let pixels = dimension * scale
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
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
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high
    NSGraphicsContext.current?.shouldAntialias = true
    draw(CGFloat(dimension))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

func roundedRect(_ rect: NSRect, radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

func drawAppIcon(in size: CGFloat) {
    NSColor.clear.setFill()
    NSRect(x: 0, y: 0, width: size, height: size).fill()

    let inset = size * 0.08
    let board = NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
    let radius = size * 0.22
    let fill = NSColor(calibratedRed: 0.10, green: 0.37, blue: 0.53, alpha: 1)
    fill.setFill()
    roundedRect(board, radius: radius).fill()

    let lid = NSRect(
        x: board.minX + size * 0.18,
        y: board.minY + size * 0.52,
        width: board.width - size * 0.36,
        height: size * 0.16
    )
    let body = NSRect(
        x: board.minX + size * 0.22,
        y: board.minY + size * 0.22,
        width: board.width - size * 0.44,
        height: size * 0.36
    )
    NSColor.white.setFill()
    roundedRect(lid, radius: size * 0.04).fill()
    roundedRect(body, radius: size * 0.045).fill()

    let stripe = NSRect(x: body.midX - size * 0.035, y: body.minY, width: size * 0.07, height: body.height + lid.height * 0.35)
    fill.setFill()
    roundedRect(stripe, radius: size * 0.02).fill()
}

func drawRARIcon(in size: CGFloat) {
    NSColor.clear.setFill()
    NSRect(x: 0, y: 0, width: size, height: size).fill()

    let page = NSRect(x: size * 0.16, y: size * 0.08, width: size * 0.68, height: size * 0.84)
    let radius = size * 0.08
    NSColor.white.setFill()
    NSColor(calibratedWhite: 0.75, alpha: 1).setStroke()
    let path = roundedRect(page, radius: radius)
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
    NSColor(calibratedRed: 0.10, green: 0.37, blue: 0.53, alpha: 1).setFill()
    roundedRect(badge, radius: size * 0.04).fill()

    let text = "RAR" as NSString
    let fontSize = size * 0.12
    let font = NSFont.systemFont(ofSize: fontSize, weight: .heavy)
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor.white,
    ]
    let textSize = text.size(withAttributes: attrs)
    let point = NSPoint(
        x: badge.midX - textSize.width / 2,
        y: badge.midY - textSize.height / 2
    )
    text.draw(at: point, withAttributes: attrs)

    let box = NSRect(x: page.midX - size * 0.16, y: page.minY + size * 0.42, width: size * 0.32, height: size * 0.22)
    NSColor(calibratedRed: 0.10, green: 0.37, blue: 0.53, alpha: 1).setStroke()
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
print("Wrote \(app.path)")
print("Wrote \(rar.path)")
