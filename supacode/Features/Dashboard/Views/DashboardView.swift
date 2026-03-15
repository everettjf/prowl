import SwiftUI

struct DashboardView: View {
  let terminalManager: WorktreeTerminalManager
  @State private var layoutStore = DashboardLayoutStore()

  @State private var canvasOffset: CGSize = .zero
  @State private var canvasScale: CGFloat = 1.0
  @State private var focusedWorktreeID: Worktree.ID?
  @State private var dragOffset: [Worktree.ID: CGSize] = [:]
  @State private var resizeDelta: [Worktree.ID: CGSize] = [:]

  private let minCardSize = CGSize(width: 300, height: 200)
  private let maxCardSize = CGSize(width: 1200, height: 900)
  private let titleBarHeight: CGFloat = 28

  var body: some View {
    GeometryReader { geometry in
      let activeStates = terminalManager.activeWorktreeStates
      ZStack {
        canvasBackground
        ForEach(activeStates, id: \.worktreeID) { state in
          if let surfaceView = state.activeSurfaceView {
            let layout = effectiveLayout(for: state.worktreeID, canvasSize: geometry.size)
            DashboardCardView(
              repositoryName: Repository.name(for: state.repositoryRootURL),
              worktreeName: state.worktreeName,
              surfaceView: surfaceView,
              isFocused: focusedWorktreeID == state.worktreeID,
              hasUnseenNotification: state.hasUnseenNotification,
              cardSize: effectiveCardSize(for: state.worktreeID, baseSize: layout.size),
              onTap: { focusCard(state.worktreeID, states: activeStates) },
              onDragPosition: { translation in dragOffset[state.worktreeID] = translation },
              onDragPositionEnd: { commitDragPosition(for: state.worktreeID) },
              onResizeEdge: { edge, translation in
                handleResizeEdge(edge, translation: translation, for: state.worktreeID)
              },
              onResizeEdgeEnd: { commitResize(for: state.worktreeID, surfaceView: surfaceView) }
            )
            .position(effectivePosition(for: state.worktreeID, basePosition: layout.position))
            .zIndex(focusedWorktreeID == state.worktreeID ? 1 : 0)
          }
        }
      }
      .scaleEffect(canvasScale)
      .offset(canvasOffset)
      .gesture(canvasPanGesture)
      .gesture(canvasZoomGesture)
    }
    .onAppear { enableSurfaceOcclusion() }
    .onDisappear { disableSurfaceOcclusion() }
  }

  // MARK: - Canvas Background

  private var canvasBackground: some View {
    Color.clear
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .contentShape(.rect)
      .accessibilityAddTraits(.isButton)
      .onTapGesture { unfocusAll() }
  }

  // MARK: - Canvas Gestures

  @State private var lastCanvasOffset: CGSize = .zero

  private var canvasPanGesture: some Gesture {
    DragGesture()
      .onChanged { value in
        canvasOffset = CGSize(
          width: lastCanvasOffset.width + value.translation.width,
          height: lastCanvasOffset.height + value.translation.height
        )
      }
      .onEnded { _ in
        lastCanvasOffset = canvasOffset
      }
  }

  private var canvasZoomGesture: some Gesture {
    MagnifyGesture()
      .onChanged { value in
        canvasScale = max(0.25, min(2.0, value.magnification))
      }
  }

  // MARK: - Layout Calculation

  private func effectiveLayout(for worktreeID: Worktree.ID, canvasSize: CGSize) -> DashboardCardLayout {
    if let existing = layoutStore.cardLayouts[worktreeID] {
      return existing
    }
    let position = autoPosition(for: worktreeID, canvasSize: canvasSize)
    let layout = DashboardCardLayout(position: position)
    layoutStore.cardLayouts[worktreeID] = layout
    return layout
  }

  private func autoPosition(for worktreeID: Worktree.ID, canvasSize: CGSize) -> CGPoint {
    let existingCount = layoutStore.cardLayouts.count
    let columns = max(1, Int(canvasSize.width / (DashboardCardLayout.defaultSize.width + 20)))
    let row = existingCount / columns
    let col = existingCount % columns
    let spacing: CGFloat = 20
    let totalCardWidth = DashboardCardLayout.defaultSize.width + spacing
    let totalCardHeight = DashboardCardLayout.defaultSize.height + titleBarHeight + spacing
    return CGPoint(
      x: spacing + totalCardWidth * CGFloat(col) + DashboardCardLayout.defaultSize.width / 2,
      y: spacing + totalCardHeight * CGFloat(row) + (DashboardCardLayout.defaultSize.height + titleBarHeight) / 2
    )
  }

