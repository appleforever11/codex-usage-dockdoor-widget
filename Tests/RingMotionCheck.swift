import AppKit
let root = CommandLine.arguments[1]
let a = NSBitmapImageRep(data: try Data(contentsOf: URL(fileURLWithPath: root + "/ring-frame-1.png")))!
let b = NSBitmapImageRep(data: try Data(contentsOf: URL(fileURLWithPath: root + "/ring-frame-2.png")))!
precondition(a.pixelsWide == b.pixelsWide && a.pixelsHigh == b.pixelsHigh)
let w = a.pixelsWide, h = a.pixelsHigh
for (name, xs, ys, expected) in [("Astra", 0..<w/4, 0..<h/2, true), ("Other models", w/4..<w, 0..<h/2, false), ("Reduced motion path", 0..<w, h/2..<h, false)] {
 var changed = false
 for y in ys {
  for x in xs {
   if a.colorAt(x: x, y: y) != b.colorAt(x: x, y: y) { changed = true; break }
  }
  if changed { break }
 }
 precondition(changed == expected, name)
 print("\(name): \(changed ? "animated" : "static")")
}
