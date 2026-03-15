import ComposableArchitecture
import SwiftUI

struct DashboardSidebarButton: View {
  let store: StoreOf<RepositoriesFeature>
  let isSelected: Bool

  var body: some View {
    Button {
      store.send(.selectDashboard)
    } label: {
      Label("Dashboard", systemImage: "square.grid.2x2")
        .font(.callout)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .buttonStyle(.plain)
    .padding(.horizontal, 12)
    .padding(.vertical, 6)
    .background(isSelected ? Color.accentColor.opacity(0.15) : .clear, in: .rect(cornerRadius: 6))
    .help("Dashboard")
  }
}
