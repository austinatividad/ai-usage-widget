import SwiftUI
import AppKit

public struct NotchIslandView: View {
    @ObservedObject var tracker: UsageTracker
    @State private var isExpanded: Bool = false
    @State private var collapseTask: Task<Void, Never>?
    
    // Exact physical notch dimensions (MacBook Air / Pro hardware notch)
    private let notchWidth: CGFloat = 180
    private let notchHeight: CGFloat = 32
    
    private var expandedHeight: CGFloat {
        return tracker.widgetHeight + 30
    }
    
    public init(tracker: UsageTracker) {
        self.tracker = tracker
    }
    
    public var body: some View {
        ZStack(alignment: .top) {
            // Expanded Panel
            VStack(spacing: 0) {
                WidgetContent(tracker: tracker, showRefresh: true)
            }
            .padding(.horizontal, 22)
            .padding(.top, 48)
            .padding(.bottom, 16)
            .frame(width: 350, height: expandedHeight)
            .background(
                ZStack {
                    UnevenRoundedRectangle(
                        topLeadingRadius: 0,
                        bottomLeadingRadius: 24,
                        bottomTrailingRadius: 24,
                        topTrailingRadius: 0,
                        style: .continuous
                    )
                    .fill(.ultraThinMaterial)
                    
                    UnevenRoundedRectangle(
                        topLeadingRadius: 0,
                        bottomLeadingRadius: 24,
                        bottomTrailingRadius: 24,
                        topTrailingRadius: 0,
                        style: .continuous
                    )
                    .fill(Color.black.opacity(0.95))
                    
                    UnevenRoundedRectangle(
                        topLeadingRadius: 0,
                        bottomLeadingRadius: 24,
                        bottomTrailingRadius: 24,
                        topTrailingRadius: 0,
                        style: .continuous
                    )
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
                }
            )
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: 24,
                    bottomTrailingRadius: 24,
                    topTrailingRadius: 0,
                    style: .continuous
                )
            )
            .offset(y: isExpanded ? 0 : -(expandedHeight + 10))
            .opacity(isExpanded ? 1.0 : 0.0)
            .allowsHitTesting(isExpanded)
            .onHover { hovering in
                handleHover(hovering)
            }
            
            // Collapsed Notch Target Area (Strictly limited to the 180x32pt physical hardware notch)
            if !isExpanded {
                Color.clear
                    .frame(width: notchWidth, height: notchHeight)
                    .contentShape(Rectangle())
                    .onHover { hovering in
                        handleHover(hovering)
                    }
            }
        }
        .frame(width: 350, height: isExpanded ? expandedHeight : notchHeight, alignment: .top)
    }
    
    private func handleHover(_ hovering: Bool) {
        if hovering {
            collapseTask?.cancel()
            withAnimation(.spring(response: 0.18, dampingFraction: 0.88)) {
                isExpanded = true
            }
        } else {
            collapseTask?.cancel()
            collapseTask = Task {
                try? await Task.sleep(nanoseconds: 120_000_000)
                if !Task.isCancelled {
                    withAnimation(.spring(response: 0.16, dampingFraction: 0.92)) {
                        isExpanded = false
                    }
                }
            }
        }
    }
}
