import AppKit

let canvasWidth = 1290
let canvasHeight = 2796

let arguments = CommandLine.arguments
guard arguments.count == 4 else {
    fputs("Usage: compose-focus.swift <background> <device-frame> <output>\n", stderr)
    exit(2)
}

let backgroundURL = URL(fileURLWithPath: arguments[1])
let deviceURL = URL(fileURLWithPath: arguments[2])
let outputURL = URL(fileURLWithPath: arguments[3])

guard
    let background = NSImage(contentsOf: backgroundURL),
    let device = NSImage(contentsOf: deviceURL),
    let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: canvasWidth,
        pixelsHigh: canvasHeight,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: canvasWidth * 4,
        bitsPerPixel: 32
    ),
    let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmap)
else {
    fputs("Could not prepare image assets.\n", stderr)
    exit(1)
}

func rectFromTop(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) -> NSRect {
    NSRect(
        x: x,
        y: CGFloat(canvasHeight) - y - height,
        width: width,
        height: height
    )
}

func drawAspectFill(_ image: NSImage, in bounds: NSRect) {
    let imageSize = image.size
    let scale = max(bounds.width / imageSize.width, bounds.height / imageSize.height)
    let size = NSSize(width: imageSize.width * scale, height: imageSize.height * scale)
    let destination = NSRect(
        x: bounds.midX - size.width / 2,
        y: bounds.midY - size.height / 2,
        width: size.width,
        height: size.height
    )

    NSGraphicsContext.current?.saveGraphicsState()
    NSBezierPath(rect: bounds).addClip()
    image.draw(
        in: destination,
        from: .zero,
        operation: .sourceOver,
        fraction: 1,
        respectFlipped: false,
        hints: [.interpolation: NSImageInterpolation.high]
    )
    NSGraphicsContext.current?.restoreGraphicsState()
}

func drawCenteredText(
    _ text: String,
    top: CGFloat,
    width: CGFloat,
    height: CGFloat,
    font: NSFont,
    color: NSColor,
    lineSpacing: CGFloat = 0
) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    paragraph.lineBreakMode = .byWordWrapping
    paragraph.lineSpacing = lineSpacing

    let attributed = NSAttributedString(
        string: text,
        attributes: [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ]
    )

    let rect = rectFromTop(
        x: (CGFloat(canvasWidth) - width) / 2,
        y: top,
        width: width,
        height: height
    )
    attributed.draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading])
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = graphicsContext
graphicsContext.imageInterpolation = .high

let canvas = NSRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight)
NSColor(red: 0.025, green: 0.018, blue: 0.055, alpha: 1).setFill()
canvas.fill()
drawAspectFill(background, in: canvas)

// A restrained dark veil keeps the copy legible and lets the real UI dominate.
NSColor(calibratedWhite: 0.0, alpha: 0.10).setFill()
canvas.fill(using: .sourceOver)

let cream = NSColor(red: 0.985, green: 0.956, blue: 0.875, alpha: 1)
let secondary = NSColor(red: 0.91, green: 0.88, blue: 0.82, alpha: 1)

drawCenteredText(
    "Make space for salah",
    top: 152,
    width: 1100,
    height: 150,
    font: .systemFont(ofSize: 112, weight: .bold),
    color: cream
)

drawCenteredText(
    "Optional Screen Time shields pause distractions\nat prayer time.",
    top: 308,
    width: 1040,
    height: 132,
    font: .systemFont(ofSize: 45, weight: .regular),
    color: secondary,
    lineSpacing: 7
)

let deviceWidth: CGFloat = 1080
let deviceHeight = deviceWidth * device.size.height / device.size.width
let deviceRect = rectFromTop(
    x: (CGFloat(canvasWidth) - deviceWidth) / 2,
    y: 690,
    width: deviceWidth,
    height: deviceHeight
)

let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.72)
shadow.shadowBlurRadius = 58
shadow.shadowOffset = NSSize(width: 0, height: -16)

NSGraphicsContext.current?.saveGraphicsState()
shadow.set()
device.draw(
    in: deviceRect,
    from: .zero,
    operation: .sourceOver,
    fraction: 1,
    respectFlipped: false,
    hints: [.interpolation: NSImageInterpolation.high]
)
NSGraphicsContext.current?.restoreGraphicsState()

NSGraphicsContext.restoreGraphicsState()

let outputType: NSBitmapImageRep.FileType =
    ["jpg", "jpeg"].contains(outputURL.pathExtension.lowercased()) ? .jpeg : .png
let properties: [NSBitmapImageRep.PropertyKey: Any] =
    outputType == .jpeg ? [.compressionFactor: 1.0] : [:]

guard let data = bitmap.representation(using: outputType, properties: properties) else {
    fputs("Could not encode output image.\n", stderr)
    exit(1)
}

do {
    try data.write(to: outputURL, options: .atomic)
} catch {
    fputs("Could not write output: \(error)\n", stderr)
    exit(1)
}
