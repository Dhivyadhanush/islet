import AppKit
import SwiftUI

/// A small now-playing chip that sits in the menu bar immediately left of the
/// notch.
///
/// `NSStatusBar` only accepts items to the right of the notch, so the chip is a
/// borderless island-owned panel at the status-bar level instead. It shows the
/// mini cover and a live waveform while a track is playing, and disappears when
/// playback stops or the island expands.
@MainActor
final class NowPlayingChipController {
    private let state: IslandState
    private let nowPlaying: NowPlaying
    private let panel: IslandPanel
    private var screenObserver: NSObjectProtocol?

    private static let size = CGSize(width: 70, height: 24)

    init(state: IslandState, nowPlaying: NowPlaying) {
        self.state = state
        self.nowPlaying = nowPlaying

        let root = AnyView(
            NowPlayingChipView()
                .environmentObject(state)
                .environmentObject(nowPlaying)
        )
        let hosting = IslandHostingView(rootView: root)
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = NSColor.clear.cgColor

        panel = IslandPanel()
        panel.contentView = hosting
        panel.setContentSize(Self.size)
        panel.animationBehavior = .none
        panel.hasShadow = false
        reposition()
        panel.orderOut(nil)

        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.reposition() }
        }
    }

    deinit {
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
    }

    func update(track: NowPlaying.Track?, islandVisible: Bool) {
        let playing = track?.isPlaying == true
        guard playing, !state.expanded, islandVisible else {
            if panel.isVisible { panel.orderOut(nil) }
            return
        }

        reposition()
        if !panel.isVisible {
            panel.orderFrontRegardless()
        }
    }

    private func reposition() {
        let screen = Self.preferredScreen()
        let geometry = IslandGeometry.read(from: screen)
        let islandWidth = geometry.hasNotch
            ? geometry.notchWidth
            : geometry.collapsedSize.width
        let barHeight = geometry.hasNotch
            ? geometry.notchHeight
            : max(24, screen.frame.maxY - screen.visibleFrame.maxY)

        let frame = NSRect(
            x: screen.frame.midX - islandWidth / 2 - Self.size.width - 6,
            y: screen.frame.maxY - (barHeight + Self.size.height) / 2,
            width: Self.size.width,
            height: Self.size.height
        )
        panel.setFrame(frame, display: true)
    }

    private static func preferredScreen() -> NSScreen {
        if let notched = NSScreen.screens.first(where: {
            $0.safeAreaInsets.top > 0 && $0.auxiliaryTopLeftArea != nil
        }) {
            return notched
        }
        return NSScreen.main ?? NSScreen.screens[0]
    }
}

private struct NowPlayingChipView: View {
    @EnvironmentObject private var state: IslandState
    @EnvironmentObject private var nowPlaying: NowPlaying

    var body: some View {
        if let track = nowPlaying.track {
            HStack(spacing: 5) {
                artwork(track.artwork)
                PlayingWaveform(active: track.isPlaying, color: .white)
                    .frame(width: 26, height: 18)
            }
            .padding(.horizontal, 7)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.black)
            )
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.5)
            }
            .contentShape(Capsule(style: .continuous))
            .onTapGesture {
                state.tab = .music
                state.onExpandNow?()
            }
            .help(track.artist.isEmpty ? track.title : "\(track.title) — \(track.artist)")
        } else {
            Color.clear
        }
    }

    @ViewBuilder
    private func artwork(_ image: NSImage?) -> some View {
        if let image {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 16, height: 16)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        } else {
            Image(systemName: "music.note")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Theme.secondary)
                .frame(width: 16, height: 16)
        }
    }
}
