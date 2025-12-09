import SwiftUI

// MARK: - 1. Magazine Cover (Vogue Style)
struct MagazineCoverArtifactView: View {
    let data: ViralShareData

    // Dynamic editorial headline templates - includes track AND artist
    private func generateHeadline(for friend: ViralShareData.FriendTrack, index: Int) -> String {
        let templates = [
            "@\(friend.username): \"\(friend.trackName)\" by \(friend.artistName)",
            "@\(friend.username) picks \"\(friend.trackName)\" - \(friend.artistName)",
            "@\(friend.username)'s choice: \(friend.artistName) – \"\(friend.trackName)\""
        ]
        return templates[index % templates.count]
    }

    private var fullDate: String {
        data.date.formatted(.dateTime.weekday(.wide).month(.wide).day().year()).uppercased()
    }

    private var issueNumber: String {
        let calendar = Calendar.current
        let weekOfYear = calendar.component(.weekOfYear, from: data.date)
        return String(format: "NO. %03d", weekOfYear)
    }

    var body: some View {
        ZStack {
            // Full bleed background
            if let url = URL(string: data.userTrack.albumArtUrl ?? "") {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.black
                }
            } else {
                Color.black
            }

            // Gradient overlay for text legibility
            LinearGradient(
                colors: [
                    Color.black.opacity(0.2),
                    Color.black.opacity(0.3),
                    Color.black.opacity(0.85)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 0) {
                // Top bar with full date
                HStack {
                    Text(issueNumber)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))

                    Spacer()

                    Text(fullDate)
                        .font(.system(size: 22, weight: .medium))
                        .tracking(2)
                        .foregroundColor(.white.opacity(0.8))

                    Spacer()

                    Text("FREE")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.horizontal, 500)
                .padding(.top, 60)

                // Masthead - PHLOCK
                Text("PHLOCK")
                    .font(.custom("Didot", size: 180))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .tracking(8)
                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                    .padding(.top, 12)

                Spacer()

                // Featured headline (user's pick) - with track and artist
                VStack(alignment: .leading, spacing: 12) {
                    Text("THE COVER")
                        .font(.system(size: 24, weight: .bold))
                        .tracking(4)
                        .foregroundColor(.white.opacity(0.7))

                    Text("@\(data.userName)")
                        .font(.custom("Didot", size: 60))
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Text("\"\(data.userTrack.name)\"")
                        .font(.system(size: 42, weight: .bold, design: .serif))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Text("by \(data.userTrack.artistName ?? "Unknown")")
                        .font(.system(size: 32, weight: .medium, design: .serif))
                        .foregroundColor(.white.opacity(0.85))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 500)
                .padding(.bottom, 30)

                // Divider
                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .frame(height: 1)
                    .padding(.horizontal, 500)

                // Friends' headlines (each shows username, track, AND artist)
                VStack(alignment: .leading, spacing: 20) {
                    Text("ALSO IN THIS ISSUE")
                        .font(.system(size: 22, weight: .bold))
                        .tracking(4)
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.top, 20)

                    ForEach(Array(data.friendsTracks.prefix(4).enumerated()), id: \.element.id) { index, friend in
                        Text(generateHeadline(for: friend, index: index))
                            .font(.system(size: 30, weight: .medium, design: .serif))
                            .foregroundColor(.white.opacity(0.9))
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 500)
                .padding(.bottom, 30)

                // Footer
                HStack(alignment: .bottom) {
                    // Barcode
                    VStack(spacing: 4) {
                        HStack(spacing: 2) {
                            ForEach(0..<18, id: \.self) { _ in
                                Rectangle()
                                    .fill(Color.white)
                                    .frame(width: CGFloat.random(in: 2...5), height: 48)
                            }
                        }
                        Text("@myphlock")
                            .font(.system(size: 18, design: .monospaced))
                            .foregroundColor(.white.opacity(0.5))
                    }

                    Spacer()

                    Text("@myphlock")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 500)
                .padding(.bottom, 60)
            }
        }
        .frame(width: 1080, height: 1920)
        .clipped()
    }
}

// MARK: - 2. Festival Poster (Lineup Style)
struct FestivalPosterArtifactView: View {
    let data: ViralShareData

    var body: some View {
        ZStack {
            // Full-bleed album art background
            if let url = URL(string: data.userTrack.albumArtUrl ?? "") {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color(hex: "1a1a1a")
                }
                .frame(width: 1080, height: 1920)
                .clipped()
            } else {
                Color(hex: "1a1a1a")
            }

            // Strong gradient overlay for text legibility on any album art
            LinearGradient(
                colors: [
                    Color.black.opacity(0.8),
                    Color.black.opacity(0.5),
                    Color.black.opacity(0.6),
                    Color.black.opacity(0.9)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 0) {
                // Festival header
                VStack(spacing: 12) {
                    // Decorative stars
                    HStack(spacing: 24) {
                        ForEach(0..<5, id: \.self) { _ in
                            Text("★")
                                .font(.system(size: 36))
                                .foregroundColor(.yellow)
                        }
                    }

                    Text("PHLOCK FEST")
                        .font(.system(size: 108, weight: .black))
                        .foregroundColor(.yellow)
                        .tracking(6)

                    Text(data.date.formatted(.dateTime.weekday(.wide).month(.wide).day().year()).uppercased())
                        .font(.system(size: 36, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .tracking(4)
                }
                .padding(.top, 100)

                // Decorative line
                Rectangle()
                    .fill(Color.yellow)
                    .frame(height: 4)
                    .padding(.horizontal, 120)
                    .padding(.vertical, 30)

                // Headliner section
                VStack(spacing: 16) {
                    Text("HEADLINED BY")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(.yellow)
                        .tracking(8)

                    Text((data.userTrack.artistName ?? "Unknown Artist").uppercased())
                        .font(.system(size: 144, weight: .black))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.3)
                        .padding(.horizontal, 48)

                    Text("\"\(data.userTrack.name)\"")
                        .font(.system(size: 54, weight: .medium))
                        .foregroundColor(.yellow)
                        .lineLimit(1)

                    Text("CURATED BY")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(.yellow)
                        .tracking(8)
                        .padding(.top, 8)

                    Text("@\(data.userName)")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.yellow)
                }
                .padding(.bottom, 40)

                // Decorative separator
                HStack(spacing: 24) {
                    Rectangle()
                        .fill(Color.white.opacity(0.3))
                        .frame(height: 2)
                    Text("★")
                        .font(.system(size: 36))
                        .foregroundColor(.white.opacity(0.5))
                    Rectangle()
                        .fill(Color.white.opacity(0.3))
                        .frame(height: 2)
                }
                .padding(.horizontal, 72)
                .padding(.vertical, 24)

                // Special Guests section with larger album thumbnails and text
                VStack(spacing: 20) {
                    Text("SPECIAL GUESTS")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.white)
                        .tracking(8)

                    ForEach(data.friendsTracks.prefix(4)) { friend in
                        HStack(spacing: 24) {
                            // Larger album art thumbnail
                            if let url = URL(string: friend.albumArtUrl ?? "") {
                                AsyncImage(url: url) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.white.opacity(0.1))
                                }
                                .frame(width: 90, height: 90)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            } else {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.white.opacity(0.1))
                                    .frame(width: 90, height: 90)
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 12) {
                                    Text(friend.artistName.uppercased())
                                        .font(.system(size: 38, weight: .black))
                                        .foregroundColor(.white)
                                        .lineLimit(1)

                                    Text("•")
                                        .foregroundColor(.white.opacity(0.4))

                                    Text("@\(friend.username)")
                                        .font(.system(size: 32, weight: .bold))
                                        .foregroundColor(.yellow)
                                }

                                Text("\"\(friend.trackName)\"")
                                    .font(.system(size: 28, weight: .medium))
                                    .foregroundColor(.white.opacity(0.8))
                                    .lineLimit(1)
                            }

                            Spacer()
                        }
                        .padding(.horizontal, 60)
                    }
                }

                Spacer()

                // Footer
                VStack(spacing: 18) {
                    Rectangle()
                        .fill(Color.yellow)
                        .frame(height: 4)
                        .padding(.horizontal, 120)

                    HStack {
                        Image(systemName: "globe")
                            .font(.system(size: 36))
                            .foregroundColor(.white)
                        Text("@myphlock")
                            .font(.system(size: 30, weight: .medium))
                            .foregroundColor(.white)

                        Spacer()

                        Text("DAILY MUSIC CURATION")
                            .font(.system(size: 24, weight: .bold))
                            .tracking(4)
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .padding(.horizontal, 72)
                }
                .padding(.bottom, 72)
            }
        }
        .frame(width: 1080, height: 1920)
    }
}

