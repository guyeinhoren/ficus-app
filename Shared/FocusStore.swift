//
//  FocusStore.swift
//  Persistent model shared by every target, designed to sync through CloudKit.
//
//  Storage is one tiny row per planted tree (a few integers, no blobs):
//   - rows are append-mostly, so two devices planting at the same time never overwrite each other;
//   - every attribute has a default and nothing is unique, as CloudKit requires.
//

import CoreGraphics
import Foundation
import SwiftData

@Model
final class Tree {
    /// Local calendar day, see `Day`.
    var day: Int32 = 0
    /// Planting order within the day.
    var slot: Int16 = 0
    /// Offset from the island's center, in points.
    var x: Int16 = 0
    var y: Int16 = 0
    /// Index into the tree catalog; 0 is the oak.
    var species: Int16 = 0

    init(day: Int32, slot: Int, position: CGPoint, species: Int = 0) {
        self.day = day
        self.slot = Int16(clamping: slot)
        self.species = Int16(clamping: species)
        self.x = Int16(clamping: Int(position.x.rounded()))
        self.y = Int16(clamping: Int(position.y.rounded()))
    }

    var position: CGPoint {
        get { CGPoint(x: Double(x), y: Double(y)) }
        set {
            x = Int16(clamping: Int(newValue.x.rounded()))
            y = Int16(clamping: Int(newValue.y.rounded()))
        }
    }
}

/// Days are stored as the number of the day within the era in the user's calendar.
nonisolated enum Day {
    static var today: Int32 { stamp(of: .now) }

    static func stamp(of date: Date) -> Int32 {
        Int32(Calendar.current.ordinality(of: .day, in: .era, for: date) ?? 0)
    }

    static func date(of stamp: Int32) -> Date {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: .now)
        return calendar.date(byAdding: .day, value: Int(stamp - today), to: startOfToday) ?? startOfToday
    }
}

enum FocusStore {
    static let appGroup = "group.focal.ficus"

    /// Builds the container inside the app group (so extensions and a future macOS app can read it)
    /// and mirrors it to the user's private iCloud database.
    static func makeContainer() -> ModelContainer {
        let schema = Schema([Tree.self])
        let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
        let url = (groupURL ?? .applicationSupportDirectory).appending(path: "Ficus.store")

        let cloud = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .automatic)
        if let container = try? ModelContainer(for: schema, configurations: cloud) {
            return container
        }
        // iCloud unavailable (e.g. capability not provisioned): keep working locally.
        let local = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        do {
            return try ModelContainer(for: schema, configurations: local)
        } catch {
            fatalError("Unable to open the tree store: \(error)")
        }
    }
}
