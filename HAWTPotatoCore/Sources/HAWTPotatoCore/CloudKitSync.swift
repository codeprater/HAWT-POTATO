#if canImport(CloudKit)
import CloudKit
import Foundation

public actor CloudKitPotatoService {
    private let container: CKContainer
    private let database: CKDatabase
    private let recordType = "HotPotato"

    public init(identifier: String = ProductCanon.cloudKitContainer) {
        container = CKContainer(identifier: identifier)
        database = container.publicCloudDatabase
    }

    public func currentUserRecordName() async -> String? {
        (try? await container.userRecordID())?.recordName
    }

    public func save(_ card: HotPotatoCard) async throws {
        let recordID = CKRecord.ID(recordName: card.id.uuidString)
        let record = CKRecord(recordType: recordType, recordID: recordID)
        record["passGeneration"] = card.passGeneration as CKRecordValue
        record["status"] = card.status.rawValue as CKRecordValue
        record["holderID"] = card.currentHolder.id as CKRecordValue
        record["expiresAt"] = card.expiresAt as CKRecordValue
        if let mustThrowBy = card.mustThrowBy {
            record["mustThrowBy"] = mustThrowBy as CKRecordValue
        } else {
            record["mustThrowBy"] = nil
        }
        record["payload"] = try PotatoPayload.data(from: card) as CKRecordValue

        let outcome = try await database.modifyRecords(
            saving: [record],
            deleting: [],
            savePolicy: .allKeys,
            atomically: true
        )
        if case .failure(let error)? = outcome.saveResults[recordID] {
            throw error
        }
    }

    public func delete(id: UUID) async throws {
        let recordID = CKRecord.ID(recordName: id.uuidString)
        _ = try await database.deleteRecord(withID: recordID)
    }

    public func fetch(id: UUID) async throws -> HotPotatoCard? {
        let recordID = CKRecord.ID(recordName: id.uuidString)
        guard let record = try? await database.record(for: recordID),
              let data = record["payload"] as? Data else { return nil }
        return try PotatoPayload.card(from: data)
    }

    public func fetchActive(for playerID: String) async throws -> [HotPotatoCard] {
        let predicate = NSPredicate(format: "holderID == %@", playerID)
        let query = CKQuery(recordType: recordType, predicate: predicate)
        let result = try await database.records(matching: query)
        return result.matchResults.compactMap { _, result in
            guard let record = try? result.get(),
                  let data = record["payload"] as? Data else { return nil }
            return try? PotatoPayload.card(from: data)
        }
    }
}
#endif
