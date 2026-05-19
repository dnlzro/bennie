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
