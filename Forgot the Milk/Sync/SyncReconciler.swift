import Foundation
import SwiftData

@MainActor
struct SyncReconciler {
    let context: ModelContext
    let client: any CloudKitClient
    let defaults: UserDefaults
    let conflictPolicy: ConflictPolicy
    private let now: () -> Date

    init(
        context: ModelContext,
        client: any CloudKitClient,
        defaults: UserDefaults = .standard,
        conflictPolicy: ConflictPolicy = ConflictPolicy(),
        now: @escaping () -> Date = Date.init
    ) {
        self.context = context
        self.client = client
        self.defaults = defaults
        self.conflictPolicy = conflictPolicy
        self.now = now
    }

    func reconcile() async -> ReconcileReport {
        var report = ReconcileReport()
        var journal = SyncJournal.load(from: defaults)

        let auth = await client.authenticationStatus()
        guard auth == .authorized else {
            if auth == .restricted || auth == .unavailable {
                report.failure = .authentication
            }
            return report
        }

        let pull: SyncPullResult
        switch await client.fetchSyncRecords() {
        case .success(let result):
            pull = result
            report.sharedHouseholdListIDs = Set(
                pull.records
                    .filter { $0.shared && $0.record.type == .householdList }
                    .map(\.record.id)
            )
        case .failure(let error):
            report.failure = error.syncErrorKind
            return report
        }

        let households = Self.fetchAll(context, HouseholdList.self)
        let categories = Self.fetchAll(context, Category.self)
        let catalogItems = Self.fetchAll(context, CatalogItem.self)
        let listItems = Self.fetchAll(context, ListItem.self)
        let templates = Self.fetchAll(context, Template.self)

        var local: [UUID: SyncRecord] = [:]
        var householdsByID: [UUID: HouseholdList] = [:]
        var categoriesByID: [UUID: Category] = [:]
        var catalogItemsByID: [UUID: CatalogItem] = [:]
        var listItemsByID: [UUID: ListItem] = [:]
        var templatesByID: [UUID: Template] = [:]
        for household in households {
            householdsByID[household.id] = household
            local[household.id] = SyncRecord(householdList: household)
        }
        for category in categories {
            categoriesByID[category.id] = category
            local[category.id] = SyncRecord(category: category)
        }
        for item in catalogItems where item.scope == .household {
            if let record = SyncRecord(catalogItem: item) {
                catalogItemsByID[item.id] = item
                local[item.id] = record
            }
        }
        for listItem in listItems {
            listItemsByID[listItem.id] = listItem
            local[listItem.id] = SyncRecord(listItem: listItem)
        }
        for template in templates {
            templatesByID[template.id] = template
            local[template.id] = SyncRecord(template: template)
        }

        var remoteByID: [UUID: FetchedSyncRecord] = [:]
        for fetched in pull.records {
            remoteByID[fetched.record.id] = fetched
        }

        var pushes: [SyncRecord] = []
        var adoptions: [FetchedSyncRecord] = []
        var appliedDeletions = 0
        var rejected: [RejectedMutation] = []

        var entityIDs = Set(local.keys)
        entityIDs.formUnion(remoteByID.keys)

        for id in entityIDs {
            let localRecord = local[id]
            let fetched = remoteByID[id]
            let localVersion = journal.localVersions[id]
            let localIsDirty = localRecord.map { $0.updatedAt != localVersion } ?? false

            if localRecord == nil, journal.pendingDeletions[id] != nil {
                guard let fetched else { continue }
                if fetched.serverModifiedAt == journal.baselines[id] {
                    continue
                }
                journal.pendingDeletions.removeValue(forKey: id)
                rejected.append(RejectedMutation(
                    id: id,
                    entityType: fetched.record.type,
                    reason: .supersededByRemote,
                    rejectedAt: now(),
                    localRecord: fetched.record
                ))
            }

            if localRecord == nil, journal.pendingDeletions[id] == nil,
                let fetched,
                let baseline = journal.baselines[id],
                fetched.serverModifiedAt == baseline {
                journal.pendingDeletions[id] = fetched.record.type
                continue
            }

            if localRecord == fetched?.record {
                if let fetched {
                    journal.baselines[id] = fetched.serverModifiedAt
                }
                continue
            }

            let resolution = conflictPolicy.resolve(
                local: localRecord,
                localIsDirty: localIsDirty,
                baseline: journal.baselines[id],
                remote: fetched.map { RemoteRecord(record: $0.record, serverModifiedAt: $0.serverModifiedAt) }
            )
            switch resolution.outcome {
            case .noChange:
                break
            case .pushLocal:
                if let localRecord {
                    pushes.append(localRecord)
                }
            case .adoptRemote:
                guard let fetched else { continue }
                adoptions.append(fetched)
                journal.baselines[id] = fetched.serverModifiedAt
                journal.localVersions[id] = fetched.record.updatedAt
                if resolution.rejectedLocal, let localRecord {
                    rejected.append(RejectedMutation(
                        id: id,
                        entityType: localRecord.type,
                        reason: .supersededByRemote,
                        rejectedAt: now(),
                        localRecord: localRecord
                    ))
                }
            }
        }

        for deletion in pull.deletions {
            let id = deletion.entityID
            if let localRecord = local[id] {
                let localIsDirty = localRecord.updatedAt != journal.localVersions[id]
                if localIsDirty {
                    rejected.append(RejectedMutation(
                        id: id,
                        entityType: localRecord.type,
                        reason: .supersededByRemote,
                        rejectedAt: now(),
                        localRecord: localRecord
                    ))
                }
                appliedDeletions += 1
            }
            if journal.pendingDeletions[id] != nil {
                journal.pendingDeletions.removeValue(forKey: id)
            }
            Self.applyDeletion(deletion, households: householdsByID, categories: categoriesByID, catalogItems: catalogItemsByID, listItems: listItemsByID, templates: templatesByID, context: context)
            householdsByID.removeValue(forKey: id)
            categoriesByID.removeValue(forKey: id)
            catalogItemsByID.removeValue(forKey: id)
            listItemsByID.removeValue(forKey: id)
            templatesByID.removeValue(forKey: id)
            journal.baselines.removeValue(forKey: id)
            journal.localVersions.removeValue(forKey: id)
        }
        let deletedIDs = Set(pull.deletions.map(\.entityID))
        pushes.removeAll { deletedIDs.contains($0.id) }

        for fetched in adoptions where journal.pendingDeletions[fetched.record.id] != nil {
            rejected.append(RejectedMutation(
                id: fetched.record.id,
                entityType: fetched.record.type,
                reason: .supersededByRemote,
                rejectedAt: now(),
                localRecord: fetched.record
            ))
            journal.pendingDeletions.removeValue(forKey: fetched.record.id)
        }

        Self.applyAdoptions(
            adoptions,
            households: householdsByID,
            categories: categoriesByID,
            catalogItems: catalogItemsByID,
            listItems: listItemsByID,
            templates: templatesByID,
            context: context
        )
        if context.hasChanges {
            try? context.save()
        }

        report.pulledCount = adoptions.count + appliedDeletions

        var unpushedDeletions = journal.pendingDeletions.count
        if !journal.pendingDeletions.isEmpty {
            let requests = journal.pendingDeletions
                .map { SyncDeleteRequest(entityType: $0.value, entityID: $0.key) }
                .sorted {
                    ($0.entityType.rawValue, $0.entityID.uuidString) < ($1.entityType.rawValue, $1.entityID.uuidString)
                }
            switch await client.deleteRecords(requests) {
            case .success(let acceptedIDs):
                for id in acceptedIDs where journal.pendingDeletions[id] != nil {
                    journal.pendingDeletions.removeValue(forKey: id)
                }
                unpushedDeletions = journal.pendingDeletions.count
            case .failure(let error):
                report.failure = error.syncErrorKind
                unpushedDeletions = journal.pendingDeletions.count
            }
        }

        pushes.sort {
            ($0.type.rawValue, $0.updatedAt.timeIntervalSinceReferenceDate, $0.id.uuidString)
                < ($1.type.rawValue, $1.updatedAt.timeIntervalSinceReferenceDate, $1.id.uuidString)
        }

        var unpushedUpserts = 0
        if !pushes.isEmpty {
            switch await client.saveRecords(pushes) {
            case .success(let result):
                for outcome in result.outcomes {
                    guard outcome.accepted, let stamp = outcome.serverModifiedAt else { continue }
                    journal.baselines[outcome.entityID] = stamp
                    if let record = pushes.first(where: { $0.id == outcome.entityID }) {
                        journal.localVersions[outcome.entityID] = record.updatedAt
                    }
                }
                unpushedUpserts = result.rejectedIDs.count
                report.pushedCount = result.acceptedIDs.count
                if !result.rejectedIDs.isEmpty {
                    report.failure = .partialFailure
                }
            case .failure(let error):
                unpushedUpserts = pushes.count
                report.failure = error.syncErrorKind
            }
        }

        report.rejectedCount = rejected.count
        report.remainingPendingCount = unpushedUpserts + unpushedDeletions
        report.syncedAt = report.failure == nil ? now() : nil
        journal.persist(to: defaults)

        return report
    }

