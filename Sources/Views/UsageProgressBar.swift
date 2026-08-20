import SwiftUI

public struct UsageProgressBar: View {
    public let progress: Double
    public var fillColor: Color = .white
    public var height: CGFloat = 7
    
    public init(progress: Double, fillColor: Color = .white, height: CGFloat = 7) {
        self.progress = min(1.0, max(0.0, progress))
        self.fillColor = fillColor
        self.height = height
    }
    
    public var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Liquid Glass Background Track
                Capsule()
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                    )
                    .frame(height: height)
                
                // Liquid Glass Active Fill with Specular Highlight
                if progress > 0 {
                    let fillWidth = max(height, geo.size.width * CGFloat(progress))
                    ZStack(alignment: .topLeading) {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [fillColor.opacity(0.96), fillColor.opacity(0.82)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        
                        // Top Specular Sheen
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.38), Color.white.opacity(0.0)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(height: height * 0.45)
                            .padding(.horizontal, 1)
                    }
                    .frame(width: fillWidth, height: height)
                    .clipShape(Capsule())
                    .animation(.spring(response: 0.35, dampingFraction: 0.75), value: progress)
                }
            }
        }
        .frame(height: height)
    }
}
