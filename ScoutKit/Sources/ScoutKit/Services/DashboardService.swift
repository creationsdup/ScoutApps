import Foundation

/// Instantané agrégé du tableau de bord ScoutMatériel (lecture seule).
public struct DashboardSnapshot {
    public var total = 0
    public var available = 0
    public var checkedOut = 0
    public var toRepair = 0
    public var alerts: [DashboardAlert] = []
    public var ongoingCheckouts: [OngoingCheckout] = []
    public var ongoingCamps: [OngoingCamp] = []
    public init() {}
}

/// Une alerte du tableau de bord : un type + les objets concernés.
public struct DashboardAlert: Identifiable {
    public enum Kind: String, CaseIterable {
        case checkedOutOver7d, toRepair, missingQR, missingPhoto, lowStock, toVerify
        public var label: String {
            switch self {
            case .checkedOutOver7d: return "Sortis depuis +7 jours"
            case .toRepair:         return "À réparer"
            case .missingQR:        return "Sans QR code"
            case .missingPhoto:     return "Sans photo"
            case .lowStock:         return "Stock faible"
            case .toVerify:         return "À vérifier"
            }
        }
        public var systemImage: String {
            switch self {
            case .checkedOutOver7d: return "calendar.badge.exclamationmark"
            case .toRepair:         return "wrench.adjustable"
            case .missingQR:        return "qrcode"
            case .missingPhoto:     return "photo"
            case .lowStock:         return "exclamationmark.triangle.fill"
            case .toVerify:         return "sparkles"
            }
        }
    }
    public let kind: Kind
    public let items: [Item]
    public var id: String { kind.rawValue }
    public init(kind: Kind, items: [Item]) {
        self.kind = kind
        self.items = items
    }
}

/// Un bon de sortie ouvert et son avancement de retour.
public struct OngoingCheckout: Identifiable {
    public let checkout: Checkout
    public let totalItems: Int
    public let returnedItems: Int
    public var id: String { checkout.id }
    public var returnRate: Double { totalItems == 0 ? 0 : Double(returnedItems) / Double(totalItems) }
    public init(checkout: Checkout, totalItems: Int, returnedItems: Int) {
        self.checkout = checkout
        self.totalItems = totalItems
        self.returnedItems = returnedItems
    }
}

/// Un camp détenant du matériel (pont ScoutCamp -> ScoutMatériel).
public struct OngoingCamp: Identifiable {
    public let camp: Camp
    public let items: [Item]
    public var id: String { camp.id }
    public var itemCount: Int { items.count }
    public init(camp: Camp, items: [Item]) {
        self.camp = camp
        self.items = items
    }
}

/// Agrège les données existantes pour le tableau de bord. Lecture seule.
public struct DashboardService {
    public init() {}

    public func loadSnapshot() async throws -> DashboardSnapshot {
        let items = try await ItemService().list(includeArchived: false)

        var snap = DashboardSnapshot()
        snap.total = items.count
        snap.available = items.filter { $0.status == .disponible }.count
        snap.checkedOut = items.filter { $0.status == .sorti }.count
        snap.toRepair = items.filter { $0.status == .aReparer }.count

        // Bons de sortie ouverts + objets sortis depuis +7 jours.
        let checkoutService = CheckoutService()
        let openCheckouts = try await checkoutService.list().filter { $0.status == .open }
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        var ongoingCheckouts: [OngoingCheckout] = []
        var over7d: [Item] = []
        for co in openCheckouts {
            let lines = try await checkoutService.lines(checkoutId: co.id)
            let total = lines.reduce(0) { $0 + $1.quantity }
            let returned = lines.reduce(0) { $0 + $1.quantityReturned }
            ongoingCheckouts.append(OngoingCheckout(checkout: co, totalItems: total, returnedItems: returned))
            if let createdAt = co.createdAt,
               let day = SGDFDate.day(from: String(createdAt.prefix(10))),
               day < cutoff {
                for line in lines where line.remaining > 0 { over7d.append(line.item) }
            }
        }
        var seen = Set<String>()
        let over7dUnique = over7d.filter { seen.insert($0.id).inserted }

        // Camps détenant du matériel (ScoutCamp).
        let campMaterial = CampMaterialService()
        var ongoingCamps: [OngoingCamp] = []
        for camp in try await CampService().list() {
            let campItems = try await campMaterial.items(campId: camp.id)
            if !campItems.isEmpty { ongoingCamps.append(OngoingCamp(camp: camp, items: campItems)) }
        }

        // Alertes (uniquement celles non vides), dans l'ordre d'affichage.
        var alerts: [DashboardAlert] = []
        func add(_ kind: DashboardAlert.Kind, _ list: [Item]) {
            if !list.isEmpty { alerts.append(DashboardAlert(kind: kind, items: list)) }
        }
        add(.checkedOutOver7d, over7dUnique)
        add(.toRepair, items.filter { $0.status == .aReparer })
        add(.missingPhoto, items.filter { $0.imagePath == nil })
        add(.lowStock, items.filter { $0.isLowStock })
        add(.toVerify, items.filter { $0.status == .aVerifier })

        snap.alerts = alerts
        snap.ongoingCheckouts = ongoingCheckouts
        snap.ongoingCamps = ongoingCamps
        return snap
    }
}
