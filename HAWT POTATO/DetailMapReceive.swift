import SwiftUI
import MapKit
import UIKit
import HAWTPotatoCore

struct PotatoDetailView: View {
    @Environment(PotatoStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let cardID: UUID
    @State private var throwing = false
    @State private var showMap = false
    @State private var showShare = false

    var body: some View {
        if let card = store.potato(cardID) {
            NavigationStack {
                ZStack {
                    ScreenBackground(heat: card.heat(at: store.now), exploded: card.status == .exploded)
                    ScrollView {
                        VStack(spacing: 20) {
                            PotatoCardView(
                                card: card,
                                me: store.me,
                                now: store.now,
                                onThrow: card.isHeld(by: store.me) && card.status != .exploded ? { throwing = true } : nil,
                                onBack: { dismiss() },
                                onCancelGame: {
                                    if store.cancelOwnPotato(card.id) {
                                        dismiss()
                                    }
                                },
                                onPause: { try? store.togglePause(card.id) }
                            )
                            journey(card)
                            HStack {
                                Button("VIEW MAP") { showMap = true }
                                if card.status == .exploded {
                                    Button("SHARE RESULT") { showShare = true }
                                }
                            }
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(HPColor.potatoOrange)
                        }
                        .padding(20)
                    }
                }
                .navigationTitle("POTATO #\(card.shortCode)")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Back") { dismiss() }
                    }
                }
                
                .sheet(isPresented: $throwing) { ThrowSheet(card: card) }
                .sheet(isPresented: $showMap) { JourneyMapView(card: card) }
                .sheet(isPresented: $showShare) {
                    ShareResultView(text: store.shareResultText(card), card: card)
                }
            }
        } else {
            Text("Potato gone.")
        }
    }

    private func journey(_ card: HotPotatoCard) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(card.history.enumerated()), id: \.element.id) { index, event in
                HStack(alignment: .top, spacing: 12) {
                    VStack {
                        Text(event.action == .exploded ? "💥" : event.action == .paused ? "⏸" : event.action == .resumed ? "▶️" : "🥔")
                        if index < card.history.count - 1 {
                            Rectangle().fill(HPColor.faint.opacity(0.45)).frame(width: 2, height: 28)
                        }
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(event.player.displayName)
                            .font(.headline)
                            .foregroundStyle(HPColor.ink)
                        Text(event.location?.displayName ?? (card.locationSharing == .hidden ? "Location Hidden" : "Location Hidden"))
                            .font(.caption)
                            .foregroundStyle(HPColor.faint)
                    }
                    Spacer()
                    Text(event.action == .exploded ? "💥" : (card.revealsPassTimes ? event.remaining.hpClock : "???"))
                        .font(HPFont.timer(16))
                        .foregroundStyle(event.action == .exploded ? HPColor.criticalRed : HPColor.muted)
                }
                .padding(.vertical, 4)
            }
        }
        .padding(16)
        .background(HPColor.card, in: RoundedRectangle(cornerRadius: 18))
    }
}

struct JourneyMapView: View {
    let card: HotPotatoCard
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                HPColor.nearBlack.ignoresSafeArea()
                if card.history.compactMap(\.location).filter({ $0.sharing != .hidden }).isEmpty {
                    VStack(spacing: 12) {
                        Text("📍")
                        Text("Location Hidden")
                            .font(HPFont.name())
                            .foregroundStyle(HPColor.ink)
                        Text("This potato kept its path private.")
                            .foregroundStyle(HPColor.muted)
                        Button("CANCEL") { dismiss() }
                            .font(.subheadline.weight(.heavy))
                            .foregroundStyle(HPColor.muted)
                            .padding(.top, 8)
                    }
                } else {
                    Map {
                        ForEach(card.history) { event in
                            if let location = event.location, location.sharing != .hidden {
                                Annotation(event.player.displayName, coordinate: location.coordinate) {
                                    Text(event.action == .exploded ? "💥" : (event.player.id == card.currentHolder.id ? "🥔🔥" : "🥔"))
                                        .font(.title)
                                }
                            }
                        }
                    }
                    .mapStyle(.standard(pointsOfInterest: .excludingAll))
                }
            }
            .navigationTitle(ProductCanon.voice.findMyPotato)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back") { dismiss() }
                }
            }
        }
    }
}

