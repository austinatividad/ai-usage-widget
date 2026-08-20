import SwiftUI
import AppKit

public struct NotchIslandView: View {
    @ObservedObject var tracker: UsageTracker
    @State private var isExpanded: Bool = false
    @State private var collapseTask: Task<Void, Never>?
    
    private let collapsedWidth: CGFloat
    private let collapsedHeight: CGFloat
    private let expandedWidth: CGFloat = 350
    
    private var expandedHeight: CGFloat {
        return tracker.widgetHeight + 36
    }
    
    public var onExpandChange: ((Bool) -> Void)?
    
    public init(
        tracker: UsageTracker,
        collapsedWidth: CGFloat = 185,
        collapsedHeight: CGFloat = 32,
        onExpandChange: ((Bool) -> Void)? = nil
    ) {
        self.tracker = tracker
        self.collapsedWidth = collapsedWidth
        self.collapsedHeight = collapsedHeight
        self.onExpandChange = onExpandChange
    }
    
    public var body: some View {
        ZStack(alignment: .top) {
            // Morphing Island Container
            ZStack(alignment: .top) {
                // Pure Black Background
                UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: isExpanded ? 24 : 14,
                    bottomTrailingRadius: isExpanded ? 24 : 14,
                    topTrailingRadius: 0,
                    style: .continuous
                )
                .fill(Color.black)
                
                // Content View
                if isExpanded {
                    VStack(spacing: 0) {
                        WidgetContent(tracker: tracker)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 40)
                    .padding(.bottom, 16)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.94, anchor: .top)),
                        removal: .opacity.combined(with: .scale(scale: 0.92, anchor: .top))
                    ))
                }
            }
            .frame(
                width: isExpanded ? expandedWidth : collapsedWidth,
                height: isExpanded ? expandedHeight : collapsedHeight,
                alignment: .top
            )
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: isExpanded ? 24 : 14,
                    bottomTrailingRadius: isExpanded ? 24 : 14,
                    topTrailingRadius: 0,
                    style: .continuous
                )
            )
            .contentShape(Rectangle())
            .onHover { hovering in
                handleHover(hovering)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.spring(response: 0.28, dampingFraction: 0.78, blendDuration: 0), value: isExpanded)
        .animation(.easeInOut(duration: 0.2), value: tracker.activeProviders.count)
    }
    
    private func handleHover(_ hovering: Bool) {
        if hovering {
            collapseTask?.cancel()
            onExpandChange?(true)
            withAnimation(.spring(response: 0.28, dampingFraction: 0.78, blendDuration: 0)) {
                isExpanded = true
            }
        } else {
            collapseTask?.cancel()
            collapseTask = Task {
                try? await Task.sleep(nanoseconds: 180_000_000)
                if !Task.isCancelled {
                    onExpandChange?(false)
                    withAnimation(.spring(response: 0.24, dampingFraction: 0.88, blendDuration: 0)) {
                        isExpanded = false
                    }
                }
            }
        }
    }
}
