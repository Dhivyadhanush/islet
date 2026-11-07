import SwiftUI
import AppKit

struct MusicPane: View {
    @EnvironmentObject private var nowPlaying: NowPlaying
    @Environment(\.openURL) private var openURL

    @State private var scrubFraction: Double?

    var body: some View {
        if let track = nowPlaying.track {
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    artwork(track.artwork)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.title.isEmpty ? "Unknown track" : track.title)
                            .font(.system(size: 13.5, weight: .semibold))
                            .foregroundStyle(Theme.text)
                            .lineLimit(1)
                        Text(track.artist.isEmpty ? "Unknown artist" : track.artist)
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.secondary)
                            .lineLimit(1)
                        if !track.album.isEmpty {
                            Text(track.album)
                                .font(.system(size: 9.5))
                                .foregroundStyle(Theme.tertiary)
                                .lineLimit(1)
                        }
                        if !track.source.isEmpty {
                            HStack(spacing: 4) {
                                if let icon = track.sourceIcon {
                                    Image(nsImage: icon)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 9, height: 9)
                                }
                                Text(track.source)
                                    .lineLimit(1)
                            }
                            .font(.system(size: 8.5, weight: .medium))
                            .foregroundStyle(Theme.tertiary)
                            .padding(.top, 1)
                        }
                    }
                    Spacer(minLength: 0)

                    PlayingWaveform(active: track.isPlaying, color: accent)
                        .frame(width: 64, height: 26)
                        .padding(.trailing, 4)
                        .help(track.isPlaying ? "Playing" : "Paused")
                }

                progress(track)
                controls(track)
            }
            .padding(.top, 2)
            .background(alignment: .topLeading) {
                Circle()
                    .fill(accent.opacity(0.16))
                    .frame(width: 150, height: 150)
                    .blur(radius: 40)
                    .offset(x: -30, y: -40)
                    .allowsHitTesting(false)
            }
        } else {
            emptyState
        }
    }

    /// Colour pulled from the current artwork; white when there is none.
    private var accent: Color {
        ArtworkPalette.accent(for: nowPlaying.track?.artwork) ?? .white
    }

    private func artwork(_ image: NSImage?) -> some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    LinearGradient(
                        colors: [Color.white.opacity(0.17), Color.white.opacity(0.04)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Image(systemName: "music.note")
                        .font(.system(size: 18, weight: .light))
                        .foregroundStyle(.white.opacity(0.45))
                }
            }
        }
        .frame(width: 58, height: 58)
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .strokeBorder(accent.opacity(0.45), lineWidth: 1)
        }
        .shadow(color: accent.opacity(0.35), radius: 9, y: 2)
    }

    private func progress(_ track: NowPlaying.Track) -> some View {
        let shown = scrubFraction.map { $0 * max(track.duration, 0) } ?? nowPlaying.position
        let fraction = track.duration > 0
            ? min(max(shown / track.duration, 0), 1)
            : 0

        return VStack(spacing: 3) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.14))
                        .frame(height: 3)
                    Capsule()
                        .fill(accent)
                        .frame(width: max(3, geo.size.width * fraction), height: 3)
                    if scrubFraction != nil {
                        Circle()
                            .fill(accent)
                            .frame(width: 7, height: 7)
                            .offset(x: max(0, min(geo.size.width - 7, geo.size.width * fraction - 3.5)))
                    }
                }
                .frame(maxHeight: .infinity, alignment: .center)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            guard track.duration > 0 else { return }
                            scrubFraction = min(max(value.location.x / geo.size.width, 0), 1)
                        }
                        .onEnded { value in
                            guard track.duration > 0 else { return }
                            let target = min(max(value.location.x / geo.size.width, 0), 1)
                            nowPlaying.seek(to: target * track.duration)
                            scrubFraction = nil
                        }
                )
            }
            .frame(height: 16)

            HStack {
                Text(clock(shown))
                Spacer()
                Text(track.duration > 0 ? "-\(clock(max(track.duration - shown, 0)))" : "--:--")
            }
            .font(Theme.mono)
            .foregroundStyle(Theme.tertiary)
        }
    }

    private func controls(_ track: NowPlaying.Track) -> some View {
        HStack(spacing: 26) {
            Button { nowPlaying.previous() } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 26, height: 30)
                    .contentShape(Rectangle())
            }
            Button { nowPlaying.toggle() } label: {
                Image(systemName: track.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(accent))
                    .contentShape(Circle())
            }
            Button { nowPlaying.next() } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 26, height: 30)
                    .contentShape(Rectangle())
            }
        }
        .buttonStyle(PressableButtonStyle(scale: 0.88))
        .foregroundStyle(Theme.text)
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "music.note")
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(Theme.tertiary)
            Text("Nothing playing")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.text)
            Text("Play something in Music, Spotify, or any browser.")
                .font(.system(size: 9.5))
                .foregroundStyle(Theme.tertiary)
                .multilineTextAlignment(.center)
            Button {
                if let url = URL(string: "music://") {
                    openURL(url)
                }
            } label: {
                Text("Open Music")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(Theme.secondary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Theme.fill))
            }
            .buttonStyle(PressableButtonStyle())
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func clock(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
