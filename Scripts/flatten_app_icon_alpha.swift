#!/usr/bin/env swift
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct IconJob {
    let path: String
    let backgroundRGB: (CGFloat, CGFloat, CGFloat)
}

func flattenPNG(at path: String, backgroundRGB: (CGFloat, CGFloat, CGFloat)) throws {
    let url = URL(fileURLWithPath: path)
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        throw NSError(domain: "flatten", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not read \(path)"])
    }

    let width = image.width
    let height = image.height
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.noneSkipLast.rawValue

    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: bitmapInfo
    ) else {
        throw NSError(domain: "flatten", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not create context"])
    }

    let (r, g, b) = backgroundRGB
    context.setFillColor(CGColor(red: r, green: g, blue: b, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

    guard let flattened = context.makeImage() else {
        throw NSError(domain: "flatten", code: 3, userInfo: [NSLocalizedDescriptionKey: "Could not flatten image"])
    }

    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, flattened, nil)
    guard CGImageDestinationFinalize(dest) else {
        throw NSError(domain: "flatten", code: 4, userInfo: [NSLocalizedDescriptionKey: "Could not write \(path)"])
    }
}

// Usage: swift flatten_app_icon_alpha.swift <AppIcon.appiconset path> [more paths…]
var jobs: [IconJob] = []
for arg in CommandLine.arguments.dropFirst() {
    let dir = URL(fileURLWithPath: arg, isDirectory: true)
    let name = dir.lastPathComponent
    if name == "AppIcon.appiconset", FileManager.default.fileExists(atPath: dir.appendingPathComponent("cloud9_icon-iOS-Default-1024x1024@1x.png").path) {
        jobs += [
            IconJob(path: dir.appendingPathComponent("cloud9_icon-iOS-Default-1024x1024@1x.png").path, backgroundRGB: (1, 1, 1)),
            IconJob(path: dir.appendingPathComponent("cloud9_icon-iOS-Dark-1024x1024@1x.png").path, backgroundRGB: (0, 0, 0)),
            IconJob(path: dir.appendingPathComponent("cloud9_icon-iOS-TintedLight-1024x1024@1x.png").path, backgroundRGB: (1, 1, 1)),
        ]
    } else if FileManager.default.fileExists(atPath: dir.appendingPathComponent("appstore.png").path) {
        jobs.append(IconJob(path: dir.appendingPathComponent("appstore.png").path, backgroundRGB: (0, 0, 0)))
    }
}
guard !jobs.isEmpty else {
    fputs("No icons found. Pass AppIcon.appiconset directory path(s).\n", stderr)
    exit(1)
}

for job in jobs {
    try flattenPNG(at: job.path, backgroundRGB: job.backgroundRGB)
    print("flattened: \(job.path)")
}