// MARK: - 3. Daily Mixtape (Cassette Style)
struct DailyMixtapeArtifactView: View {
    let data: ViralShareData

    // Format date as "DEC 08 MIX" style
    private var mixTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd"
        return formatter.string(from: data.date).uppercased() + " MIX"
    }

    // Possessive form: "'" for names ending in s, "'s" otherwise
    private var possessiveUserName: String {
        data.userName.lowercased().hasSuffix("s") ? "@\(data.userName)'" : "@\(data.userName)'s"
    }

    // Collect only non-nil album art URLs for the tape window (dynamic)
    private var albumArtUrls: [String] {
        var urls: [String] = []
        if let userUrl = data.userTrack.albumArtUrl {
            urls.append(userUrl)
        }
        for friend in data.friendsTracks.prefix(4) {
            if let friendUrl = friend.albumArtUrl {
                urls.append(friendUrl)
            }
        }
        return urls
    }

    var body: some View {
        ZStack {
            // Warm cream background
            Color(hex: "f5f0e8")

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 12) {
                    Text("DAILY MIXTAPE")
                        .font(.system(size: 60, weight: .bold, design: .monospaced))
                        .tracking(6)
                        .foregroundColor(.black)

                    Text("MIXED BY @\(data.userName.uppercased())")
                        .font(.system(size: 36, weight: .medium))
                        .foregroundColor(.gray)
                }
                .padding(.top, 120)

                Spacer()

                // 90s Clear Shell Cassette with album art in window
                ClearShellCassette(mixTitle: mixTitle, userName: data.userName, albumArtUrls: albumArtUrls)
                    .frame(height: 540)
                    .padding(.horizontal, 60)

                Spacer()

                // J-Card Tracklist
                JCardTracklist(data: data)
                    .padding(.horizontal, 60)
                    .padding(.bottom, 90)
            }
        }
        .frame(width: 1080, height: 1920)
    }
}

// 90s Clear Shell Cassette Graphic
struct ClearShellCassette: View {
    let mixTitle: String
    let userName: String
    var albumArtUrls: [String] = []

    // Possessive form for cassette label
    private var possessiveUserName: String {
        userName.lowercased().hasSuffix("s") ? "@\(userName)'" : "@\(userName)'s"
    }

    var body: some View {
        ZStack {
            // Outer cassette shell (translucent)
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.9),
                            Color.gray.opacity(0.2),
                            Color.white.opacity(0.7)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.gray.opacity(0.4), lineWidth: 3)
                )

            // Inner tape window area
            VStack(spacing: 0) {
                // Top section with label
                ZStack {
                    // Label background (cream colored)
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(hex: "fffef5"))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )

                    VStack(spacing: 8) {
                        // Brand area
                        HStack {
                            Text("PHLOCK")
                                .font(.system(size: 24, weight: .black))
                                .foregroundColor(Color(hex: "cc3333"))
                            Spacer()
                            Text("C-60")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.gray)
                        }

                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 1)

                        // Handwritten-style title
                        Text(mixTitle)
                            .font(.custom("Marker Felt", size: 48))
                            .foregroundColor(Color(hex: "2255aa"))

                        Text("\(possessiveUserName) mix")
                            .font(.custom("Marker Felt", size: 32))
                            .foregroundColor(Color(hex: "444444"))

                        Spacer()
                    }
                    .padding(24)
                }
                .frame(height: 200)
                .padding(.horizontal, 36)
                .padding(.top, 36)

                // Tape window (showing album art grid instead of reels) - dynamic sizing
                ZStack {
                    // Tape window background (dark)
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(hex: "1a1a1a"))

                    // Album art grid in tape window - only shows albums that exist
                    HStack(spacing: 8) {
                        ForEach(Array(albumArtUrls.enumerated()), id: \.offset) { _, urlString in
                            if let url = URL(string: urlString) {
                                AsyncImage(url: url) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.3))
                                }
                                .frame(width: albumArtUrls.count == 1 ? 140 : (albumArtUrls.count <= 3 ? 120 : 100),
                                       height: albumArtUrls.count == 1 ? 140 : (albumArtUrls.count <= 3 ? 120 : 100))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                // Desaturation + tint to simulate viewing through plastic
                                .saturation(0.7)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color(hex: "1a1a1a").opacity(0.25))
                                )
                            }
                        }
                    }

                    // Tape guides on sides
                    HStack {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.6))
                            .frame(width: 12, height: 60)
                        Spacer()
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.6))
                            .frame(width: 12, height: 60)
                    }
                    .padding(.horizontal, 24)

                    // Subtle plastic sheen overlay
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.1),
                                    Color.clear,
                                    Color.white.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .frame(height: 180)
                .padding(.horizontal, 60)
                .padding(.top, 24)

                Spacer()
            }

            // Screw holes in corners
            VStack {
                HStack {
                    ScrewHole()
                    Spacer()
                    ScrewHole()
                }
                Spacer()
                HStack {
                    ScrewHole()
                    Spacer()
                    ScrewHole()
                }
            }
            .padding(30)

            // Ridge details on sides
            HStack {
                VStack(spacing: 24) {
                    ForEach(0..<8, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 6, height: 30)
                    }
                }
                Spacer()
                VStack(spacing: 24) {
                    ForEach(0..<8, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 6, height: 30)
                    }
                }
            }
            .padding(.horizontal, 6)
        }
    }
}

// Tape Reel with spokes
struct TapeReel: View {
    let tapeAmount: CGFloat // 0.0 to 1.0

    var body: some View {
        ZStack {
            // Outer tape (brown)
            Circle()
                .fill(Color(hex: "3d2518"))
                .frame(width: 120 * tapeAmount + 48, height: 120 * tapeAmount + 48)

            // Inner hub (white/clear)
            Circle()
                .fill(Color.white.opacity(0.9))
                .frame(width: 48, height: 48)

            // Hub spokes
            ForEach(0..<6, id: \.self) { i in
                Rectangle()
                    .fill(Color.gray.opacity(0.5))
                    .frame(width: 3, height: 36)
                    .offset(y: -10)
                    .rotationEffect(.degrees(Double(i) * 60))
            }

            // Center hole
            Circle()
                .fill(Color(hex: "1a1a1a"))
                .frame(width: 12, height: 12)
        }
    }
}

// Screw hole detail
struct ScrewHole: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 24, height: 24)
            Circle()
                .fill(Color.gray.opacity(0.5))
                .frame(width: 12, height: 12)
        }
    }
}

// J-Card style tracklist
struct JCardTracklist: View {
    let data: ViralShareData

    var body: some View {
        VStack(spacing: 0) {
            // J-Card header
            HStack {
                Text("SIDE A")
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundColor(.black)
                Spacer()
                Text("TRACKLIST")
                    .font(.system(size: 24, weight: .medium, design: .monospaced))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 36)
            .padding(.vertical, 24)
            .background(Color(hex: "e8e4dc"))

            // Tracks
            VStack(alignment: .leading, spacing: 0) {
                // User's track (highlighted)
                TrackRow(
                    number: 1,
                    track: data.userTrack.name,
                    artist: data.userTrack.artistName ?? "Unknown",
                    username: "@\(data.userName)",
                    isHighlighted: true
                )

                ForEach(Array(data.friendsTracks.prefix(4).enumerated()), id: \.element.id) { index, friend in
                    TrackRow(
                        number: index + 2,
                        track: friend.trackName,
                        artist: friend.artistName,
                        username: "@\(friend.username)",
                        isHighlighted: false
                    )
                }
            }
            .padding(.vertical, 18)
            .background(Color.white)

            // J-Card footer
            HStack {
                Text("@myphlock")
                    .font(.system(size: 24, weight: .medium, design: .monospaced))
                    .foregroundColor(.gray)
                Spacer()
                Text(data.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 24, weight: .medium, design: .monospaced))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 36)
            .padding(.vertical, 18)
            .background(Color(hex: "e8e4dc"))
        }
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 12, x: 0, y: 6)
    }
}

