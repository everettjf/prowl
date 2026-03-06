import Foundation
import YiTong

@Observable
@MainActor
final class DiffWindowState {
  var worktreeURL: URL?
  var branchName: String = ""
  var changedFiles: [DiffChangedFile] = []
  var selectedFile: DiffChangedFile?
  var diffDocument: DiffDocument?
  var isLoadingFiles = false
  var isLoadingDiff = false

  private let gitClient = GitClient()

  func load(worktreeURL: URL, branchName: String) {
    self.worktreeURL = worktreeURL
    self.branchName = branchName
    changedFiles = []
    selectedFile = nil
    diffDocument = nil
    Task { await loadChangedFiles() }
  }

  func refresh() {
    guard worktreeURL != nil else { return }
    Task { await loadChangedFiles() }
  }

  func selectFile(_ file: DiffChangedFile) {
    guard selectedFile != file else { return }
    selectedFile = file
    diffDocument = nil
    Task { await loadDiffForSelectedFile() }
  }

  // MARK: - Private

  private func loadChangedFiles() async {
    guard let worktreeURL else { return }
    isLoadingFiles = true
    async let trackedOutput = gitClient.diffNameStatus(at: worktreeURL)
    async let untrackedPaths = gitClient.untrackedFilePaths(at: worktreeURL)
    let trackedFiles = DiffChangedFile.parseNameStatus(await trackedOutput)
    let untrackedFiles = await untrackedPaths.map {
      DiffChangedFile(status: .added, oldPath: nil, newPath: $0)
    }
    let files = trackedFiles + untrackedFiles
    changedFiles = files
    isLoadingFiles = false

    if let selectedFile, files.contains(selectedFile) {
      await loadDiffForSelectedFile()
    } else if let first = files.first {
      selectedFile = first
      await loadDiffForSelectedFile()
    } else {
      selectedFile = nil
      diffDocument = nil
    }
  }

  private func loadDiffForSelectedFile() async {
    guard let worktreeURL, let file = selectedFile else {
      diffDocument = nil
      return
    }
    isLoadingDiff = true

    let oldContents: String
    let newContents: String

    switch file.status {
    case .added:
      oldContents = ""
      newContents = await readWorkingFile(file.displayPath, in: worktreeURL)
    case .deleted:
      oldContents = await gitClient.showFileAtHEAD(file.oldPath ?? "", in: worktreeURL) ?? ""
      newContents = ""
    case .renamed:
      oldContents = await gitClient.showFileAtHEAD(file.oldPath ?? "", in: worktreeURL) ?? ""
      newContents = await readWorkingFile(file.newPath ?? "", in: worktreeURL)
    default:
      let path = file.displayPath
      oldContents = await gitClient.showFileAtHEAD(path, in: worktreeURL) ?? ""
      newContents = await readWorkingFile(path, in: worktreeURL)
    }

    guard selectedFile == file else { return }

    let diffFile = DiffFile(
      oldPath: file.oldPath,
      newPath: file.newPath,
      oldContents: oldContents,
      newContents: newContents,
    )
    diffDocument = DiffDocument(files: [diffFile], title: file.displayName)
    isLoadingDiff = false
  }

  private func readWorkingFile(_ relativePath: String, in worktreeURL: URL) async -> String {
    let fileURL = worktreeURL.appending(path: relativePath)
    return await Task.detached {
      (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
    }.value
  }
}