  private func effectivePosition(for worktreeID: Worktree.ID, basePosition: CGPoint) -> CGPoint {
    let drag = dragOffset[worktreeID] ?? .zero
    return CGPoint(x: basePosition.x + drag.width, y: basePosition.y + drag.height)
  }

  private func effectiveCardSize(for worktreeID: Worktree.ID, baseSize: CGSize) -> CGSize {
    let delta = resizeDelta[worktreeID] ?? .zero
    return CGSize(
      width: max(minCardSize.width, min(maxCardSize.width, baseSize.width + delta.width)),
      height: max(minCardSize.height, min(maxCardSize.height, baseSize.height + delta.height))
    )
  }

  // MARK: - Drag Position

  private func commitDragPosition(for worktreeID: Worktree.ID) {
    guard let drag = dragOffset[worktreeID] else { return }
    if var layout = layoutStore.cardLayouts[worktreeID] {
      layout.position.x += drag.width
      layout.position.y += drag.height
      layoutStore.cardLayouts[worktreeID] = layout
    }
    dragOffset[worktreeID] = nil
  }

  // MARK: - Resize

  private func handleResizeEdge(
    _ edge: DashboardCardView.CardEdge,
    translation: CGSize,
    for worktreeID: Worktree.ID
  ) {
    switch edge {
    case .trailing:
      resizeDelta[worktreeID] = CGSize(width: translation.width, height: 0)
    case .leading:
      resizeDelta[worktreeID] = CGSize(width: -translation.width, height: 0)
    case .bottom:
      resizeDelta[worktreeID] = CGSize(width: 0, height: translation.height)
    }
  }

  private func commitResize(for worktreeID: Worktree.ID, surfaceView: GhosttySurfaceView) {
    guard let delta = resizeDelta[worktreeID] else { return }
    if var layout = layoutStore.cardLayouts[worktreeID] {
      let newSize = CGSize(
        width: max(minCardSize.width, min(maxCardSize.width, layout.size.width + delta.width)),
        height: max(minCardSize.height, min(maxCardSize.height, layout.size.height + delta.height)),
      )
      layout.size = newSize
      layoutStore.cardLayouts[worktreeID] = layout
    }
    resizeDelta[worktreeID] = nil
    surfaceView.needsLayout = true
    surfaceView.needsDisplay = true
  }

  // MARK: - Focus Management

  private func focusCard(_ worktreeID: Worktree.ID, states: [WorktreeTerminalState]) {
    let previousID = focusedWorktreeID
    focusedWorktreeID = worktreeID

    if let previousID, previousID != worktreeID {
      if let previousState = states.first(where: { $0.worktreeID == previousID }),
        let previousSurface = previousState.activeSurfaceView
      {
        previousSurface.focusDidChange(false)
      }
    }

    if let currentState = states.first(where: { $0.worktreeID == worktreeID }),
      let currentSurface = currentState.activeSurfaceView
    {
      currentSurface.focusDidChange(true)
      currentSurface.requestFocus()
    }
  }

  private func unfocusAll() {
    guard let previousID = focusedWorktreeID else { return }
    focusedWorktreeID = nil
    let states = terminalManager.activeWorktreeStates
    if let state = states.first(where: { $0.worktreeID == previousID }),
      let surface = state.activeSurfaceView
    {
      surface.focusDidChange(false)
    }
  }

  // MARK: - Occlusion

  private func enableSurfaceOcclusion() {
    for state in terminalManager.activeWorktreeStates {
      if let surfaceView = state.activeSurfaceView {
        surfaceView.setOcclusion(true)
      }
    }
  }

  private func disableSurfaceOcclusion() {
    for state in terminalManager.activeWorktreeStates {
      if let surfaceView = state.activeSurfaceView {
        surfaceView.setOcclusion(false)
        surfaceView.focusDidChange(false)
      }
    }
  }
}
