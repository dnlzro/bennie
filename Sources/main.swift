import AppKit
import CoreGraphics
import Foundation
import ImageIO

// MARK: - Error

enum BennieError: LocalizedError {
  case invalidColor(String)
  case configNotFound(URL)
  case configInvalid(URL)
  case imageRenderFailed
  case heicGenerationFailed
  case fileWriteFailed(URL)
  case screenUnavailable
  case wallpaperSetFailed(URL)

  var errorDescription: String? {
    switch self {
    case .invalidColor(let hex): return "invalid hex color: \(hex)"
    case .configNotFound(let url):
      return """
        config not found at \(url.path)
        hint: create one with:
          mkdir -p ~/.config/bennie && echo '{\"light\":\"#FFFFFF\",\"dark\":\"#000000\"}' > ~/.config/bennie/config.json
        """
    case .configInvalid(let url): return "config at \(url.path) is not valid JSON"
    case .imageRenderFailed: return "failed to render solid image"
    case .heicGenerationFailed: return "failed to generate HEIC"
    case .fileWriteFailed(let url): return "failed to write \(url.path)"
    case .screenUnavailable: return "screen unavailable"
    case .wallpaperSetFailed(let url): return "failed to set wallpaper from \(url.path)"
    }
  }
}

// MARK: - Config

struct Config: Codable {
  let light: String
  let dark: String
}

func defaultConfigPath() -> URL {
  FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent(".config/bennie/config.json")
}

func loadConfig(from path: URL) throws -> Config {
  let data: Data
  do {
    data = try Data(contentsOf: path)
  } catch {
    throw BennieError.configNotFound(path)
  }
  guard let config = try? JSONDecoder().decode(Config.self, from: data) else {
    throw BennieError.configInvalid(path)
  }
  return config
}

// MARK: - Color

func parseHex(_ hex: String) throws -> CGColor {
  var h = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
  if h.hasPrefix("#") { h.removeFirst() }
  guard h.count == 6, let n = Int(h, radix: 16) else {
    throw BennieError.invalidColor(hex)
  }
  return CGColor(
    srgbRed: CGFloat((n >> 16) & 0xFF) / 255,
    green: CGFloat((n >> 8) & 0xFF) / 255,
    blue: CGFloat(n & 0xFF) / 255,
    alpha: 1)
}

// MARK: - CLI

func usage() {
  print(
    """
    bennie — solid color dynamic wallpaper for macOS

    USAGE:
      bennie                               Apply wallpaper from config file
      bennie --light <hex> --dark <hex>    Apply wallpaper, overriding config
      bennie --help                        Show this help

    OPTIONS:
      -c, --config <path>  Use a custom config file (default: ~/.config/bennie/config.json)

    """)
}

struct ParsedInput {
  let showHelp: Bool
  let lightOverride: String?
  let darkOverride: String?
  let configPathOverride: String?
}

enum ParseError: LocalizedError {
  case missingValue(flag: String)
  case unknownFlag(String)

  var errorDescription: String? {
    switch self {
    case .missingValue(let flag): return "--\(flag) requires a value"
    case .unknownFlag(let flag): return "unknown argument '\(flag)'"
    }
  }
}

func parseCLI(_ args: [String]) throws -> ParsedInput {
  var lightOverride: String?
  var darkOverride: String?
  var configPathOverride: String?
  var i = 1

  while i < args.count {
    switch args[i] {
    case "--help", "-h":
      return ParsedInput(
        showHelp: true, lightOverride: nil, darkOverride: nil, configPathOverride: nil)
    case "--light", "-l":
      guard i + 1 < args.count else { throw ParseError.missingValue(flag: "light") }
      i += 1
      lightOverride = args[i]
    case "--dark", "-d":
      guard i + 1 < args.count else { throw ParseError.missingValue(flag: "dark") }
      i += 1
      darkOverride = args[i]
    case "--config", "-c":
      guard i + 1 < args.count else { throw ParseError.missingValue(flag: "config") }
      i += 1
      configPathOverride = args[i]
    default:
      throw ParseError.unknownFlag(args[i])
    }
    i += 1
  }

  return ParsedInput(
    showHelp: false,
    lightOverride: lightOverride,
    darkOverride: darkOverride,
    configPathOverride: configPathOverride)
}

// MARK: - Appearance metadata

