import SwiftUI
import AppKit

@MainActor
private enum IconAssetCache {
    static let claudeImage: NSImage? = {
        if let url = Bundle.module.url(forResource: "claude", withExtension: "svg"),
           let img = NSImage(contentsOf: url) {
            img.size = NSSize(width: 16, height: 16)
            return img
        }
        return nil
    }()
    
    static let antigravityImage: NSImage? = {
        if let url = Bundle.module.url(forResource: "antigravity", withExtension: "svg"),
           let img = NSImage(contentsOf: url) {
            img.size = NSSize(width: 16, height: 16)
            return img
        }
        return nil
    }()
    
    static let codexImage: NSImage? = {
        if let url = Bundle.module.url(forResource: "codex", withExtension: "svg"),
           let img = NSImage(contentsOf: url) {
            img.size = NSSize(width: 16, height: 16)
            return img
        }
        return nil
    }()
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
        } else {
            Image(systemName: "bolt.circle.fill")
                .resizable()
                .foregroundColor(Color(red: 16/255, green: 163/255, blue: 127/255))
                .frame(width: size, height: size)
        }
    }
}
