import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

for path in CommandLine.arguments.dropFirst() {
    let url = URL(fileURLWithPath: path)
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
          let context = CGContext(data: nil, width: image.width, height: image.height,
            bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
        fatalError("Cannot read icon: \(path)")
    }
    let rect = CGRect(x: 0, y: 0, width: image.width, height: image.height)
    context.setFillColor(CGColor(gray: 1, alpha: 1))
    context.fill(rect)
    context.draw(image, in: rect)
    let output = context.makeImage()!
    let temporary = url.deletingLastPathComponent().appendingPathComponent(UUID().uuidString + ".png")
    guard let destination = CGImageDestinationCreateWithURL(temporary as CFURL,
            UTType.png.identifier as CFString, 1, nil) else { fatalError("Cannot encode icon") }
    CGImageDestinationAddImage(destination, output, nil)
    guard CGImageDestinationFinalize(destination) else { fatalError("Cannot write icon") }
    _ = try FileManager.default.replaceItemAt(url, withItemAt: temporary)
    print("Opaque PNG: \(path)")
}
