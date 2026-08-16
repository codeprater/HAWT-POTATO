import SwiftUI
import UIKit
import MessageUI
import LinkPresentation
import UniformTypeIdentifiers
import HAWTPotatoCore

extension UTType {
    static var hawtPotato: UTType {
        UTType(exportedAs: ProductCanon.exportedTypeIdentifier)
    }
}

struct PotatoFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.hawtPotato, .json, .data] }
    var card: HotPotatoCard

    init(card: HotPotatoCard) {
        self.card = card
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw PotatoError.unknownPotato
        }
        card = try PotatoPayload.card(from: data)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: try PotatoPayload.data(from: card))
    }
}

enum PotatoShareDestination: Identifiable {
    case messages
    case airDrop
    case send
    case shareSheet

    var id: String {
        switch self {
        case .messages: "messages"
        case .airDrop: "airDrop"
        case .send: "send"
        case .shareSheet: "shareSheet"
        }
    }
}

struct SharePotatoView: UIViewControllerRepresentable {
    let card: HotPotatoCard
    var senderName: String
    var destination: PotatoShareDestination = .messages
    var shareTitle: String? = nil
    var shareText: String? = nil
    var recipients: [String] = []

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIViewController(context: Context) -> UIViewController {
        if destination != .shareSheet, destination == .messages || destination == .send, MFMessageComposeViewController.canSendText() {
            let composer = MFMessageComposeViewController()
            composer.messageComposeDelegate = context.coordinator
            if !recipients.isEmpty {
                composer.recipients = recipients
            }
            composer.body = card.status == .exploded
                ? (shareText ?? PotatoBrain.explodeRecap(card: card))
                : """
            🔥 HAWT POTATO
            \(senderName) threw this into the chat. First to open it catches it.
            \(card.deepLink.absoluteString)
            No app? \(card.webLink.absoluteString)
            """
            if let data = PotatoShareArtwork.image(for: card, senderName: senderName).pngData() {
                composer.addAttachmentData(data, typeIdentifier: UTType.png.identifier, filename: "HAWT-POTATO-\(card.shortCode).png")
            }
            return composer
        }

        let item = PotatoShareItem(
            card: card,
            senderName: senderName,
            destination: destination,
            shareTitle: shareTitle,
            shareText: shareText
        )
        let controller = UIActivityViewController(activityItems: [item], applicationActivities: nil)
        if destination == .airDrop {
            controller.excludedActivityTypes = [
                .message,
                .mail,
                .postToFacebook,
                .postToTwitter,
                .addToReadingList,
                .assignToContact,
                .print
            ]
        } else {
            controller.excludedActivityTypes = [.addToReadingList, .assignToContact, .print]
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    final class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
            controller.dismiss(animated: true)
        }
    }
}

final class PotatoShareItem: NSObject, UIActivityItemSource {
    let card: HotPotatoCard
    let senderName: String
    let destination: PotatoShareDestination
    let image: UIImage
    let fileURL: URL?
    let shareTitle: String
    let shareText: String?

    init(
        card: HotPotatoCard,
        senderName: String,
        destination: PotatoShareDestination,
        shareTitle: String? = nil,
        shareText: String? = nil
    ) {
        self.card = card
        self.senderName = senderName
        self.destination = destination
        self.image = PotatoShareArtwork.image(for: card, senderName: senderName)
        self.fileURL = try? PotatoPayload.writeTemporaryFile(for: card)
        self.shareTitle = shareTitle ?? "HAWT POTATO · \(card.callsign)"
        self.shareText = shareText
        super.init()
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        destination == .airDrop ? (fileURL ?? image) : image
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? {
        if activityType == .copyToPasteboard {
            return shareText ?? "\(shareTitle)\n\(card.deepLink.absoluteString)"
        }
        if activityType == .airDrop, let fileURL {
            return fileURL
        }
        return image
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        subjectForActivityType activityType: UIActivity.ActivityType?
    ) -> String {
        shareTitle
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        thumbnailImageForActivityType activityType: UIActivity.ActivityType?,
        suggestedSize size: CGSize
    ) -> UIImage? {
        BrandMark.icon(fitting: size)
    }

    func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.title = shareTitle
        metadata.originalURL = card.webLink
        metadata.url = card.deepLink
        let logo = BrandMark.icon(fitting: CGSize(width: 120, height: 120))
        metadata.iconProvider = NSItemProvider(object: logo)
        metadata.imageProvider = NSItemProvider(object: logo)
        return metadata
    }
}

enum BrandMark {
    static var image: UIImage {
        UIImage(named: "BrandLogo") ?? UIImage()
    }

    static func icon(fitting size: CGSize) -> UIImage {
        let source = image
        let side = max(80, min(max(size.width, size.height), 180))
        let canvas = CGSize(width: side, height: side)
        let renderer = UIGraphicsImageRenderer(size: canvas)
        return renderer.image { _ in
            source.draw(in: CGRect(origin: .zero, size: canvas))
        }
    }
}
