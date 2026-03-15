enum SidebarSelection: Hashable {
  case worktree(Worktree.ID)
  case archivedWorktrees
  case repository(Repository.ID)
  case dashboard

  var worktreeID: Worktree.ID? {
    switch self {
    case .worktree(let id):
      return id
    case .archivedWorktrees, .repository, .dashboard:
      return nil
    }
  }
}
