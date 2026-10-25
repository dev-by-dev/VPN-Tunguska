#!/usr/bin/env swift
import AppKit
import CoreGraphics
import Foundation

let root = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
let appIconSet = root
    .appendingPathComponent("Resources/Assets.xcassets/AppIcon.appiconset", isDirectory: true)
let accentSet = root
    .appendingPathComponent("Resources/Assets.xcassets/AccentColor.colorset", isDirectory: true)

try FileManager.default.createDirectory(at: appIconSet, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: accentSet, withIntermediateDirectories: true)

struct IconVariant {
    let name: String
    let pixels: Int
}

let variants: [IconVariant] = [
    .init(name: "icon_16x16", pixels: 16),
    .init(name: "icon_16x16@2x", pixels: 32),
    .init(name: "icon_32x32", pixels: 32),
    .init(name: "icon_32x32@2x", pixels: 64),
    .init(name: "icon_128x128", pixels: 128),
    .init(name: "icon_128x128@2x", pixels: 256),
    .init(name: "icon_256x256", pixels: 256),
    .init(name: "icon_256x256@2x", pixels: 512),
    .init(name: "icon_512x512", pixels: 512),
    .init(name: "icon_512x512@2x", pixels: 1024),
]

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(red: red, green: green, blue: blue, alpha: alpha)
}

func drawIcon(size: Int) -> CGImage? {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }

    let s = CGFloat(size)
    context.clear(CGRect(x: 0, y: 0, width: s, height: s))
    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)
    context.interpolationQuality = .high

    // Rounded macOS icon silhouette.
    let inset = s * 0.055
    let rect = CGRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
    let radius = s * 0.22
    let background = CGPath(
        roundedRect: rect,
        cornerWidth: radius,
        cornerHeight: radius,
        transform: nil
    )
    context.saveGState()
    context.addPath(background)
    context.clip()
    let bgGradient = CGGradient(
        colorsSpace: colorSpace,
        colors: [
            color(0.025, 0.075, 0.12),
            color(0.035, 0.16, 0.22),
            color(0.015, 0.05, 0.085),
        ] as CFArray,
        locations: [0, 0.55, 1]
    )!
    context.drawLinearGradient(
        bgGradient,
        start: CGPoint(x: s * 0.2, y: s * 0.9),
        end: CGPoint(x: s * 0.85, y: s * 0.1),
        options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
    )

    // Instrument-grid texture.
    context.setStrokeColor(color(0.28, 0.83, 0.84, 0.08))
    context.setLineWidth(max(1, s * 0.002))
    let gridStep = s / 12
    for index in 1 ..< 12 {
        let offset = CGFloat(index) * gridStep
        context.move(to: CGPoint(x: offset, y: inset))
        context.addLine(to: CGPoint(x: offset, y: s - inset))
        context.move(to: CGPoint(x: inset, y: offset))
        context.addLine(to: CGPoint(x: s - inset, y: offset))
    }
    context.strokePath()

    let center = CGPoint(x: s * 0.5, y: s * 0.5)
    let outerRadius = s * 0.31

    // Outer halo.
    let halo = CGGradient(
        colorsSpace: colorSpace,
        colors: [color(0.25, 0.95, 0.88, 0.28), color(0.1, 0.65, 0.72, 0)] as CFArray,
        locations: [0, 1]
    )!
    context.drawRadialGradient(
        halo,
        startCenter: center,
        startRadius: outerRadius * 0.72,
        endCenter: center,
        endRadius: outerRadius * 1.23,
        options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
    )

    // Circular gauge channels.
    context.setLineCap(.round)
    context.setStrokeColor(color(0.18, 0.55, 0.60, 0.35))
    context.setLineWidth(max(1.5, s * 0.013))
    context.strokeEllipse(in: CGRect(
        x: center.x - outerRadius,
        y: center.y - outerRadius,
        width: outerRadius * 2,
        height: outerRadius * 2
    ))
    context.setStrokeColor(color(0.55, 0.94, 0.89, 0.44))
    context.setLineWidth(max(1, s * 0.006))
    let innerRadius = outerRadius * 0.78
    context.strokeEllipse(in: CGRect(
        x: center.x - innerRadius,
        y: center.y - innerRadius,
        width: innerRadius * 2,
        height: innerRadius * 2
    ))

    // Glowing signal arc.
    context.setStrokeColor(color(0.25, 0.95, 0.87))
    context.setLineWidth(max(2, s * 0.026))
    context.addArc(
        center: center,
        radius: outerRadius,
        startAngle: .pi * 0.22,
        endAngle: .pi * 0.78,
        clockwise: false
    )
    context.strokePath()

    // Instrument ticks.
    for index in 0 ..< 24 {
        let angle = CGFloat(index) / 24 * .pi * 2
        let isMajor = index % 3 == 0
        let start = innerRadius * 1.06
        let end = innerRadius * (isMajor ? 1.17 : 1.12)
        context.setStrokeColor(color(0.65, 0.96, 0.93, isMajor ? 0.72 : 0.36))
        context.setLineWidth(max(1, s * (isMajor ? 0.006 : 0.003)))
        context.move(to: CGPoint(
            x: center.x + cos(angle) * start,
            y: center.y + sin(angle) * start
        ))
        context.addLine(to: CGPoint(
            x: center.x + cos(angle) * end,
            y: center.y + sin(angle) * end
        ))
        context.strokePath()
    }

    // Central luminous core.
    let coreRadius = s * 0.085
    let core = CGGradient(
        colorsSpace: colorSpace,
        colors: [color(0.82, 1, 0.98), color(0.20, 0.88, 0.80), color(0.04, 0.35, 0.42)] as CFArray,
        locations: [0, 0.55, 1]
    )!
    context.saveGState()
    context.addEllipse(in: CGRect(
        x: center.x - coreRadius,
        y: center.y - coreRadius,
        width: coreRadius * 2,
        height: coreRadius * 2
    ))
    context.clip()
    context.drawRadialGradient(
        core,
        startCenter: CGPoint(x: center.x - coreRadius * 0.28, y: center.y + coreRadius * 0.28),
        startRadius: 0,
        endCenter: center,
        endRadius: coreRadius,
        options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
    )
    context.restoreGState()

    // Comet trajectory: a sharp diagonal cut through the gauge.
    context.setLineCap(.round)
    context.setStrokeColor(color(0.90, 1, 0.99, 0.95))
    context.setLineWidth(max(1.2, s * 0.010))
    context.move(to: CGPoint(x: s * 0.68, y: s * 0.73))
    context.addLine(to: CGPoint(x: s * 0.86, y: s * 0.86))
    context.strokePath()
    context.setFillColor(color(0.90, 1, 0.99, 0.98))
    let sparkRadius = s * 0.018
    context.fillEllipse(in: CGRect(
        x: s * 0.86 - sparkRadius,
        y: s * 0.86 - sparkRadius,
        width: sparkRadius * 2,
        height: sparkRadius * 2
    ))

    context.restoreGState()

    // Fine inner border.
    context.addPath(background)
    context.setStrokeColor(color(0.55, 0.95, 0.90, 0.20))
    context.setLineWidth(max(1, s * 0.004))
    context.strokePath()

    return context.makeImage()
}

