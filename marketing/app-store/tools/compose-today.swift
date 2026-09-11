import AppKit

let canvasWidth = 1290
let canvasHeight = 2796

let arguments = CommandLine.arguments
guard arguments.count == 4 else {
    fputs("Usage: compose-today.swift <background> <device-frame> <output>\n", stderr)
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
NSColor(red: 0.94, green: 0.87, blue: 0.72, alpha: 1).setFill()
canvas.fill()
drawAspectFill(background, in: canvas)

// A light parchment veil keeps the set calm and protects dark-copy contrast.
NSColor(red: 1.0, green: 0.97, blue: 0.88, alpha: 0.08).setFill()
canvas.fill(using: .sourceOver)

let ink = NSColor(red: 0.035, green: 0.20, blue: 0.18, alpha: 1)
let secondary = NSColor(red: 0.17, green: 0.31, blue: 0.28, alpha: 1)

drawCenteredText(
    "Keep all five\nprayers close",
    top: 118,
    width: 1100,
    height: 286,
    font: .systemFont(ofSize: 116, weight: .bold),
    color: ink,
    lineSpacing: -2
)

drawCenteredText(
    "Prayer times and a gentle way\nto record each salah.",
    top: 420,
    width: 1040,
    height: 132,
    font: .systemFont(ofSize: 45, weight: .regular),
    color: secondary,
    lineSpacing: 7
)

let screenWidth: CGFloat = 1008
let screenHeight = screenWidth * device.size.height / device.size.width
let bezel: CGFloat = 24
let deviceTop: CGFloat = 650
let outerWidth = screenWidth + bezel * 2
let outerHeight = screenHeight + bezel * 2
let outerX = (CGFloat(canvasWidth) - outerWidth) / 2
let outerRect = rectFromTop(
    x: outerX,
    y: deviceTop,
    width: outerWidth,
    height: outerHeight
)

// Hardware controls sit behind the phone body.
let hardware = NSColor(red: 0.055, green: 0.055, blue: 0.060, alpha: 1)
hardware.setFill()
for button in [
    rectFromTop(x: outerX - 10, y: deviceTop + 286, width: 18, height: 82),
    rectFromTop(x: outerX - 10, y: deviceTop + 410, width: 18, height: 146),
    rectFromTop(x: outerX - 10, y: deviceTop + 586, width: 18, height: 146),
    rectFromTop(x: outerX + outerWidth - 8, y: deviceTop + 438, width: 18, height: 198)
] {
    NSBezierPath(roundedRect: button, xRadius: 7, yRadius: 7).fill()
}

let outerPath = NSBezierPath(roundedRect: outerRect, xRadius: 154, yRadius: 154)
let shadow = NSShadow()
shadow.shadowColor = NSColor(red: 0.19, green: 0.10, blue: 0.05, alpha: 0.34)
shadow.shadowBlurRadius = 48
shadow.shadowOffset = NSSize(width: 0, height: -15)

NSGraphicsContext.current?.saveGraphicsState()
shadow.set()
NSColor(red: 0.020, green: 0.022, blue: 0.024, alpha: 1).setFill()
outerPath.fill()
NSGraphicsContext.current?.restoreGraphicsState()

NSColor(red: 0.24, green: 0.24, blue: 0.26, alpha: 1).setStroke()
outerPath.lineWidth = 4
outerPath.stroke()

let screenRect = NSRect(
    x: outerRect.minX + bezel,
    y: outerRect.minY + bezel,
    width: screenWidth,
    height: screenHeight
)
let screenPath = NSBezierPath(roundedRect: screenRect, xRadius: 125, yRadius: 125)

NSGraphicsContext.current?.saveGraphicsState()
screenPath.addClip()
device.draw(
    in: screenRect,
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
