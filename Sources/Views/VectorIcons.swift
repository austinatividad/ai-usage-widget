import SwiftUI
import AppKit

@MainActor
public enum IconAssetCache {
    public static let logoImage: NSImage? = {
        if let url = Bundle.module.url(forResource: "logo", withExtension: "jpg"),
           let img = NSImage(contentsOf: url) {
            return img
        }
        return nil
    }()
    
    public static let claudeImage: NSImage? = {
        if let url = Bundle.module.url(forResource: "claude", withExtension: "svg"),
           let img = NSImage(contentsOf: url) {
            img.size = NSSize(width: 16, height: 16)
            return img
        }
        return nil
    }()
    
    public static let antigravityImage: NSImage? = {
        if let url = Bundle.module.url(forResource: "antigravity", withExtension: "svg"),
           let img = NSImage(contentsOf: url) {
            img.size = NSSize(width: 16, height: 16)
            return img
        }
        return nil
    }()
    
    public static let codexImage: NSImage? = {
        if let url = Bundle.module.url(forResource: "codex", withExtension: "png"),
           let img = NSImage(contentsOf: url) {
            img.size = NSSize(width: 16, height: 16)
            return img
        } else if let url = Bundle.module.url(forResource: "codex", withExtension: "svg"),
                  let img = NSImage(contentsOf: url) {
            img.size = NSSize(width: 16, height: 16)
            return img
        }
        return nil
    }()
}

public struct TachoLogoView: View {
    public var size: CGFloat
    public var cornerRadius: CGFloat?
    
    public init(size: CGFloat = 32, cornerRadius: CGFloat? = nil) {
        self.size = size
        self.cornerRadius = cornerRadius
    }
    
    public var body: some View {
        let radius = cornerRadius ?? (size * 0.22)
        if let image = IconAssetCache.logoImage {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 0.75)
                )
        } else {
            Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundColor(.white)
                .frame(width: size * 0.75, height: size * 0.75)
                .frame(width: size, height: size)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        }
    }
}

public struct ClaudeIconView: View {
    public var size: CGFloat = 16
    
    public init(size: CGFloat = 16) {
        self.size = size
    }
    
    public var body: some View {
        if let image = IconAssetCache.claudeImage {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
        } else {
            Image(systemName: "circle.hexagongrid.fill")
                .resizable()
                .foregroundColor(Color(red: 217/255, green: 119/255, blue: 87/255))
                .frame(width: size, height: size)
        }
    }
}

public struct AntigravityIconView: View {
    public var size: CGFloat = 16
    
    public init(size: CGFloat = 16) {
        self.size = size
    }
    
    public var body: some View {
        if let image = IconAssetCache.antigravityImage {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
        } else {
            Image(systemName: "sparkle")
                .resizable()
                .foregroundColor(Color(red: 255/255, green: 199/255, blue: 0/255))
                .frame(width: size, height: size)
        }
    }
}

public struct CodexIconView: View {
    public var size: CGFloat = 16
    
    public init(size: CGFloat = 16) {
        self.size = size
    }
    
    public var body: some View {
        if let image = IconAssetCache.codexImage {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
        } else {
            Image(systemName: "bolt.circle.fill")
                .resizable()
                .foregroundColor(Color(red: 16/255, green: 163/255, blue: 127/255))
                .frame(width: size, height: size)
        }
    }
}
