import AppKit
import Foundation

struct ClipboardRepresentation: Sendable {
  let type: String
  let data: Data
}

struct ClipboardItemSnapshot: Sendable {
  let representations: [ClipboardRepresentation]
}

struct ClipboardSnapshot: Sendable {
  let changeCount: Int
  let items: [ClipboardItemSnapshot]
}

struct ClipboardValue: Sendable {
  let text: String?
  let changeCount: Int
}

protocol ClipboardAccess: Sendable {
  func snapshot() async -> ClipboardSnapshot
  func stringValue() async -> ClipboardValue
  func restore(
    _ snapshot: ClipboardSnapshot,
    ifChangeCountIs expectedChangeCount: Int
  ) async
}

struct SystemClipboard: ClipboardAccess {
  func snapshot() async -> ClipboardSnapshot {
    await MainActor.run {
      let pasteboard = NSPasteboard.general
      let items = (pasteboard.pasteboardItems ?? []).map { item in
        let representations = item.types.compactMap { type in
          item.data(forType: type).map {
            ClipboardRepresentation(type: type.rawValue, data: $0)
          }
        }
        return ClipboardItemSnapshot(representations: representations)
      }
      return ClipboardSnapshot(
        changeCount: pasteboard.changeCount,
        items: items
      )
    }
  }

  func stringValue() async -> ClipboardValue {
    await MainActor.run {
      let pasteboard = NSPasteboard.general
      return ClipboardValue(
        text: pasteboard.string(forType: .string),
        changeCount: pasteboard.changeCount
      )
    }
  }

  func restore(
    _ snapshot: ClipboardSnapshot,
    ifChangeCountIs expectedChangeCount: Int
  ) async {
    await MainActor.run {
      let pasteboard = NSPasteboard.general
      guard pasteboard.changeCount == expectedChangeCount else { return }

      pasteboard.clearContents()
      let items = snapshot.items.map { snapshotItem in
        let item = NSPasteboardItem()
        for representation in snapshotItem.representations {
          item.setData(
            representation.data,
            forType: .init(rawValue: representation.type)
          )
        }
        return item
      }
      if !items.isEmpty {
        pasteboard.writeObjects(items)
      }
    }
  }
}
