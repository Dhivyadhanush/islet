import SwiftUI

/// The visual island. When collapsed on a notched Mac it is exactly the notch
/// silhouette, so there is no pill extending into the menu bar. Hovering the
/// notch opens the card; the controller owns that hit area.
struct IslandRootView: View {
    @EnvironmentObject private var state: IslandState

    var body: some View {
        let geometry = state.geometry
        let expanded = state.expanded
        let size = expanded ? geometry.expandedSize : geometry.collapsedSize
        let topRadius: CGFloat = geometry.hasNotch ? 0 : (expanded ? 18 : 15)
        let bottomRadius: CGFloat = expanded ? 26 : (geometry.hasNotch ? 12 : 15)
        let shape = IslandShape(topRadius: topRadius, bottomRadius: bottomRadius)

        ZStack(alignment: .top) {
            if !expanded && !geometry.hasNotch {
                Circle()
                    .fill(Color.white.opacity(0.32))
                    .frame(width: 4, height: 4)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        .animation(Theme.motion, value: expanded)
        .environment(\.colorScheme, .dark)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .contentShape(Rectangle())
        .onHover { inside in
            state.onHover?(inside)
        }
        .onTapGesture {
            if !state.expanded { state.onExpandNow?() }
        }
    }
}