// Individual track row
struct TrackRow: View {
    let number: Int
    let track: String
    let artist: String
    let username: String
    let isHighlighted: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            Text(String(format: "%02d", number))
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .foregroundColor(isHighlighted ? Color(hex: "cc3333") : .gray)
                .frame(width: 54)

            VStack(alignment: .leading, spacing: 4) {
                Text(track)
                    .font(.system(size: 32, weight: isHighlighted ? .bold : .medium, design: .monospaced))
                    .foregroundColor(.black)
                    .lineLimit(1)

                HStack(spacing: 12) {
                    Text(artist)
                        .font(.system(size: 26, design: .monospaced))
                        .foregroundColor(.gray)
                        .lineLimit(1)

                    Text("•")
                        .foregroundColor(.gray.opacity(0.5))

                    Text(username)
                        .font(.system(size: 26, weight: .medium, design: .monospaced))
                        .foregroundColor(isHighlighted ? Color(hex: "cc3333") : Color(hex: "666666"))
                }
            }

            Spacer()
        }
        .padding(.horizontal, 36)
        .padding(.vertical, 18)
        .background(isHighlighted ? Color(hex: "fff8f0") : Color.clear)
    }
}

// MARK: - 4. Notification Stack (Lock Screen)
struct NotificationStackArtifactView: View {
    let data: ViralShareData

    private var formattedDate: String {
        data.date.formatted(.dateTime.weekday(.wide).month(.wide).day())
    }

    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: Date())
    }

    var body: some View {
        ZStack {
            // Blurred album art background
            if let url = URL(string: data.userTrack.albumArtUrl ?? "") {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                        .blur(radius: 60)
                        .scaleEffect(1.4)
                } placeholder: {
                    LinearGradient(
                        colors: [Color(hex: "2c2c2e"), Color(hex: "1c1c1e")],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            } else {
                LinearGradient(
                    colors: [Color(hex: "2c2c2e"), Color(hex: "1c1c1e")],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }

            // Slight dark overlay for text legibility
            Color.black.opacity(0.25)

            VStack(spacing: 0) {
                // iOS Lock Screen Header - Date above time
                VStack(spacing: 12) {
                    Text(formattedDate)
                        .font(.system(size: 56, weight: .regular))
                        .foregroundColor(.white)

                    Text(formattedTime)
                        .font(.system(size: 280, weight: .light))
                        .foregroundColor(.white)
                        .tracking(-8)
                }
                .padding(.top, 80)

                Spacer()

                // Notification stack - iOS style translucent cards
                VStack(spacing: 24) {
                    // User's notification
                    IOSNotificationCard(
                        appName: "phlock",
                        title: "@\(data.userName) set today's mood",
                        subtitle: "\"\(data.userTrack.name)\" by \(data.userTrack.artistName ?? "Unknown")",
                        timestamp: "now",
                        albumArtUrl: data.userTrack.albumArtUrl
                    )

                    // Friends' notifications (limit to 2 to ensure fit)
                    ForEach(Array(data.friendsTracks.prefix(2).enumerated()), id: \.element.id) { index, friend in
                        IOSNotificationCard(
                            appName: "phlock",
                            title: "@\(friend.username) shared a track",
                            subtitle: "\"\(friend.trackName)\" by \(friend.artistName)",
                            timestamp: "\(index + 1)m ago",
                            albumArtUrl: friend.albumArtUrl
                        )
                    }
                }
                .padding(.horizontal, 450)
                .padding(.bottom, 160)

                // Branding
                Text("@myphlock")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.bottom, 20)

                // Home indicator
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.white.opacity(0.6))
                    .frame(width: 200, height: 8)
                    .padding(.bottom, 30)
            }
        }
        .frame(width: 1080, height: 1920)
        .clipped()
    }
}

// iOS-style notification card (translucent background like profile carousel)
struct IOSNotificationCard: View {
    let appName: String
    let title: String
    let subtitle: String
    let timestamp: String
    let albumArtUrl: String?

    var body: some View {
        HStack(alignment: .center, spacing: 24) {
            // Album art thumbnail
            if let urlString = albumArtUrl, let url = URL(string: urlString) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 28)
                        .fill(Color.gray.opacity(0.3))
                }
                .frame(width: 140, height: 140)
                .clipShape(RoundedRectangle(cornerRadius: 28))
            } else {
                RoundedRectangle(cornerRadius: 28)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 140, height: 140)
            }

            // Content
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(appName)
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                        .tracking(0.5)

                    Spacer()

                    Text(timestamp)
                        .font(.system(size: 32))
                        .foregroundColor(.white.opacity(0.7))
                }

                Text(title)
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.system(size: 38))
                    .foregroundColor(.white.opacity(0.85))
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 40)
                .fill(.ultraThinMaterial)
                .opacity(0.9)
        )
    }
}

// MARK: - 5. Color Palette (Pantone Style)
struct ColorPaletteArtifactView: View {
    let data: ViralShareData

    // Generate Pantone-style color codes based on date and index
    private func colorCode(index: Int) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        let dateCode = dateFormatter.string(from: data.date)
        let letter = Character(UnicodeScalar(65 + index)!) // A, B, C, D, E...
        return "PHLOCK-\(dateCode)-\(letter)"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("PHLOCK")
                        .font(.system(size: 72, weight: .black))
                        .tracking(8)
                    Text("COLOR SYSTEM")
                        .font(.system(size: 36, weight: .medium))
                        .tracking(4)
                        .foregroundColor(.gray)
                }
                Spacer()
                Text(data.date.formatted(.dateTime.month(.wide).day().year()))
                    .font(.system(size: 30, weight: .medium))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 72)
            .padding(.top, 90)
            .padding(.bottom, 48)
            .background(Color.white)

            // User's swatch (larger, featured)
            PantoneSwatchRow(
                track: data.userTrack.name,
                artist: data.userTrack.artistName ?? "Unknown Artist",
                username: "@\(data.userName)",
                url: data.userTrack.albumArtUrl,
                colorCode: colorCode(index: 0),
                isFeature: true
            )

            // Divider line
            Rectangle()
                .fill(Color.black.opacity(0.1))
                .frame(height: 2)

            // Friends' swatches
            ForEach(Array(data.friendsTracks.prefix(4).enumerated()), id: \.element.id) { index, friend in
                PantoneSwatchRow(
                    track: friend.trackName,
                    artist: friend.artistName,
                    username: "@\(friend.username)",
                    url: friend.albumArtUrl,
                    colorCode: colorCode(index: index + 1),
                    isFeature: false
                )

                if index < min(3, data.friendsTracks.count - 1) {
                    Rectangle()
                        .fill(Color.black.opacity(0.05))
                        .frame(height: 1)
                }
            }

            Spacer(minLength: 0)

            // Footer
            HStack {
                Text("®")
                    .font(.system(size: 36))
                    .foregroundColor(.gray)
                Text("PHLOCK PALETTE")
                    .font(.system(size: 36, weight: .bold))
                    .tracking(2)
                Spacer()
                Text("@myphlock")
                    .font(.system(size: 30))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 72)
            .padding(.vertical, 48)
            .background(Color.white)
        }
        .background(Color.white)
        .frame(width: 1080, height: 1920)
    }
}

struct PantoneSwatchRow: View {
    let track: String
    let artist: String
    let username: String
    let url: String?
    let colorCode: String
    let isFeature: Bool

    @State private var dominantColor: Color = Color.gray

