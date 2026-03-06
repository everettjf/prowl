import AppKit
import SwiftUI

@MainActor
final class DiffWindowManager {
  static let shared = DiffWindowManager()

  let state = DiffWindowState()
  private var window: NSWindow?
  private var skipNextFocusRefresh = false

  private init() {}

  func show(worktreeURL: URL, branchName: String) {
    state.load(worktreeURL: worktreeURL, branchName: branchName)
    skipNextFocusRefresh = true

    if let existingWindow = window {
      existingWindow.title = windowTitle(branchName: branchName)
      if existingWindow.isMiniaturized {
        existingWindow.deminiaturize(nil)
      }
      existingWindow.makeKeyAndOrderFront(nil)
      return
    }

    let contentView = DiffWindowContentView(state: state)
    let hostingController = NSHostingController(rootView: contentView)

    let newWindow = NSWindow(contentViewController: hostingController)
    newWindow.title = windowTitle(branchName: branchName)
    newWindow.identifier = NSUserInterfaceItemIdentifier("diff")
    newWindow.styleMask = [.titled, .closable, .miniaturizable, .resizable]
    newWindow.tabbingMode = .disallowed
    newWindow.isReleasedWhenClosed = false
    newWindow.setContentSize(NSSize(width: 1000, height: 700))
    newWindow.minSize = NSSize(width: 600, height: 400)
    newWindow.center()
    newWindow.makeKeyAndOrderFront(nil)

    window = newWindow

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(windowDidBecomeKey),
      name: NSWindow.didBecomeKeyNotification,
      object: newWindow,
    )
  }

  var hasChanges: Bool {
    !state.changedFiles.isEmpty || state.isLoadingFiles
  }

  private func windowTitle(branchName: String) -> String {
    "Changes — \(branchName)"
  }

  @objc private func windowDidBecomeKey(_ notification: Notification) {
    if skipNextFocusRefresh {
      skipNextFocusRefresh = false
      return
    }
    state.refresh()
  }
}
