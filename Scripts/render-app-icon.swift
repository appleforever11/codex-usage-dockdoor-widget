import AppKit

// Render the widget's Astra usage ring at every native macOS icon size.
let output = CommandLine.arguments[1]
let image = NSImage(size: NSSize(width: 1024, height: 1024))
image.lockFocus()
let tile = NSBezierPath(roundedRect: NSRect(x: 32, y: 32, width: 960, height: 960), xRadius: 216, yRadius: 216)
NSGradient(colors: [NSColor(red: 0.22, green: 0.09, blue: 0.37, alpha: 1), NSColor(red: 0.035, green: 0.015, blue: 0.09, alpha: 1)])!.draw(in: tile, angle: -65)
NSColor.white.withAlphaComponent(0.18).setStroke()
tile.lineWidth = 3
tile.stroke()
let ring = NSBezierPath()
ring.appendArc(withCenter: NSPoint(x: 512, y: 512), radius: 290, startAngle: 0, endAngle: 360)
ring.lineWidth = 58
NSColor.white.withAlphaComponent(0.09).setStroke()
ring.stroke()
let arc = NSBezierPath()
arc.appendArc(withCenter: NSPoint(x: 512, y: 512), radius: 290, startAngle: 90, endAngle: -190, clockwise: true)
arc.lineCapStyle = .round
for (width, alpha, blur) in [(70.0, 0.25, 65.0), (58.0, 1.0, 20.0)] {
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.systemPurple.withAlphaComponent(alpha)
    shadow.shadowBlurRadius = blur
    shadow.shadowOffset = .zero
    shadow.set()
    NSColor(red: 0.72, green: 0.35, blue: 1, alpha: alpha).setStroke()
    arc.lineWidth = width
    arc.stroke()
    NSGraphicsContext.restoreGraphicsState()
}
func star(_ x: CGFloat, _ y: CGFloat, _ radius: CGFloat) {
    let path = NSBezierPath()
    for i in 0..<8 {
        let angle = CGFloat(i) * .pi / 4
        let r = i % 2 == 0 ? radius : radius * 0.22
        let point = NSPoint(x: x + cos(angle) * r, y: y + sin(angle) * r)
        if i == 0 { path.move(to: point) } else { path.line(to: point) }
    }
    path.close()
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor(red: 0.85, green: 0.58, blue: 1, alpha: 1)
    shadow.shadowBlurRadius = 20
    shadow.shadowOffset = .zero
    shadow.set()
    NSColor.white.setFill()
    path.fill()
    NSGraphicsContext.restoreGraphicsState()
}
star(512, 512, 115)
star(710, 725, 58)
star(785, 575, 27)
star(340, 278, 35)
image.unlockFocus()
let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