    var body: some View {
        HStack(spacing: 0) {
            // Album art thumbnail
            if let urlString = url, let imageUrl = URL(string: urlString) {
                AsyncImage(url: imageUrl) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .onAppear {
                                // Extract color from the loaded image
                                extractColor(from: imageUrl)
                            }
                    case .failure(_):
                        Rectangle().fill(Color.gray.opacity(0.3))
                    case .empty:
                        Rectangle().fill(Color.gray.opacity(0.1))
                    @unknown default:
                        Rectangle().fill(Color.gray.opacity(0.1))
                    }
                }
                .frame(width: isFeature ? 240 : 160, height: isFeature ? 240 : 160)
                .clipped()
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: isFeature ? 240 : 160, height: isFeature ? 240 : 160)
            }

            // Color swatch area
            ZStack(alignment: .bottomLeading) {
                dominantColor

                VStack(alignment: .leading, spacing: isFeature ? 12 : 6) {
                    // Username badge
                    Text(username)
                        .font(.system(size: isFeature ? 36 : 28, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, isFeature ? 18 : 12)
                        .padding(.vertical, isFeature ? 8 : 4)
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(6)

                    // Track name
                    Text(track)
                        .font(.system(size: isFeature ? 48 : 36, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    // Artist name
                    Text(artist)
                        .font(.system(size: isFeature ? 36 : 28))
                        .foregroundColor(.white.opacity(0.85))
                        .lineLimit(1)
                }
                .padding(isFeature ? 36 : 24)
                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
            }
            .frame(maxWidth: .infinity)
            .frame(height: isFeature ? 360 : 220)

            // Pantone-style code strip on right
            VStack {
                Spacer()
                Text(colorCode)
                    .font(.system(size: 18, weight: .medium, design: .monospaced))
                    .foregroundColor(.black.opacity(0.6))
                    .rotationEffect(.degrees(-90))
                    .fixedSize()
                Spacer()
            }
            .frame(width: 60)
            .background(Color.white)
        }
        .frame(height: isFeature ? 360 : 220)
    }

    private func extractColor(from url: URL) {
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let uiImage = UIImage(data: data),
                   let color = extractDominantColor(from: uiImage) {
                    await MainActor.run {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            self.dominantColor = color
                        }
                    }
                }
            } catch {
                // Keep default gray
            }
        }
    }

    private func extractDominantColor(from image: UIImage) -> Color? {
        guard let ciImage = CIImage(image: image) else { return nil }

        let extentVector = CIVector(
            x: ciImage.extent.origin.x,
            y: ciImage.extent.origin.y,
            z: ciImage.extent.size.width,
            w: ciImage.extent.size.height
        )

        guard let filter = CIFilter(
            name: "CIAreaAverage",
            parameters: [
                kCIInputImageKey: ciImage,
                kCIInputExtentKey: extentVector
            ]
        ),
        let outputImage = filter.outputImage else {
            return nil
        }

        let context = CIContext(options: [.workingColorSpace: CGColorSpaceCreateDeviceRGB()])
        var bitmap = [UInt8](repeating: 0, count: 4)

        context.render(
            outputImage,
            toBitmap: &bitmap,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )

        return Color(
            red: Double(bitmap[0]) / 255.0,
            green: Double(bitmap[1]) / 255.0,
            blue: Double(bitmap[2]) / 255.0
        )
    }
}

// MARK: - 6. Concert Ticket (Stub Style)
struct ConcertTicketArtifactView: View {
    let data: ViralShareData

    // Generate a ticket number from the date
    private var ticketNumber: String {
        let calendar = Calendar.current
        let day = calendar.component(.day, from: data.date)
        let month = calendar.component(.month, from: data.date)
        return String(format: "%03d%03d", month, day)
    }

    // Possessive form: "'" for names ending in s, "'s" otherwise
    private var possessiveUserName: String {
        data.userName.lowercased().hasSuffix("s") ? "@\(data.userName)'" : "@\(data.userName)'s"
    }

    // Friends for special guests section (now shows track info too)
    private var guestsList: [(username: String, trackName: String, artistName: String, albumArtUrl: String?)] {
        data.friendsTracks.prefix(4).map { ($0.username, $0.trackName, $0.artistName, $0.albumArtUrl) }
    }

    // Only non-nil album art URLs for the barcode section (dynamic)
    private var albumArtUrls: [String] {
        var urls: [String] = []
        if let userUrl = data.userTrack.albumArtUrl {
            urls.append(userUrl)
        }
        for friend in data.friendsTracks.prefix(4) {
            if let friendUrl = friend.albumArtUrl {
                urls.append(friendUrl)
            }
        }
        return urls
    }

    var body: some View {
        ZStack {
            // Dark background with subtle gradient
            LinearGradient(
                colors: [Color(hex: "1a1a1a"), Color(hex: "2d2d2d")],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 0) {
                Spacer()

                // Main ticket with perforated edge
                HStack(spacing: 0) {
                    // Left stub (tear-off portion) with album art
                    ZStack {
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color.white)

                        VStack(spacing: 12) {
                            Text("ADMIT")
                                .font(.system(size: 26, weight: .black))
                                .foregroundColor(.black)
                            Text("ONE")
                                .font(.system(size: 26, weight: .black))
                                .foregroundColor(.black)

                            Rectangle()
                                .fill(Color.black.opacity(0.2))
                                .frame(width: 60, height: 2)

                            // Album art with holographic overlay on stub
                            ZStack {
                                if let url = URL(string: data.userTrack.albumArtUrl ?? "") {
                                    AsyncImage(url: url) { image in
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        Rectangle()
                                            .fill(Color.gray.opacity(0.3))
                                    }
                                    .frame(width: 90, height: 90)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                } else {
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: 90, height: 90)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }

                                // Holographic overlay
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                .purple.opacity(0.3),
                                                .blue.opacity(0.2),
                                                .cyan.opacity(0.3),
                                                .green.opacity(0.2),
                                                .yellow.opacity(0.3)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 90, height: 90)
                                    .blendMode(.overlay)
                            }

                            Text(data.date.formatted(.dateTime.month(.abbreviated).day()))
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 24)
                    }
                    .frame(width: 140)

                    // Perforated line (semicircle cutouts)
                    PerforatedEdge()
                        .frame(width: 30)

                    // Main ticket body
                    ZStack {
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color.white)

                        VStack(spacing: 0) {
                            // Header with holographic strip
                            ZStack {
                                // Holographic gradient bar
                                LinearGradient(
                                    colors: [.purple.opacity(0.3), .blue.opacity(0.3), .cyan.opacity(0.3), .green.opacity(0.3), .yellow.opacity(0.3), .orange.opacity(0.3), .pink.opacity(0.3)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )

                                HStack {
                                    Text("\(possessiveUserName) PHLOCK")
                                        .font(.system(size: 36, weight: .black))
                                        .foregroundColor(.black)
                                    Spacer()
                                    Text("NO. \(ticketNumber)")
                                        .font(.system(size: 30, weight: .bold, design: .monospaced))
                                        .foregroundColor(.red)
                                }
                                .padding(.horizontal, 48)
                            }
                            .frame(height: 90)

                            // Event title
                            VStack(spacing: 12) {
                                Text("PHLOCK WORLD TOUR")
                                    .font(.system(size: 36, weight: .bold))
                                    .tracking(4)
                                    .foregroundColor(.gray)

                                Text(data.date.formatted(.dateTime.year()))
                                    .font(.system(size: 30, weight: .medium))
                                    .foregroundColor(.gray.opacity(0.7))
                            }
                            .padding(.top, 36)

                            // Main headliner
                            VStack(spacing: 18) {
                                Text("HEADLINER")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(.gray)
                                    .tracking(6)

                                Text((data.userTrack.artistName ?? "Unknown Artist").uppercased())
                                    .font(.system(size: 72, weight: .black))
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.5)
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 24)

                                Text("\"\(data.userTrack.name)\"")
                                    .font(.system(size: 36, weight: .medium))
                                    .foregroundColor(.gray)
                                    .lineLimit(1)
                            }
                            .padding(.vertical, 36)

                            // Divider
                            Rectangle()
                                .fill(Color.black.opacity(0.1))
                                .frame(height: 2)
                                .padding(.horizontal, 48)

                            // Special guests section - shows username, track, artist for each
                            VStack(spacing: 16) {
                                Text("SPECIAL GUESTS")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.gray)
                                    .tracking(4)

                                VStack(spacing: 12) {
                                    ForEach(Array(guestsList.prefix(3).enumerated()), id: \.offset) { _, guest in
                                        VStack(spacing: 4) {
                                            Text("@\(guest.username)")
                                                .font(.system(size: 26, weight: .bold))
                                                .foregroundColor(.black)
                                            Text("\(guest.artistName) – \"\(guest.trackName)\"")
                                                .font(.system(size: 22, weight: .medium))
                                                .foregroundColor(.gray)
                                                .lineLimit(1)
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 24)

                            // Album art "barcode" section - dynamic sizing
                            VStack(spacing: 12) {
                                // Album art thumbnails as visual barcode - only shows albums that exist
                                HStack(spacing: 8) {
                                    ForEach(Array(albumArtUrls.enumerated()), id: \.offset) { _, urlString in
                                        if let url = URL(string: urlString) {
                                            AsyncImage(url: url) { image in
                                                image
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fill)
                                            } placeholder: {
                                                Rectangle()
                                                    .fill(Color.gray.opacity(0.2))
                                            }
                                            .frame(width: albumArtUrls.count == 1 ? 100 : (albumArtUrls.count <= 3 ? 84 : 72),
                                                   height: albumArtUrls.count == 1 ? 100 : (albumArtUrls.count <= 3 ? 84 : 72))
                                            .clipShape(RoundedRectangle(cornerRadius: 6))
                                        }
                                    }
                                }

                                Text("PHLOCK-\(ticketNumber)-VIP")
                                    .font(.system(size: 24, weight: .medium, design: .monospaced))
                                    .foregroundColor(.gray)
                            }
                            .padding(.horizontal, 48)
                            .padding(.bottom, 24)

                            // Footer
                            HStack {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("DATE")
                                        .font(.system(size: 22, weight: .bold))
                                        .foregroundColor(.gray)
                                    Text(data.date.formatted(date: .abbreviated, time: .omitted))
                                        .font(.system(size: 30, weight: .bold))
                                        .foregroundColor(.black)
                                }

                                Spacer()

                                VStack(spacing: 6) {
                                    Text("SEAT")
                                        .font(.system(size: 22, weight: .bold))
                                        .foregroundColor(.gray)
                                    Text("VIP A1")
                                        .font(.system(size: 30, weight: .bold))
                                        .foregroundColor(.black)
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 6) {
                                    Text("VENUE")
                                        .font(.system(size: 22, weight: .bold))
                                        .foregroundColor(.gray)
                                    Text("PHLOCK")
                                        .font(.system(size: 30, weight: .bold))
                                        .foregroundColor(.black)
                                }
                            }
                            .padding(.horizontal, 48)
                            .padding(.vertical, 30)
                            .background(Color.gray.opacity(0.05))
                        }
                    }
                }
                .frame(height: 1100)
                .padding(.horizontal, 48)
                .shadow(color: .black.opacity(0.5), radius: 40, x: 0, y: 20)

                // "Keep this portion" text
                Text("★ KEEP THIS PORTION ★")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white.opacity(0.4))
                    .tracking(4)
                    .padding(.top, 48)

                Spacer()

                // Branding
                Text("@myphlock")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.bottom, 60)
            }
        }
        .frame(width: 1080, height: 1920)
    }
}

