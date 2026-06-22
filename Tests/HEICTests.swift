import CoreGraphics
import Foundation
import ImageIO
import Testing

@testable import bennie

// A dynamic wallpaper is a 2-image HEIC. macOS reads "apple_desktop:apr" on
// image 0 to know which index is light and which is dark.

@Test("HEIC contains exactly 2 images")
func encodesTwoImages() throws {
  let light = CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1)
  let dark = CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1)

  let data = try encodeDynamicHEIC(light: light, dark: dark)

  let src = try #require(CGImageSourceCreateWithData(data as CFData, nil))
  #expect(CGImageSourceGetCount(src) == 2)
}

// The apr tag is an XMP tag containing a base64-encoded binary plist
// {"l":0,"d":1}. This tells macOS: image 0 → light mode, image 1 → dark mode.
@Test("First image has apple_desktop:apr metadata with l=0, d=1")
func encodesMetadata() throws {
  let light = CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1)
  let dark = CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1)

  let data = try encodeDynamicHEIC(light: light, dark: dark)

  let src = try #require(CGImageSourceCreateWithData(data as CFData, nil))
  let md = try #require(CGImageSourceCopyMetadataAtIndex(src, 0, nil))
  let tag = try #require(
    CGImageMetadataCopyTagWithPath(md, nil, "apple_desktop:apr" as CFString))
  let b64 = try #require(CGImageMetadataTagCopyValue(tag) as? String)
  let plistData = try #require(Data(base64Encoded: b64))
  let apr = try #require(
    PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Int])
  #expect(apr["l"] == 0)
  #expect(apr["d"] == 1)
}

// Bennie generates solid-colour wallpapers of a single pixel, which is
// stretched by the OS.
@Test("First image is a 1×1 pixel")
func encodesFirstImagePixels() throws {
  let light = CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1)
  let dark = CGColor(srgbRed: 0, green: 0, blue: 1, alpha: 1)

  let data = try encodeDynamicHEIC(light: light, dark: dark)

  let src = try #require(CGImageSourceCreateWithData(data as CFData, nil))
  let img = try #require(CGImageSourceCreateImageAtIndex(src, 0, nil))
  #expect(img.width == 1)
  #expect(img.height == 1)
}

// Only the first image gets the apr tag. The dark image gets none; macOS
// infers dark mode from the untagged image.
@Test("Second image has no apple_desktop:apr tag")
func secondImageHasNoAppearanceMetadata() throws {
  let light = CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1)
  let dark = CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1)

  let data = try encodeDynamicHEIC(light: light, dark: dark)

  let src = try #require(CGImageSourceCreateWithData(data as CFData, nil))
  let md = try #require(CGImageSourceCopyMetadataAtIndex(src, 1, nil))
  let tag = CGImageMetadataCopyTagWithPath(md, nil, "apple_desktop:apr" as CFString)
  #expect(tag == nil)
}

// Lossy HEVC compression can mangle solid-color 1×1 images due to chroma
// subsampling, shifting colours (e.g. light grey turning green). This test
// asserts lossless encoding preserves RGB values within ±1 (HEIC's YUV
// round-trip can introduce minor rounding, but catastrophic shifts like the
// original green-tint bug would fail this).
@Test("HEIC round-trip preserves exact sRGB color values")
func roundTripPreservesColor() throws {
  let light = CGColor(srgbRed: 0xF9 / 255, green: 0xC8 / 255, blue: 0xE4 / 255, alpha: 1)
  let dark = CGColor(srgbRed: 0x1A / 255, green: 0x2B / 255, blue: 0x3C / 255, alpha: 1)

  let data = try encodeDynamicHEIC(light: light, dark: dark)

  let src = try #require(CGImageSourceCreateWithData(data as CFData, nil))
  #expect(CGImageSourceGetCount(src) == 2)

  let li = try #require(CGImageSourceCreateImageAtIndex(src, 0, nil))
  let di = try #require(CGImageSourceCreateImageAtIndex(src, 1, nil))

  let pixels: [(CGImage, (Int, Int, Int))] = [
    (li, (0xF9, 0xC8, 0xE4)),
    (di, (0x1A, 0x2B, 0x3C)),
  ]
  for (img, (er, eg, eb)) in pixels {
    let ctx = try #require(
      CGContext(
        data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 0,
        space: img.colorSpace!,
        bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
          | CGBitmapInfo.byteOrder32Little.rawValue))
    ctx.draw(img, in: CGRect(x: 0, y: 0, width: 1, height: 1))
    let p = ctx.data!.assumingMemoryBound(to: UInt8.self)
    let r = Int(p[2]), g = Int(p[1]), b = Int(p[0])
    #expect(abs(r - er) <= 1 && abs(g - eg) <= 1 && abs(b - eb) <= 1)
  }
}
