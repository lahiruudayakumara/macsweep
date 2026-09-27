import Foundation

/// Represents a mounted disk volume (internal or external).
public struct ExternalVolume: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let name: String
    public let url: URL
    public let totalCapacity: Int64
    public let availableCapacity: Int64
    public let isRemovable: Bool
    public let isExternal: Bool
    public let isReadOnly: Bool
    public let volumeUUID: String

    public var usedCapacity: Int64 { totalCapacity - availableCapacity }

    public var usedPercentage: Double {
        guard totalCapacity > 0 else { return 0 }
        return Double(usedCapacity) / Double(totalCapacity)
    }

    public var formattedTotal: String { ByteFormatter.format(totalCapacity) }
    public var formattedAvailable: String { ByteFormatter.format(availableCapacity) }
    public var formattedUsed: String { ByteFormatter.format(usedCapacity) }

    public init(
        id: UUID = UUID(),
        name: String,
        url: URL,
        totalCapacity: Int64,
        availableCapacity: Int64,
        isRemovable: Bool,
        isExternal: Bool,
        isReadOnly: Bool = false,
        volumeUUID: String = ""
    ) {
        self.id = id
        self.name = name
        self.url = url
        self.totalCapacity = totalCapacity
        self.availableCapacity = availableCapacity
        self.isRemovable = isRemovable
        self.isExternal = isExternal
        self.isReadOnly = isReadOnly
        self.volumeUUID = volumeUUID
    }

    public func hash(into hasher: inout Hasher) { hasher.combine(id) }
    public static func == (lhs: ExternalVolume, rhs: ExternalVolume) -> Bool { lhs.id == rhs.id }
}
