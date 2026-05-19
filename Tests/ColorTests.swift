import CoreGraphics
import Foundation
import Testing

@testable import bennie

// parseHex converts a 6-char hex string (with or without #) into an sRGB
// CGColor. Whitespace is trimmed, case is normalised, anything else throws.

@Test("#FF0000 → red=1, green=0, blue=0")
func validHexWithHash() throws {
  let c = try parseHex("#FF0000")
  #expect(c.components?[0] == 1.0)
  #expect(c.components?[1] == 0.0)
  #expect(c.components?[2] == 0.0)
}

@Test("00FF00 without # → green=1")
func validHexWithoutHash() throws {
  let c = try parseHex("00FF00")
  #expect(c.components?[0] == 0.0)
  #expect(c.components?[1] == 1.0)
  #expect(c.components?[2] == 0.0)
}

@Test("Lowercase #abcdef parses correctly")
func lowercaseHex() throws {
  let c = try parseHex("#abcdef")
  #expect(c.components?[0] == CGFloat(0xAB) / 255)
  #expect(c.components?[1] == CGFloat(0xCD) / 255)
  #expect(c.components?[2] == CGFloat(0xEF) / 255)
}

@Test("#FFFFFF → white")
func white() throws {
  let c = try parseHex("#FFFFFF")
  #expect(c.components?[0] == 1.0)
  #expect(c.components?[1] == 1.0)
  #expect(c.components?[2] == 1.0)
}

@Test("#000000 → black")
func black() throws {
  let c = try parseHex("#000000")
  #expect(c.components?[0] == 0.0)
  #expect(c.components?[1] == 0.0)
  #expect(c.components?[2] == 0.0)
}

@Test("Whitespace around hex is trimmed")
func hexWithWhitespace() throws {
  let c = try parseHex("  #FF8800  ")
  #expect(c.components?[0] == 1.0)
  #expect(c.components?[1] == CGFloat(0x88) / 255)
  #expect(c.components?[2] == 0.0)
}

// Only exactly 6 hex chars are accepted (after stripping #).
// 3-char, 8-char, empty, and non-hex all throw.

@Test("#FFF (3-char) throws invalidColor")
func invalidHexTooShort() {
  do {
    _ = try parseHex("#FFF")
    #expect(Bool(false), "expected throw")
  } catch BennieError.invalidColor(let hex) {
    #expect(hex == "#FFF")
  } catch {
    #expect(Bool(false), "wrong error: \(error)")
  }
}

@Test("Empty string throws invalidColor")
func invalidHexEmpty() {
  do {
    _ = try parseHex("")
    #expect(Bool(false), "expected throw")
  } catch BennieError.invalidColor(let hex) {
    #expect(hex == "")
  } catch {
    #expect(Bool(false), "wrong error: \(error)")
  }
}

@Test("#ZZZZZZ (non-hex chars) throws invalidColor")
func invalidHexNonHexChars() {
  do {
    _ = try parseHex("#ZZZZZZ")
    #expect(Bool(false), "expected throw")
  } catch BennieError.invalidColor(let hex) {
    #expect(hex == "#ZZZZZZ")
  } catch {
    #expect(Bool(false), "wrong error: \(error)")
  }
}

@Test("#FF0000FF (8-char) throws invalidColor")
func invalidHexTooLong() {
  do {
    _ = try parseHex("#FF0000FF")
    #expect(Bool(false), "expected throw")
  } catch BennieError.invalidColor(let hex) {
    #expect(hex == "#FF0000FF")
  } catch {
    #expect(Bool(false), "wrong error: \(error)")
  }
}
