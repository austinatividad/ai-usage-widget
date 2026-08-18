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
                // Background Track
                Capsule()
                    .fill(Color(white: 0.14))
                    .frame(height: height)
                
                // Active Fill
                if progress > 0 {
                    Capsule()
                        .fill(fillColor)
                        .frame(width: max(height, geo.size.width * CGFloat(progress)), height: height)
                        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: progress)
                }
            }
        }
        .frame(height: height)
    }
}