    private static func fetchAll<T: PersistentModel>(_ context: ModelContext, _ type: T.Type) -> [T] {
        let descriptor = FetchDescriptor<T>()
        return (try? context.fetch(descriptor)) ?? []
    }

    private static func applyAdoptions(
        _ adoptions: [FetchedSyncRecord],
        households: [UUID: HouseholdList],
        categories: [UUID: Category],
        catalogItems: [UUID: CatalogItem],
        listItems: [UUID: ListItem],
        templates: [UUID: Template],
        context: ModelContext
    ) {
        for fetched in adoptions {
            let record = fetched.record
            switch record {
            case .householdList(let payload):
                if let model = households[payload.id] {
                    record.apply(to: model)
                } else {
                    let model = HouseholdList(id: payload.id, title: payload.title)
                    context.insert(model)
                    record.apply(to: model)
                }
            case .category(let payload):
                if let model = categories[payload.id] {
                    record.apply(to: model)
                } else {
                    let model = Category(id: payload.id, name: payload.name, defaultOrder: payload.defaultOrder)
                    context.insert(model)
                    record.apply(to: model)
                }
            case .catalogItem(let payload):
                if let model = catalogItems[payload.id] {
                    record.apply(to: model)
                } else {
                    let model = CatalogItem(id: payload.id, name: payload.name, categoryID: payload.categoryID)
                    context.insert(model)
                    record.apply(to: model)
                }
            case .listItem(let payload):
                if let model = listItems[payload.id] {
                    record.apply(to: model)
                } else {
                    let model = ListItem(id: payload.id, listID: payload.listID, name: payload.name, categoryID: payload.categoryID, sortOrder: payload.sortOrder)
                    context.insert(model)
                    record.apply(to: model)
                }
            case .template(let payload):
                if let model = templates[payload.id] {
                    record.apply(to: model)
                } else {
                    let model = Template(id: payload.id, listID: payload.listID, name: payload.name)
                    context.insert(model)
                    record.apply(to: model)
                }
            }
        }
    }

    private static func applyDeletion(
        _ deletion: SyncDeletion,
        households: [UUID: HouseholdList],
        categories: [UUID: Category],
        catalogItems: [UUID: CatalogItem],
        listItems: [UUID: ListItem],
        templates: [UUID: Template],
        context: ModelContext
    ) {
        switch deletion.entityType {
        case .householdList:
            if let model = households[deletion.entityID] { context.delete(model) }
        case .category:
            if let model = categories[deletion.entityID] { context.delete(model) }
        case .catalogItem:
            if let model = catalogItems[deletion.entityID] { context.delete(model) }
        case .listItem:
            if let model = listItems[deletion.entityID] { context.delete(model) }
        case .template:
            if let model = templates[deletion.entityID] { context.delete(model) }
        }
    }
}

private extension CloudKitClientError {
    var syncErrorKind: SyncErrorKind {
        switch self {
        case .notAuthenticated, .authenticationRestricted:
            return .authentication
        case .networkUnavailable:
            return .network
        case .permissionDenied:
            return .permissionDenied
        case .quotaExceeded:
            return .quota
        case .conflict:
            return .conflict
        case .containerUnavailable, .unknown:
            return .unknown
        }
    }
}
