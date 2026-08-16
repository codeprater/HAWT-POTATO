import SwiftUI
import HAWTPotatoCore

struct PotatoCardView: View {
    let card: HotPotatoCard
    var me: PlayerRef
    var now: Date
    var compact: Bool = false
    var onThrow: (() -> Void)?
    var onOpen: (() -> Void)?
    var onBack: (() -> Void)?
    var onCancelGame: (() -> Void)?
    var onPause: (() -> Void)?
    var onQuickShare: ((PotatoShareDestination) -> Void)?
    var onQuickPass: ((PlayerRef, NearbyPeer?) -> Void)?
    var onQuickMessage: ((PhoneContact) -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let heat = card.heat(at: now)
        let remaining = max(0, card.remaining(at: now))
        VStack(spacing: compact ? 10 : 18) {
            HStack {
                Text(card.callsign.uppercased())
                    .font(.caption.weight(.heavy))
                    .tracking(2)
                    .foregroundStyle(HPColor.muted)
                Spacer()
                if onPause != nil || onCancelGame != nil || onBack != nil {
                    Button(cancelTitle) {
                        if card.isPaused, let onPause {
                            onPause()
                        } else if canPutOut, let onCancelGame {
                            onCancelGame()
                        } else if let onPause {
                            onPause()
                        } else if let onCancelGame {
                            onCancelGame()
                        } else {
                            onBack?()
                        }
                    }
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(HPColor.potatoOrange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                    .buttonStyle(.hapticPlain)
                }
            }
            if let note = card.note, !note.isEmpty, !compact {
                Text("“\(note)”")
                    .font(.subheadline.weight(.medium).italic())
                    .foregroundStyle(HPColor.ink.opacity(0.88))
                    .multilineTextAlignment(.center)
            }
            if card.isPaused {
                Text("PAUSED BY \(card.pausedBy?.displayName.uppercased() ?? "SOMEONE")")
                    .font(.caption.weight(.heavy))
                    .tracking(1.2)
                    .foregroundStyle(HPColor.flameYellow)
                    .multilineTextAlignment(.center)
                Text("Everyone in this potato can see the pause.")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(HPColor.faint)
                    .multilineTextAlignment(.center)
            } else if card.gameMode != .classic {
                Text(card.gameMode.title)
                    .font(.caption2.weight(.heavy))
                    .tracking(1.4)
                    .foregroundStyle(card.gameMode == .suddenDeath ? HPColor.criticalRed : HPColor.flameYellow)
            }

            PotatoVisual(
                heat: card.status == .exploded ? .finalCountdown : heat,
                exploded: card.status == .exploded,
                reduceMotion: reduceMotion,
                size: compact ? 120 : 210,
                skin: card.skin,
                live: !compact
            )

            if card.status != .exploded {
                HeatBadge(heat: heat)
                Text(card.clockText(at: now, isHolder: card.isHeld(by: me)))
                    .font(card.hidesClock ? HPFont.title(compact ? 22 : 28) : HPFont.timer(compact ? 36 : 56))
                    .foregroundStyle(heat == .critical || heat == .finalCountdown ? HPColor.criticalRed : HPColor.flameYellow)
                    .multilineTextAlignment(.center)
                    .monospacedDigit()
                    .minimumScaleFactor(0.7)
                    .accessibilityLabel(card.hidesClock ? PotatoBrain.mysteryMood(card: card, now: now) : "\(Int(remaining / 60)) minutes \(Int(remaining.truncatingRemainder(dividingBy: 60))) seconds remaining")
                Text(PotatoBrain.holdLine(card: card, me: me, now: now))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(HPColor.muted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
                if let caption = card.modeCaption(at: now, isHolder: card.isHeld(by: me)), card.isPaused || card.gameMode == .suddenDeath {
                    Text(caption)
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(HPColor.muted)
                        .multilineTextAlignment(.center)
                }
            } else {
                Text("💥")
                    .font(.largeTitle)
                Text("\(card.explosion?.loser.displayName.uppercased() ?? "SOMEONE") GOT COOKED")
                    .font(HPFont.name())
                    .foregroundStyle(HPColor.ink)
                    .multilineTextAlignment(.center)
                Text(PotatoBrain.explodeRecap(card: card))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(HPColor.flameYellow)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
                if let caption = card.modeCaption(at: now, isHolder: false) {
                    Text(caption)
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(HPColor.flameYellow)
                }
            }

            VStack(spacing: 4) {
                Text(card.isHeld(by: me) ? ProductCanon.voice.youHaveIt : ProductCanon.voice.currentlyWith)
                    .font(HPFont.label())
                    .foregroundStyle(HPColor.muted)
                Text(card.isHeld(by: me) ? "YOU" : card.currentHolder.displayName.uppercased())
                    .font(HPFont.name())
                    .foregroundStyle(HPColor.ink)
                Text("SENT BY \(card.creator.displayName.uppercased())")
                    .font(.caption)
                    .foregroundStyle(HPColor.faint)
                Text("\(card.passCount) passes · #\(card.shortCode)")
                    .font(.caption2)
                    .foregroundStyle(HPColor.secondaryGray)
            }

            if let onThrow, card.isHeld(by: me), card.status != .exploded, !card.isPaused, !compact {
                ThrowButton(action: onThrow)
                    .contextMenu {
                        if onQuickShare != nil || onQuickPass != nil {
                            QuickSendButtons(
                                card: card,
                                onShare: { destination in onQuickShare?(destination) },
                                onPass: { player, peer in onQuickPass?(player, peer) },
                                onMessageContact: { onQuickMessage?($0) }
                            )
                        }
                    }
                Button("BACK") { onBack?() }
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(HPColor.potatoOrange)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                    .buttonStyle(.hapticPlain)
                    .padding(.top, 2)
                    .accessibilityLabel("Back")
            } else if compact, card.isHeld(by: me), card.status != .exploded {
                Text("TAP TO OPEN")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(HPColor.potatoOrange)
            } else if let onOpen {
                Button("View Journey →", action: onOpen)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(HPColor.potatoOrange)
            }
        }
        .padding(compact ? 16 : 24)
        .frame(maxWidth: .infinity)
        .background(HPColor.card, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(border(heat), lineWidth: 2)
        )
        .accessibilityElement(children: .combine)
    }

    private var canPutOut: Bool {
        card.creator.id == me.id && card.isHeld(by: me) && card.passCount == 0 && !card.isPaused
    }

    private var cancelTitle: String {
        if card.isPaused { return "RESUME" }
        if canPutOut { return "CANCEL" }
        return "PAUSE"
    }

    private func border(_ heat: PotatoHeat) -> Color {
        if card.status == .exploded { return HPColor.criticalRed }
        if card.isPaused { return HPColor.flameYellow }
        switch heat {
        case .normal: return HPColor.potatoOrange.opacity(0.7)
        case .warming: return HPColor.potatoOrange
        case .hot: return HPColor.flameYellow
        case .critical, .finalCountdown: return HPColor.criticalRed
        }
    }
}