// Perforated edge with semicircle cutouts
struct PerforatedEdge: View {
    var body: some View {
        GeometryReader { geometry in
            let circleRadius: CGFloat = 12
            let spacing: CGFloat = 30
            let count = Int(geometry.size.height / spacing)

            ZStack {
                // White background strip
                Rectangle()
                    .fill(Color.white)

                // Cutout circles
                VStack(spacing: spacing - circleRadius * 2) {
                    ForEach(0..<count, id: \.self) { _ in
                        Circle()
                            .fill(Color(hex: "1a1a1a"))
                            .frame(width: circleRadius * 2, height: circleRadius * 2)
                    }
                }
            }
        }
    }
}

// Helper for Hex Colors
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - =====================================================
// MARK: - RENDERABLE ARTIFACT VIEWS (for ImageRenderer export)
// MARK: - =====================================================
// These versions use pre-loaded UIImage instead of AsyncImage,
// and solid colors instead of .ultraThinMaterial effects.
// ImageRenderer doesn't support async loading or material effects.

/// Renderable Magazine Cover - uses pre-loaded UIImage
struct RenderableMagazineCoverView: View {
    let renderData: ViralShareRenderData

    private var data: ViralShareData { renderData.data }

    private func generateHeadline(for friend: ViralShareData.FriendTrack, index: Int) -> String {
        let templates = [
            "@\(friend.username): \"\(friend.trackName)\" by \(friend.artistName)",
            "@\(friend.username) picks \"\(friend.trackName)\" - \(friend.artistName)",
            "@\(friend.username)'s choice: \(friend.artistName) – \"\(friend.trackName)\""
        ]
        return templates[index % templates.count]
    }

    private var fullDate: String {
        data.date.formatted(.dateTime.weekday(.wide).month(.wide).day().year()).uppercased()
    }

    private var issueNumber: String {
        let calendar = Calendar.current
        let weekOfYear = calendar.component(.weekOfYear, from: data.date)
        return String(format: "NO. %03d", weekOfYear)
    }

    var body: some View {
        ZStack {
            // Full bleed background - use pre-loaded image
            if let uiImage = renderData.userAlbumArt {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Color.black
            }

            // Gradient overlay for text legibility
            LinearGradient(
                colors: [
                    Color.black.opacity(0.2),
                    Color.black.opacity(0.3),
                    Color.black.opacity(0.85)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 0) {
                HStack {
                    Text(issueNumber)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                    Spacer()
                    Text(fullDate)
                        .font(.system(size: 22, weight: .medium))
                        .tracking(2)
                        .foregroundColor(.white.opacity(0.8))
                    Spacer()
                    Text("FREE")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.horizontal, 500)
                .padding(.top, 60)

                Text("PHLOCK")
                    .font(.custom("Didot", size: 180))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .tracking(8)
                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                    .padding(.top, 12)

                Spacer()

                VStack(alignment: .leading, spacing: 12) {
                    Text("THE COVER")
                        .font(.system(size: 24, weight: .bold))
                        .tracking(4)
                        .foregroundColor(.white.opacity(0.7))
                    Text("@\(data.userName)")
                        .font(.custom("Didot", size: 60))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Text("\"\(data.userTrack.name)\"")
                        .font(.system(size: 42, weight: .bold, design: .serif))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text("by \(data.userTrack.artistName ?? "Unknown")")
                        .font(.system(size: 32, weight: .medium, design: .serif))
                        .foregroundColor(.white.opacity(0.85))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 500)
                .padding(.bottom, 30)

                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .frame(height: 1)
                    .padding(.horizontal, 500)

                VStack(alignment: .leading, spacing: 20) {
                    Text("ALSO IN THIS ISSUE")
                        .font(.system(size: 22, weight: .bold))
                        .tracking(4)
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.top, 20)

                    ForEach(Array(data.friendsTracks.prefix(4).enumerated()), id: \.element.id) { index, friend in
                        Text(generateHeadline(for: friend, index: index))
                            .font(.system(size: 30, weight: .medium, design: .serif))
                            .foregroundColor(.white.opacity(0.9))
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 500)
                .padding(.bottom, 30)

                HStack(alignment: .bottom) {
                    VStack(spacing: 4) {
                        HStack(spacing: 2) {
                            ForEach(0..<18, id: \.self) { _ in
                                Rectangle()
                                    .fill(Color.white)
                                    .frame(width: CGFloat.random(in: 2...5), height: 48)
                            }
                        }
                        Text("@myphlock")
                            .font(.system(size: 18, design: .monospaced))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    Spacer()
                    Text("@myphlock")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 500)
                .padding(.bottom, 60)
            }
        }
        .frame(width: 1080, height: 1920)
        .clipped()
    }
}

/// Renderable Notification Stack - uses pre-loaded UIImage and solid background instead of .ultraThinMaterial
struct RenderableNotificationStackView: View {
    let renderData: ViralShareRenderData

    private var data: ViralShareData { renderData.data }

    private var formattedDate: String {
        data.date.formatted(.dateTime.weekday(.wide).month(.wide).day())
    }

    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: Date())
    }