for variant in variants {
    guard let image = drawIcon(size: variant.pixels) else {
        fatalError("Could not render \(variant.pixels)px icon")
    }
    let rep = NSBitmapImageRep(cgImage: image)
    guard let data = rep.representation(using: .png, properties: [:]) else {
        fatalError("Could not encode \(variant.name)")
    }
    try data.write(to: appIconSet.appendingPathComponent("\(variant.name).png"))
}

let appIconContents: [String: Any] = [
    "images": variants.map { variant in
        [
            "filename": "\(variant.name).png",
            "idiom": "mac",
            "scale": variant.name.contains("@2x") ? "2x" : "1x",
            "size": variant.name
                .replacingOccurrences(of: "icon_", with: "")
                .replacingOccurrences(of: "@2x", with: "")
                .replacingOccurrences(of: ".png", with: ""),
        ]
    },
    "info": ["author": "xcode", "version": 1],
]
let appIconJSON = try JSONSerialization.data(withJSONObject: appIconContents, options: [.prettyPrinted, .sortedKeys])
try appIconJSON.write(to: appIconSet.appendingPathComponent("Contents.json"))

let accentContents: [String: Any] = [
    "colors": [
        [
            "color": [
                "color-space": "srgb",
                "components": [
                    "alpha": "1.000",
                    "blue": "0.875",
                    "green": "0.945",
                    "red": "0.251",
                ],
            ],
            "idiom": "universal",
        ],
    ],
    "info": ["author": "xcode", "version": 1],
]
let accentJSON = try JSONSerialization.data(withJSONObject: accentContents, options: [.prettyPrinted, .sortedKeys])
try accentJSON.write(to: accentSet.appendingPathComponent("Contents.json"))

let assetsContents = """
{
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
"""
try assetsContents.write(
    to: root.appendingPathComponent("Resources/Assets.xcassets/Contents.json"),
    atomically: true,
    encoding: .utf8
)

print("Generated app icons in \(appIconSet.path)")
