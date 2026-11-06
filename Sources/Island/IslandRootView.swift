import SwiftUI

/// The window is exactly the size of the island, so the transparent parts of
/// the SwiftUI hierarchy never steal clicks from the desktop or the menu bar.
struct IslandRootView: View {
    @EnvironmentObject private var state: IslandState

    var body: some View {
        let geometry = state.geometry
        let expanded = state.expanded
        let size = expanded ? geometry.expandedSize : geometry.collapsedSize
        let shape = UnevenRoundedRectangle(
            topLeadingRadius: geometry.topRadius,
            bottomLeadingRadius: geometry.bottomRadius,
            bottomTrailingRadius: geometry.bottomRadius,
            topTrailingRadius: geometry.topRadius,
            style: .continuous
        )

        ZStack(alignment: .top) {
            if !expanded {
                CompactView()
                    .frame(width: geometry.collapsedSize.width, height: geometry.collapsedSize.height)
                    .transition(.opacity)
            }

            if expanded {
                ExpandedView()
                    .frame(width: geometry.expandedSize.width, height: geometry.expandedSize.height)
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(
                                with: .scale(scale: 0.96, anchor: .top)
                            ),
                            removal: .opacity
                        )
                    )
            }
        }
        .frame(width: size.width, height: size.height, alignment: .top)
        .background(shape.fill(Color.black))
        .clipShape(shape)
        .contentShape(shape)
        .onHover { inside in
            state.onHover?(inside)
        }
        .onTapGesture {
            if !state.expanded { state.onExpandNow?() }
        }
        .animation(Theme.motion, value: expanded)
        .environment(\.colorScheme, .dark)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