    var body: some View {
        ZStack {
            // Blurred album art background - use pre-loaded image
            if let uiImage = renderData.userAlbumArt {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .blur(radius: 60)
                    .scaleEffect(1.4)
            } else {
                LinearGradient(
                    colors: [Color(hex: "2c2c2e"), Color(hex: "1c1c1e")],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }

            Color.black.opacity(0.25)

            VStack(spacing: 0) {
                VStack(spacing: 12) {
                    Text(formattedDate)
                        .font(.system(size: 56, weight: .regular))
                        .foregroundColor(.white)
                    Text(formattedTime)
                        .font(.system(size: 280, weight: .light))
                        .foregroundColor(.white)
                        .tracking(-8)
                }
                .padding(.top, 80)

                Spacer()

                VStack(spacing: 24) {
                    RenderableNotificationCard(
                        appName: "phlock",
                        title: "@\(data.userName) set today's mood",
                        subtitle: "\"\(data.userTrack.name)\" by \(data.userTrack.artistName ?? "Unknown")",
                        timestamp: "now",
                        albumArtImage: renderData.userAlbumArt
                    )

                    ForEach(Array(data.friendsTracks.prefix(2).enumerated()), id: \.element.id) { index, friend in
                        RenderableNotificationCard(
                            appName: "phlock",
                            title: "@\(friend.username) shared a track",
                            subtitle: "\"\(friend.trackName)\" by \(friend.artistName)",
                            timestamp: "\(index + 1)m ago",
                            albumArtImage: renderData.friendsAlbumArt[friend.id]
                        )
                    }
                }
                .padding(.horizontal, 450)
                .padding(.bottom, 160)

                Text("@myphlock")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.bottom, 20)

                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.white.opacity(0.6))
                    .frame(width: 200, height: 8)
                    .padding(.bottom, 30)
            }
        }
        .frame(width: 1080, height: 1920)
        .clipped()
    }
}

/// Renderable notification card - uses solid semi-transparent background instead of .ultraThinMaterial
struct RenderableNotificationCard: View {
    let appName: String
    let title: String
    let subtitle: String
    let timestamp: String
    let albumArtImage: UIImage?

    var body: some View {
        HStack(alignment: .center, spacing: 24) {
            // Album art thumbnail
            if let uiImage = albumArtImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 140, height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 28))
            } else {
                RoundedRectangle(cornerRadius: 28)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 140, height: 140)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(appName)
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                        .tracking(0.5)
                    Spacer()
                    Text(timestamp)
                        .font(.system(size: 32))
                        .foregroundColor(.white.opacity(0.7))
                }
                Text(title)
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 38))
                    .foregroundColor(.white.opacity(0.85))
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 40)
                .fill(Color.black.opacity(0.4)) // Solid color instead of .ultraThinMaterial
        )
    }
}

/// Renderable Color Palette - uses pre-loaded images and colors
struct RenderableColorPaletteView: View {
    let renderData: ViralShareRenderData

    private var data: ViralShareData { renderData.data }

    private func colorCode(index: Int) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        let dateCode = dateFormatter.string(from: data.date)
        let letter = Character(UnicodeScalar(65 + index)!)
        return "PHLOCK-\(dateCode)-\(letter)"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("PHLOCK")
                        .font(.system(size: 72, weight: .black))
                        .tracking(8)
                    Text("COLOR SYSTEM")
                        .font(.system(size: 36, weight: .medium))
                        .tracking(4)
                        .foregroundColor(.gray)
                }
                Spacer()
                Text(data.date.formatted(.dateTime.month(.wide).day().year()))
                    .font(.system(size: 30, weight: .medium))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 72)
            .padding(.top, 90)
            .padding(.bottom, 48)
            .background(Color.white)

            // User's swatch
            RenderablePantoneSwatchRow(
                track: data.userTrack.name,
                artist: data.userTrack.artistName ?? "Unknown Artist",
                username: "@\(data.userName)",
                image: renderData.userAlbumArt,
                dominantColor: renderData.userDominantColor ?? .gray,
                colorCode: colorCode(index: 0),
                isFeature: true
            )

            Rectangle()
                .fill(Color.black.opacity(0.1))
                .frame(height: 2)

            ForEach(Array(data.friendsTracks.prefix(4).enumerated()), id: \.element.id) { index, friend in
                RenderablePantoneSwatchRow(
                    track: friend.trackName,
                    artist: friend.artistName,
                    username: "@\(friend.username)",
                    image: renderData.friendsAlbumArt[friend.id],
                    dominantColor: renderData.dominantColors[friend.id] ?? .gray,
                    colorCode: colorCode(index: index + 1),
                    isFeature: false
                )

                if index < min(3, data.friendsTracks.count - 1) {
                    Rectangle()
                        .fill(Color.black.opacity(0.05))
                        .frame(height: 1)
                }
            }

            Spacer(minLength: 0)

            HStack {
                Text("®")
                    .font(.system(size: 36))
                    .foregroundColor(.gray)
                Text("PHLOCK PALETTE")
                    .font(.system(size: 36, weight: .bold))
                    .tracking(2)
                Spacer()
                Text("@myphlock")
                    .font(.system(size: 30))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 72)
            .padding(.vertical, 48)
            .background(Color.white)
        }
        .background(Color.white)
        .frame(width: 1080, height: 1920)
    }
}

/// Renderable Pantone swatch row - uses pre-loaded image and color
struct RenderablePantoneSwatchRow: View {
    let track: String
    let artist: String
    let username: String
    let image: UIImage?
    let dominantColor: Color
    let colorCode: String
    let isFeature: Bool

    var body: some View {
        HStack(spacing: 0) {
            if let uiImage = image {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: isFeature ? 240 : 160, height: isFeature ? 240 : 160)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: isFeature ? 240 : 160, height: isFeature ? 240 : 160)
            }

            ZStack(alignment: .bottomLeading) {
                dominantColor

                VStack(alignment: .leading, spacing: isFeature ? 12 : 6) {
                    Text(username)
                        .font(.system(size: isFeature ? 36 : 28, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, isFeature ? 18 : 12)
                        .padding(.vertical, isFeature ? 8 : 4)
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(6)

                    Text(track)
                        .font(.system(size: isFeature ? 48 : 36, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Text(artist)
                        .font(.system(size: isFeature ? 36 : 28))
                        .foregroundColor(.white.opacity(0.85))
                        .lineLimit(1)
                }
                .padding(isFeature ? 36 : 24)
                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
            }
            .frame(maxWidth: .infinity)
            .frame(height: isFeature ? 360 : 220)

            VStack {
                Spacer()
                Text(colorCode)
                    .font(.system(size: 18, weight: .medium, design: .monospaced))
                    .foregroundColor(.black.opacity(0.6))
                    .rotationEffect(.degrees(-90))
                    .fixedSize()
                Spacer()
            }
            .frame(width: 60)
            .background(Color.white)
        }
        .frame(height: isFeature ? 360 : 220)
    }
}

/// Renderable Festival Poster - uses pre-loaded UIImage
struct RenderableFestivalPosterView: View {
    let renderData: ViralShareRenderData

    private var data: ViralShareData { renderData.data }