struct ShareResultView: View {
    let text: String
    let card: HotPotatoCard
    @Environment(\.dismiss) private var dismiss
    @Environment(PotatoStore.self) private var store
    @State private var sharing = false
    @State private var saved = false

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 22 / 255, green: 10 / 255, blue: 6 / 255),
                        HPColor.nearBlack
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 28) {
                        VStack(spacing: 8) {
                            Text("Cooked.")
                                .font(.system(size: 40, weight: .bold, design: .rounded))
                                .foregroundStyle(HPColor.ink)
                            Text("Share the damage.")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundStyle(HPColor.faint)
                        }
                        .padding(.top, 8)

                        PotatoDamageSheet(card: card, viewerName: store.me.displayName)
                            .scaleEffect(0.92)
                            .shadow(color: HPColor.potatoOrange.opacity(0.22), radius: 28, y: 16)
                            .allowsHitTesting(false)

                        VStack(spacing: 12) {
                            Button {
                                sharing = true
                            } label: {
                                Label("Share", systemImage: "square.and.arrow.up")
                                    .font(.system(size: 18, weight: .semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(.white, in: Capsule())
                                    .foregroundStyle(.black)
                            }
                            Button {
                                let image = PotatoShareArtwork.damageImage(for: card, viewerName: store.me.displayName)
                                UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                                saved = true
                            } label: {
                                Label(saved ? "Saved to Photos" : "Save to Photos", systemImage: saved ? "checkmark" : "square.and.arrow.down")
                                    .font(.system(size: 16, weight: .semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(HPColor.card, in: Capsule())
                                    .foregroundStyle(HPColor.ink)
                            }
                            Button("Not now") { dismiss() }
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(HPColor.faint)
                        }
                        .padding(.horizontal, 28)
                        .padding(.bottom, 24)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(HPColor.muted)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .sheet(isPresented: $sharing) {
                DamageShareSheet(card: card, viewerName: store.me.displayName, caption: text)
                    .ignoresSafeArea()
            }
        }
    }
}

private struct DamageShareSheet: UIViewControllerRepresentable {
    let card: HotPotatoCard
    let viewerName: String
    let caption: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let image = PotatoShareArtwork.damageImage(for: card, viewerName: viewerName)
        let controller = UIActivityViewController(activityItems: [image, caption], applicationActivities: nil)
        controller.excludedActivityTypes = [.addToReadingList, .assignToContact, .print]
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct ReceiveCover: View {
    @Environment(PotatoStore.self) private var store
    let card: HotPotatoCard
    var queuedBehind: Int = 0
    var onThrow: () -> Void
    var onBack: () -> Void

    var body: some View {
        ZStack {
            ScreenBackground(heat: card.heat(at: store.now))
            VStack(spacing: 18) {
                if queuedBehind > 0 {
                    Text("\(queuedBehind) MORE COMING")
                        .font(.caption.weight(.heavy))
                        .tracking(1.4)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(HPColor.criticalRed, in: Capsule())
                        .foregroundStyle(.white)
                }
                let sender = card.previousHolder ?? card.creator
                if sender.id == store.me.id, card.previousHolder == nil {
                    Text("YOU LIT IT")
                        .font(HPFont.label())
                        .foregroundStyle(HPColor.muted)
                } else {
                    Text(sender.displayName.uppercased())
                        .font(HPFont.label())
                        .foregroundStyle(HPColor.muted)
                    Text("PASSED YOU THE POTATO")
                        .font(HPFont.title(28))
                        .foregroundStyle(HPColor.ink)
                    Text("It's in your hands now.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(HPColor.flameYellow)
                }
                Text(card.callsign.uppercased())
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(HPColor.potatoOrange)
                if let note = card.note, !note.isEmpty {
                    Text("“\(note)”")
                        .font(.title3.weight(.semibold).italic())
                        .foregroundStyle(HPColor.ink)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                PotatoVisual(heat: card.heat(at: store.now), exploded: false, reduceMotion: false, size: 230, skin: card.skin)
                Text(PotatoBrain.catchLine(card: card, me: store.me))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(HPColor.ink.opacity(0.88))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
                if card.gameMode != .classic {
                    Text(card.gameMode == .suddenDeath ? ProductCanon.voice.throwOrDie : card.gameMode.title)
                        .font(.caption.weight(.heavy))
                        .tracking(1.6)
                        .foregroundStyle(card.gameMode == .suddenDeath ? HPColor.criticalRed : HPColor.flameYellow)
                }
                Text(card.clockText(at: store.now, isHolder: true))
                    .font(card.hidesClock ? HPFont.title(28) : HPFont.timer(58))
                    .foregroundStyle(HPColor.flameYellow)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.7)
                if let caption = card.modeCaption(at: store.now, isHolder: true), card.gameMode == .suddenDeath {
                    Text(caption)
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(HPColor.muted)
                }
                ThrowButton(title: ProductCanon.voice.passIt, action: onThrow)
                    .padding(.horizontal, 24)
                Button("BACK") {
                    onBack()
                }
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(HPColor.muted)
                .padding(.top, 4)
                .accessibilityLabel("Back")
            }
            .padding()
        }
        .onAppear {
            SensoryDirector.shared.startReceivePulse(
                heat: card.heat(at: store.now),
                haptics: store.settings.haptics,
                countdownSound: store.settings.countdownSounds,
                skin: card.skin
            )
            if card.isIncomingCatch(for: store.me) {
                SensoryDirector.shared.potatoCaught(
                    sound: store.settings.soundEffects,
                    haptics: store.settings.haptics
                )
            }
        }
        .onChange(of: card.heat(at: store.now)) { _, heat in
            SensoryDirector.shared.updateReceiveHeat(
                heat,
                haptics: store.settings.haptics,
                countdownSound: store.settings.countdownSounds,
                skin: card.skin
            )
        }
        .onDisappear {
            SensoryDirector.shared.stopHeartbeat()
        }
    }
}

struct ExplosionCover: View {
    let name: String
    var isMe: Bool
    var recap: String? = nil
    var onBack: (() -> Void)? = nil

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 16) {
                Text("💥")
                    .font(.system(size: 96))
                Text(isMe ? ProductCanon.voice.youGotCooked : ProductCanon.voice.theyAreCooked)
                    .font(HPFont.title(34))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                if !isMe {
                    Text(name.uppercased())
                        .font(HPFont.name())
                        .foregroundStyle(HPColor.flameYellow)
                }
                if let recap, !recap.isEmpty {
                    Text(recap)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(HPColor.flameYellow)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                Button("BACK") {
                    onBack?()
                }
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(.white.opacity(0.8))
            }
        }
        .onTapGesture { onBack?() }
    }
}
