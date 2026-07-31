import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

private func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(red: red / 255, green: green / 255, blue: blue / 255, alpha: alpha)
}

private func makeIcon(size: Int) throws -> CGImage {
    let dimension = CGFloat(size)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        throw NSError(domain: "AntiAwayIcon", code: 1)
    }

    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)
    context.clear(CGRect(x: 0, y: 0, width: dimension, height: dimension))

    let inset = dimension * 0.065
    let tile = CGRect(x: inset, y: inset, width: dimension - inset * 2, height: dimension - inset * 2)
    let radius = dimension * 0.215
    let tilePath = CGPath(roundedRect: tile, cornerWidth: radius, cornerHeight: radius, transform: nil)

    context.saveGState()
    context.addPath(tilePath)
    context.clip()

    let background = CGGradient(
        colorsSpace: colorSpace,
        colors: [color(45, 48, 40), color(20, 21, 17)] as CFArray,
        locations: [0, 1]
    )!
    context.drawLinearGradient(
        background,
        start: CGPoint(x: tile.minX, y: tile.maxY),
        end: CGPoint(x: tile.maxX, y: tile.minY),
        options: []
    )

    let glowCenter = CGPoint(x: dimension * 0.6, y: dimension * 0.6)
    let glow = CGGradient(
        colorsSpace: colorSpace,
        colors: [color(216, 255, 88, 0.34), color(216, 255, 88, 0)] as CFArray,
        locations: [0, 1]
    )!
    context.drawRadialGradient(
        glow,
        startCenter: glowCenter,
        startRadius: 0,
        endCenter: glowCenter,
        endRadius: dimension * 0.55,
        options: []
    )
    context.restoreGState()

    context.addPath(tilePath)
    context.setStrokeColor(color(255, 255, 255, 0.15))
    context.setLineWidth(dimension * 0.012)
    context.strokePath()

    let bolt = CGMutablePath()
    bolt.move(to: CGPoint(x: dimension * 0.55, y: dimension * 0.78))
    bolt.addLine(to: CGPoint(x: dimension * 0.31, y: dimension * 0.47))
    bolt.addLine(to: CGPoint(x: dimension * 0.48, y: dimension * 0.47))
    bolt.addLine(to: CGPoint(x: dimension * 0.40, y: dimension * 0.22))
    bolt.addLine(to: CGPoint(x: dimension * 0.70, y: dimension * 0.56))
    bolt.addLine(to: CGPoint(x: dimension * 0.53, y: dimension * 0.56))
    bolt.closeSubpath()

    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -dimension * 0.018), blur: dimension * 0.035, color: color(216, 255, 88, 0.3))
    context.addPath(bolt)
    context.setFillColor(color(216, 255, 88))
    context.fillPath()
    context.restoreGState()

    guard let image = context.makeImage() else {
        throw NSError(domain: "AntiAwayIcon", code: 2)
    }
    return image
}

private func writePNG(_ image: CGImage, to url: URL) throws {
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        throw NSError(domain: "AntiAwayIcon", code: 3)
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw NSError(domain: "AntiAwayIcon", code: 4)
    }
}

let outputDirectory = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "AntiAway/Resources/Assets.xcassets/AntiAwayIcon.appiconset")
try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

for size in [16, 32, 64, 128, 256, 512, 1024] {
    try writePNG(makeIcon(size: size), to: outputDirectory.appendingPathComponent("AntiAwayIcon-\(size).png"))
}