    var body: some View {
        ZStack {
            // Full-bleed album art background
            if let uiImage = renderData.userAlbumArt {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 1080, height: 1920)
                    .clipped()
            } else {
                Color(hex: "1a1a1a")
            }

            // Strong gradient overlay for text legibility on any album art
            LinearGradient(
                colors: [
                    Color.black.opacity(0.8),
                    Color.black.opacity(0.5),
                    Color.black.opacity(0.6),
                    Color.black.opacity(0.9)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 0) {
                VStack(spacing: 12) {
                    HStack(spacing: 24) {
                        ForEach(0..<5, id: \.self) { _ in
                            Text("★")
                                .font(.system(size: 36))
                                .foregroundColor(.yellow)
                        }
                    }

                    Text("PHLOCK FEST")
                        .font(.system(size: 108, weight: .black))
                        .foregroundColor(.yellow)
                        .tracking(6)

                    Text(data.date.formatted(.dateTime.weekday(.wide).month(.wide).day().year()).uppercased())
                        .font(.system(size: 36, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .tracking(4)
                }
                .padding(.top, 100)

                Rectangle()
                    .fill(Color.yellow)
                    .frame(height: 4)
                    .padding(.horizontal, 120)
                    .padding(.vertical, 30)

                // Headliner section
                VStack(spacing: 16) {
                    Text("HEADLINED BY")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(.yellow)
                        .tracking(8)

                    Text((data.userTrack.artistName ?? "Unknown Artist").uppercased())
                        .font(.system(size: 144, weight: .black))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.3)
                        .padding(.horizontal, 48)

                    Text("\"\(data.userTrack.name)\"")
                        .font(.system(size: 54, weight: .medium))
                        .foregroundColor(.yellow)
                        .lineLimit(1)

                    Text("CURATED BY")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(.yellow)
                        .tracking(8)
                        .padding(.top, 8)

                    Text("@\(data.userName)")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.yellow)
                }
                .padding(.bottom, 40)

                HStack(spacing: 24) {
                    Rectangle()
                        .fill(Color.white.opacity(0.3))
                        .frame(height: 2)
                    Text("★")
                        .font(.system(size: 36))
                        .foregroundColor(.white.opacity(0.5))
                    Rectangle()
                        .fill(Color.white.opacity(0.3))
                        .frame(height: 2)
                }
                .padding(.horizontal, 72)
                .padding(.vertical, 24)

                // Special guests with larger album thumbnails and text
                VStack(spacing: 20) {
                    Text("SPECIAL GUESTS")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.white)
                        .tracking(8)

                    ForEach(data.friendsTracks.prefix(4)) { friend in
                        HStack(spacing: 24) {
                            if let uiImage = renderData.friendsAlbumArt[friend.id] {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 90, height: 90)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            } else {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.white.opacity(0.1))
                                    .frame(width: 90, height: 90)
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 12) {
                                    Text(friend.artistName.uppercased())
                                        .font(.system(size: 38, weight: .black))
                                        .foregroundColor(.white)
                                        .lineLimit(1)

                                    Text("•")
                                        .foregroundColor(.white.opacity(0.4))

                                    Text("@\(friend.username)")
                                        .font(.system(size: 32, weight: .bold))
                                        .foregroundColor(.yellow)
                                }

                                Text("\"\(friend.trackName)\"")
                                    .font(.system(size: 28, weight: .medium))
                                    .foregroundColor(.white.opacity(0.8))
                                    .lineLimit(1)
                            }

                            Spacer()
                        }
                        .padding(.horizontal, 60)
                    }
                }

                Spacer()

                VStack(spacing: 18) {
                    Rectangle()
                        .fill(Color.yellow)
                        .frame(height: 4)
                        .padding(.horizontal, 120)

                    HStack {
                        Image(systemName: "globe")
                            .font(.system(size: 36))
                            .foregroundColor(.white)
                        Text("@myphlock")
                            .font(.system(size: 30, weight: .medium))
                            .foregroundColor(.white)

                        Spacer()

                        Text("DAILY MUSIC CURATION")
                            .font(.system(size: 24, weight: .bold))
                            .tracking(4)
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .padding(.horizontal, 72)
                }
                .padding(.bottom, 72)
            }
        }
        .frame(width: 1080, height: 1920)
    }
}

/// Renderable Daily Mixtape - uses pre-loaded UIImage for tape window
struct RenderableDailyMixtapeView: View {
    let renderData: ViralShareRenderData

    private var data: ViralShareData { renderData.data }

    private var mixTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd"
        return formatter.string(from: data.date).uppercased() + " MIX"
    }

    // Possessive form: "'" for names ending in s, "'s" otherwise
    private var possessiveUserName: String {
        data.userName.lowercased().hasSuffix("s") ? "@\(data.userName)'" : "@\(data.userName)'s"
    }

    // Get pre-loaded album images in order (only non-nil)
    private var albumImages: [UIImage] {
        var images: [UIImage] = []
        if let userImg = renderData.userAlbumArt {
            images.append(userImg)
        }
        for friend in data.friendsTracks.prefix(4) {
            if let friendImg = renderData.friendsAlbumArt[friend.id] {
                images.append(friendImg)
            }
        }
        return images
    }

    var body: some View {
        ZStack {
            Color(hex: "f5f0e8")

            VStack(spacing: 0) {
                VStack(spacing: 12) {
                    Text("DAILY MIXTAPE")
                        .font(.system(size: 60, weight: .bold, design: .monospaced))
                        .tracking(6)
                        .foregroundColor(.black)

                    Text("MIXED BY @\(data.userName.uppercased())")
                        .font(.system(size: 36, weight: .medium))
                        .foregroundColor(.gray)
                }
                .padding(.top, 120)

                Spacer()

                // Cassette with album art
                RenderableClearShellCassette(mixTitle: mixTitle, userName: data.userName, albumImages: albumImages)
                    .frame(height: 540)
                    .padding(.horizontal, 60)

                Spacer()

                JCardTracklist(data: data)
                    .padding(.horizontal, 60)
                    .padding(.bottom, 90)
            }
        }
        .frame(width: 1080, height: 1920)
    }
}

/// Renderable cassette shell with pre-loaded images
struct RenderableClearShellCassette: View {
    let mixTitle: String
    let userName: String
    var albumImages: [UIImage] = []

    // Possessive form for cassette label
    private var possessiveUserName: String {
        userName.lowercased().hasSuffix("s") ? "@\(userName)'" : "@\(userName)'s"
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.9),
                            Color.gray.opacity(0.2),
                            Color.white.opacity(0.7)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.gray.opacity(0.4), lineWidth: 3)
                )

            VStack(spacing: 0) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(hex: "fffef5"))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )

                    VStack(spacing: 8) {
                        HStack {
                            Text("PHLOCK")
                                .font(.system(size: 24, weight: .black))
                                .foregroundColor(Color(hex: "cc3333"))
                            Spacer()
                            Text("C-60")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.gray)
                        }

                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 1)

                        Text(mixTitle)
                            .font(.custom("Marker Felt", size: 48))
                            .foregroundColor(Color(hex: "2255aa"))

                        Text("\(possessiveUserName) mix")
                            .font(.custom("Marker Felt", size: 32))
                            .foregroundColor(Color(hex: "444444"))

                        Spacer()
                    }
                    .padding(24)
                }
                .frame(height: 200)
                .padding(.horizontal, 36)
                .padding(.top, 36)

                // Tape window with album art grid - dynamic sizing
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(hex: "1a1a1a"))

                    HStack(spacing: 8) {
                        ForEach(Array(albumImages.enumerated()), id: \.offset) { _, uiImage in
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: albumImages.count == 1 ? 140 : (albumImages.count <= 3 ? 120 : 100),
                                       height: albumImages.count == 1 ? 140 : (albumImages.count <= 3 ? 120 : 100))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .saturation(0.7)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color(hex: "1a1a1a").opacity(0.25))
                                )
                        }
                    }

                    HStack {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.6))
                            .frame(width: 12, height: 60)
                        Spacer()
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.6))
                            .frame(width: 12, height: 60)
                    }
                    .padding(.horizontal, 24)

                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.1),
                                    Color.clear,
                                    Color.white.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .frame(height: 180)
                .padding(.horizontal, 60)
                .padding(.top, 24)

                Spacer()
            }

            VStack {
                HStack {
                    ScrewHole()
                    Spacer()
                    ScrewHole()
                }
                Spacer()
                HStack {
                    ScrewHole()
                    Spacer()
                    ScrewHole()
                }
            }
            .padding(30)

            HStack {
                VStack(spacing: 24) {
                    ForEach(0..<8, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 6, height: 30)
                    }
                }
                Spacer()
                VStack(spacing: 24) {
                    ForEach(0..<8, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 6, height: 30)
                    }
                }
            }
            .padding(.horizontal, 6)
        }
    }
}

