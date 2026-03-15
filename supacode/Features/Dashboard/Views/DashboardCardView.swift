import AppKit
import SwiftUI

struct DashboardCardView: View {
  let repositoryName: String
  let worktreeName: String
  let surfaceView: GhosttySurfaceView
  let isFocused: Bool
  let hasUnseenNotification: Bool
  let cardSize: CGSize
  let onTap: () -> Void
  let onDragPosition: (CGSize) -> Void
  let onDragPositionEnd: () -> Void
  let onResizeEdge: (CardEdge, CGSize) -> Void
  let onResizeEdgeEnd: () -> Void

  enum CardEdge {
    case leading, trailing, bottom
  }

  private let titleBarHeight: CGFloat = 28
  private let resizeHandleThickness: CGFloat = 6
  private let cornerRadius: CGFloat = 8

  var body: some View {
    VStack(spacing: 0) {
      titleBar
      terminalContent
    }
    .frame(width: cardSize.width, height: cardSize.height + titleBarHeight)
    .clipShape(.rect(cornerRadius: cornerRadius))
    .overlay {
      RoundedRectangle(cornerRadius: cornerRadius)
        .stroke(isFocused ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: isFocused ? 2 : 1)
    }
    .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
    .overlay { resizeHandles }
    .contentShape(.rect)
    .accessibilityAddTraits(.isButton)
    .onTapGesture { onTap() }
  }

  private var titleBar: some View {
    HStack(spacing: 6) {
      if hasUnseenNotification {
        Circle()
          .fill(Color.orange)
          .frame(width: 6, height: 6)
      }
      Text(repositoryName)
        .font(.caption.bold())
        .lineLimit(1)
      Text("/ \(worktreeName)")
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(1)
      Spacer()
    }
    .padding(.horizontal, 8)
    .frame(height: titleBarHeight)
    .frame(maxWidth: .infinity)
    .background(.bar)
    .gesture(
      DragGesture()
        .onChanged { value in
          onDragPosition(value.translation)
        }
        .onEnded { _ in
          onDragPositionEnd()
        }
    )
  }

  private var terminalContent: some View {
    GhosttyTerminalView(surfaceView: surfaceView)
      .frame(width: cardSize.width, height: cardSize.height)
      .allowsHitTesting(isFocused)
  }

  private var resizeHandles: some View {
    ZStack {
      ResizeHandle(cursor: .resizeLeftRight, alignment: .leading) { translation in
        onResizeEdge(.leading, translation)
      } onEnd: {
        onResizeEdgeEnd()
      }

      ResizeHandle(cursor: .resizeLeftRight, alignment: .trailing) { translation in
        onResizeEdge(.trailing, translation)
      } onEnd: {
        onResizeEdgeEnd()
      }

      ResizeHandle(cursor: .resizeUpDown, alignment: .bottom) { translation in
        onResizeEdge(.bottom, translation)
      } onEnd: {
        onResizeEdgeEnd()
      }
    }
  }
}

private struct ResizeHandle: View {
  let cursor: NSCursor
  let alignment: Alignment
  let onChange: (CGSize) -> Void
  let onEnd: () -> Void

  @State private var isHovered = false

  private let thickness: CGFloat = 6

  var body: some View {
    let isVerticalEdge = alignment == .leading || alignment == .trailing
    Color.clear
      .frame(
        width: isVerticalEdge ? thickness : nil,
        height: isVerticalEdge ? nil : thickness
      )
      .frame(
        maxWidth: isVerticalEdge ? nil : .infinity,
        maxHeight: isVerticalEdge ? .infinity : nil
      )
      .contentShape(.rect)
      .onHover { hovering in
        guard hovering != isHovered else { return }
        isHovered = hovering
        if hovering {
          cursor.push()
        } else {
          NSCursor.pop()
        }
      }
      .onDisappear {
        if isHovered {
          isHovered = false
          NSCursor.pop()
        }
      }
      .gesture(
        DragGesture()
          .onChanged { value in onChange(value.translation) }
          .onEnded { _ in onEnd() }
      )
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
  }
}