func dynamicDesktopMetadata(lightIndex: Int, darkIndex: Int) -> CGImageMetadata {
  let md = CGImageMetadataCreateMutable()
  let apr: [String: Int] = ["l": lightIndex, "d": darkIndex]
  let b64 =
    (try! PropertyListSerialization.data(fromPropertyList: apr, format: .binary, options: 0))
    .base64EncodedString()
  CGImageMetadataRegisterNamespaceForPrefix(
    md, "http://ns.apple.com/namespace/1.0/" as CFString, "apple_desktop" as CFString, nil)
  CGImageMetadataSetTagWithPath(
    md, nil, "apple_desktop:apr" as CFString,
    CGImageMetadataTagCreate(
      "http://ns.apple.com/namespace/1.0/" as CFString, "apple_desktop" as CFString,
      "apr" as CFString, .string, b64 as CFTypeRef)!)
  return md
}

// MARK: - Dynamic HEIC

func solidImage(_ color: CGColor) -> CGImage? {
  let info = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue).union(
    .byteOrder32Little)
  guard
    let ctx = CGContext(
      data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 0,
      space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: info.rawValue)
  else { return nil }
  ctx.setFillColor(color)
  ctx.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
  return ctx.makeImage()
}

func encodeDynamicHEIC(light: CGColor, dark: CGColor) throws -> Data {
  guard let li = solidImage(light), let di = solidImage(dark) else {
    throw BennieError.imageRenderFailed
  }

  let data = NSMutableData()
  guard let dest = CGImageDestinationCreateWithData(data, "public.heic" as CFString, 2, nil) else {
    throw BennieError.heicGenerationFailed
  }

  let md = dynamicDesktopMetadata(lightIndex: 0, darkIndex: 1)

  CGImageDestinationAddImageAndMetadata(dest, li, md, nil)
  CGImageDestinationAddImage(dest, di, nil)
  guard CGImageDestinationFinalize(dest) else {
    throw BennieError.heicGenerationFailed
  }

  return data as Data
}

func createDynamicHEIC(light: CGColor, dark: CGColor, to url: URL) throws {
  let data = try encodeDynamicHEIC(light: light, dark: dark)
  do {
    try data.write(to: url, options: .atomic)
  } catch {
    throw BennieError.fileWriteFailed(url)
  }
}

// MARK: - Wallpaper

func applyWallpaper(config: Config) throws {
  let cacheDir = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent(".cache/bennie")
  try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)

  let path = cacheDir.appendingPathComponent("dynamic-\(Int(Date().timeIntervalSince1970)).heic")

  let lightColor = try parseHex(config.light)
  let darkColor = try parseHex(config.dark)
  try createDynamicHEIC(light: lightColor, dark: darkColor, to: path)

  guard let screen = NSScreen.main else {
    throw BennieError.screenUnavailable
  }
  try NSWorkspace.shared.setDesktopImageURL(
    path, for: screen,
    options: [
      .imageScaling: NSImageScaling.scaleAxesIndependently.rawValue,
      .allowClipping: false,
    ])

  for f
    in (try? FileManager.default.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: nil))
    ?? []
  {
    if f != path, f.lastPathComponent.hasPrefix("dynamic-") {
      try? FileManager.default.removeItem(at: f)
    }
  }
}

// MARK: - Main

let input: ParsedInput
do {
  input = try parseCLI(CommandLine.arguments)
} catch {
  fputs("error: \(error.localizedDescription)\n", stderr)
  usage()
  exit(1)
}

if input.showHelp {
  usage()
  exit(0)
}

let configPath: URL
if let override = input.configPathOverride {
  configPath = URL(fileURLWithPath: (override as NSString).expandingTildeInPath)
} else {
  configPath = defaultConfigPath()
}

let config: Config
do {
  if let light = input.lightOverride, let dark = input.darkOverride {
    config = Config(light: light, dark: dark)
  } else {
    let base = try loadConfig(from: configPath)
    config = Config(
      light: input.lightOverride ?? base.light, dark: input.darkOverride ?? base.dark)
  }
} catch {
  fputs("error: \(error.localizedDescription)\n", stderr)
  exit(1)
}

do {
  try applyWallpaper(config: config)
} catch {
  fputs("error: \(error.localizedDescription)\n", stderr)
  exit(1)
}