/// Renderable Concert Ticket - uses pre-loaded UIImage
struct RenderableConcertTicketView: View {
    let renderData: ViralShareRenderData

    private var data: ViralShareData { renderData.data }

    private var ticketNumber: String {
        let calendar = Calendar.current
        let day = calendar.component(.day, from: data.date)
        let month = calendar.component(.month, from: data.date)
        return String(format: "%03d%03d", month, day)
    }

    // Possessive form: "'" for names ending in s, "'s" otherwise
    private var possessiveUserName: String {
        data.userName.lowercased().hasSuffix("s") ? "@\(data.userName)'" : "@\(data.userName)'s"
    }

    private var guestsList: [(username: String, trackName: String, artistName: String)] {
        data.friendsTracks.prefix(4).map { ($0.username, $0.trackName, $0.artistName) }
    }

    // Get pre-loaded album images in order (only non-nil)
    private var albumImages: [UIImage] {
        var images: [UIImage] = []
        if let userImg = renderData.userAlbumArt {
            images.append(userImg)
        }
        for friend in data.friendsTracks.prefix(4) {
            if let friendImg = renderData.friendsAlbumArt[friend.id] {
                images.append(friendImg)
            }
        }
        return images
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "1a1a1a"), Color(hex: "2d2d2d")],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 0) {
                Spacer()

                HStack(spacing: 0) {
                    // Stub with album art
                    ZStack {
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color.white)

                        VStack(spacing: 12) {
                            Text("ADMIT")
                                .font(.system(size: 26, weight: .black))
                                .foregroundColor(.black)
                            Text("ONE")
                                .font(.system(size: 26, weight: .black))
                                .foregroundColor(.black)

                            Rectangle()
                                .fill(Color.black.opacity(0.2))
                                .frame(width: 60, height: 2)

                            ZStack {
                                if let uiImage = renderData.userAlbumArt {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 90, height: 90)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                } else {
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: 90, height: 90)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }

                                RoundedRectangle(cornerRadius: 8)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                .purple.opacity(0.3),
                                                .blue.opacity(0.2),
                                                .cyan.opacity(0.3),
                                                .green.opacity(0.2),
                                                .yellow.opacity(0.3)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 90, height: 90)
                                    .blendMode(.overlay)
                            }

                            Text(data.date.formatted(.dateTime.month(.abbreviated).day()))
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 24)
                    }
                    .frame(width: 140)

                    PerforatedEdge()
                        .frame(width: 30)

                    ZStack {
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color.white)

                        VStack(spacing: 0) {
                            ZStack {
                                LinearGradient(
                                    colors: [.purple.opacity(0.3), .blue.opacity(0.3), .cyan.opacity(0.3), .green.opacity(0.3), .yellow.opacity(0.3), .orange.opacity(0.3), .pink.opacity(0.3)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )

                                HStack {
                                    Text("\(possessiveUserName) PHLOCK")
                                        .font(.system(size: 36, weight: .black))
                                        .foregroundColor(.black)
                                    Spacer()
                                    Text("NO. \(ticketNumber)")
                                        .font(.system(size: 30, weight: .bold, design: .monospaced))
                                        .foregroundColor(.red)
                                }
                                .padding(.horizontal, 48)
                            }
                            .frame(height: 90)

                            VStack(spacing: 12) {
                                Text("PHLOCK WORLD TOUR")
                                    .font(.system(size: 36, weight: .bold))
                                    .tracking(4)
                                    .foregroundColor(.gray)

                                Text(data.date.formatted(.dateTime.year()))
                                    .font(.system(size: 30, weight: .medium))
                                    .foregroundColor(.gray.opacity(0.7))
                            }
                            .padding(.top, 36)

                            VStack(spacing: 18) {
                                Text("HEADLINER")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(.gray)
                                    .tracking(6)

                                Text((data.userTrack.artistName ?? "Unknown Artist").uppercased())
                                    .font(.system(size: 72, weight: .black))
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.5)
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 24)

                                Text("\"\(data.userTrack.name)\"")
                                    .font(.system(size: 36, weight: .medium))
                                    .foregroundColor(.gray)
                                    .lineLimit(1)
                            }
                            .padding(.vertical, 36)

                            Rectangle()
                                .fill(Color.black.opacity(0.1))
                                .frame(height: 2)
                                .padding(.horizontal, 48)

                            VStack(spacing: 16) {
                                Text("SPECIAL GUESTS")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.gray)
                                    .tracking(4)

                                VStack(spacing: 12) {
                                    ForEach(Array(guestsList.prefix(3).enumerated()), id: \.offset) { _, guest in
                                        VStack(spacing: 4) {
                                            Text("@\(guest.username)")
                                                .font(.system(size: 26, weight: .bold))
                                                .foregroundColor(.black)
                                            Text("\(guest.artistName) – \"\(guest.trackName)\"")
                                                .font(.system(size: 22, weight: .medium))
                                                .foregroundColor(.gray)
                                                .lineLimit(1)
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 24)

                            // Album art "barcode" - dynamic sizing
                            VStack(spacing: 12) {
                                HStack(spacing: 8) {
                                    ForEach(Array(albumImages.enumerated()), id: \.offset) { _, uiImage in
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: albumImages.count == 1 ? 100 : (albumImages.count <= 3 ? 84 : 72),
                                                   height: albumImages.count == 1 ? 100 : (albumImages.count <= 3 ? 84 : 72))
                                            .clipShape(RoundedRectangle(cornerRadius: 6))
                                    }
                                }

                                Text("PHLOCK-\(ticketNumber)-VIP")
                                    .font(.system(size: 24, weight: .medium, design: .monospaced))
                                    .foregroundColor(.gray)
                            }
                            .padding(.horizontal, 48)
                            .padding(.bottom, 24)

                            HStack {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("DATE")
                                        .font(.system(size: 22, weight: .bold))
                                        .foregroundColor(.gray)
                                    Text(data.date.formatted(date: .abbreviated, time: .omitted))
                                        .font(.system(size: 30, weight: .bold))
                                        .foregroundColor(.black)
                                }

                                Spacer()

                                VStack(spacing: 6) {
                                    Text("SEAT")
                                        .font(.system(size: 22, weight: .bold))
                                        .foregroundColor(.gray)
                                    Text("VIP A1")
                                        .font(.system(size: 30, weight: .bold))
                                        .foregroundColor(.black)
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 6) {
                                    Text("VENUE")
                                        .font(.system(size: 22, weight: .bold))
                                        .foregroundColor(.gray)
                                    Text("PHLOCK")
                                        .font(.system(size: 30, weight: .bold))
                                        .foregroundColor(.black)
                                }
                            }
                            .padding(.horizontal, 48)
                            .padding(.vertical, 30)
                            .background(Color.gray.opacity(0.05))
                        }
                    }
                }
                .frame(height: 1100)
                .padding(.horizontal, 48)
                .shadow(color: .black.opacity(0.5), radius: 40, x: 0, y: 20)

                Text("★ KEEP THIS PORTION ★")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white.opacity(0.4))
                    .tracking(4)
                    .padding(.top, 48)

                Spacer()

                Text("@myphlock")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.bottom, 60)
            }
        }
        .frame(width: 1080, height: 1920)
    }
}

// MARK: - Renderable Artifact Factory

/// Factory to create the appropriate renderable view for a given style
struct RenderableArtifactFactory {
    @ViewBuilder
    static func view(for style: ViralShareStyle, renderData: ViralShareRenderData) -> some View {
        switch style {
        case .magazine:
            RenderableMagazineCoverView(renderData: renderData)
        case .festival:
            RenderableFestivalPosterView(renderData: renderData)
        case .mixtape:
            RenderableDailyMixtapeView(renderData: renderData)
        case .notifications:
            RenderableNotificationStackView(renderData: renderData)
        case .palette:
            RenderableColorPaletteView(renderData: renderData)
        case .ticket:
            RenderableConcertTicketView(renderData: renderData)
        }
    }
}
