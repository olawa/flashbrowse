import SwiftUI

public struct BreadcrumbBarView: View {
    @ObservedObject var state: NavigationState
    @FocusState private var isSearchFocused: Bool
    @FocusState private var isPathFieldFocused: Bool
    
    public init(state: NavigationState) {
        self.state = state
    }
    
    public var body: some View {
        HStack(spacing: 8) {
            // History Navigation
            HStack(spacing: 4) {
                Button(action: { state.goBack() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 26, height: 26)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(6)
                }
                .disabled(!state.canGoBack)
                .buttonStyle(.plain)
                .help("Back (Cmd+[)")
                
                Button(action: { state.goForward() }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 26, height: 26)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(6)
                }
                .disabled(!state.canGoForward)
                .buttonStyle(.plain)
                .help("Forward (Cmd+])")
                
                Button(action: { state.goUp() }) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 26, height: 26)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(6)
                }
                .disabled(!state.canGoUp)
                .buttonStyle(.plain)
                .help("Parent Directory (Cmd+Up / Pinch-In)")
            }
            
            // Ubuntu / Nautilus Style Breadcrumb Path Bar
            Group {
                if state.isEditingPath {
                    HStack {
                        Image(systemName: "folder.fill")
                            .foregroundColor(Color(red: 0.91, green: 0.33, blue: 0.13))
                        TextField("Enter path (e.g. ~/dev or /tmp)", text: $state.pathInputText)
                            .textFieldStyle(.plain)
                            .focused($isPathFieldFocused)
                            .onSubmit {
                                state.commitPathInput()
                            }
                            .onExitCommand {
                                state.isEditingPath = false
                            }
                        
                        Button(action: { state.isEditingPath = false }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 8)
                    .frame(height: 28)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(red: 0.91, green: 0.33, blue: 0.13), lineWidth: 1.5)
                    )
                    .onAppear {
                        isPathFieldFocused = true
                    }
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 3) {
                            ForEach(state.breadcrumbs, id: \.url) { crumb in
                                let isCurrent = crumb.url == state.currentDirectory
                                
                                Button(action: {
                                    state.navigateTo(url: crumb.url)
                                }) {
                                    HStack(spacing: 4) {
                                        if crumb.url.path == "/" {
                                            Image(systemName: "internaldrive.fill")
                                                .font(.system(size: 11))
                                        } else {
                                            Image(systemName: "folder.fill")
                                                .font(.system(size: 11))
                                                .foregroundColor(isCurrent ? .white : Color(red: 0.91, green: 0.33, blue: 0.13))
                                        }
                                        
                                        Text(crumb.name.isEmpty ? "/" : crumb.name)
                                            .font(.system(size: 12, weight: isCurrent ? .bold : .medium))
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        isCurrent
                                        ? Color(red: 0.91, green: 0.33, blue: 0.13)
                                        : Color(nsColor: .controlBackgroundColor).opacity(0.8)
                                    )
                                    .foregroundColor(isCurrent ? .white : .primary)
                                    .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                                
                                if crumb.url != state.currentDirectory {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(.secondary.opacity(0.5))
                                }
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal, 2)
                    }
                    .frame(height: 28)
                    .onTapGesture(count: 2) {
                        state.isEditingPath = true
                    }
                }
            }
            .frame(maxWidth: .infinity)
            
            // Star / Bookmark Current Directory
            Button(action: {
                state.toggleBookmark(url: state.currentDirectory)
            }) {
                Image(systemName: state.isBookmarked(url: state.currentDirectory) ? "star.fill" : "star")
                    .font(.system(size: 12))
                    .foregroundColor(state.isBookmarked(url: state.currentDirectory) ? Color(red: 0.95, green: 0.65, blue: 0.15) : .secondary)
                    .frame(width: 26, height: 26)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .help(state.isBookmarked(url: state.currentDirectory) ? "Remove current folder from Favorites" : "Pin current folder to Favorites")
            
            // Path Edit Button
            Button(action: {
                state.isEditingPath.toggle()
            }) {
                Image(systemName: state.isEditingPath ? "folder.fill" : "pencil")
                    .font(.system(size: 12))
                    .frame(width: 26, height: 26)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .help("Edit Path (Cmd+L)")
            
            // Search Bar with Scope Switcher
            HStack(spacing: 4) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                
                TextField(state.searchScope == .currentFolder ? "Search folder..." : "Search subfolders...", text: $state.searchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .focused($isSearchFocused)
                    .frame(width: 115)
                
                // Search Scope Toggle Button
                Button(action: {
                    state.searchScope = (state.searchScope == .currentFolder) ? .includeSubfolders : .currentFolder
                }) {
                    Image(systemName: state.searchScope == .includeSubfolders ? "arrow.triangle.branch" : "folder")
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(state.searchScope == .includeSubfolders ? Color(red: 0.91, green: 0.33, blue: 0.13) : Color.clear)
                        .foregroundColor(state.searchScope == .includeSubfolders ? .white : .secondary)
                        .cornerRadius(3)
                }
                .buttonStyle(.plain)
                .help(state.searchScope == .currentFolder ? "Click to include subfolders (Recursive Search)" : "Click to search current folder only")
                
                if !state.searchQuery.isEmpty {
                    Button(action: { state.searchQuery = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 6)
            .frame(height: 28)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
            )
            
            // View Mode Switcher (List / Grid)
            HStack(spacing: 0) {
                Button(action: { state.viewMode = .list }) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 7)
                        .frame(height: 26)
                        .background(state.viewMode == .list ? Color(red: 0.91, green: 0.33, blue: 0.13) : Color.clear)
                        .foregroundColor(state.viewMode == .list ? .white : .primary)
                }
                .buttonStyle(.plain)
                
                Button(action: { state.viewMode = .grid }) {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 7)
                        .frame(height: 26)
                        .background(state.viewMode == .grid ? Color(red: 0.91, green: 0.33, blue: 0.13) : Color.clear)
                        .foregroundColor(state.viewMode == .grid ? .white : .primary)
                }
                .buttonStyle(.plain)
            }
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
            )
            
            // Detached Inspector Button (Multi-Monitor)
            Button(action: {
                InspectorWindowController.shared.toggleWindow()
            }) {
                Image(systemName: "display.2")
                    .font(.system(size: 12))
                    .frame(width: 26, height: 26)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .help("Open Inspector Window (Cmd+Option+I) for external monitor")
            
            // View Options Menu
            Menu {
                Section("Search Scope") {
                    Picker("Scope", selection: $state.searchScope) {
                        ForEach(SearchScope.allCases) { s in
                            Text(s.rawValue).tag(s)
                        }
                    }
                }
                
                Divider()
                
                Section("Behavior") {
                    Toggle("Single Click to Open", isOn: $state.singleClickToOpen)
                    Toggle("Hover to Select", isOn: $state.hoverToSelect)
                }
                
                Divider()
                
                Section("Sorting & View") {
                    Toggle("Folders on Top", isOn: $state.foldersFirst)
                    Toggle("Show Hidden Files", isOn: $state.showHiddenFiles)
                    
                    Picker("Sort By", selection: $state.sortField) {
                        ForEach(SortField.allCases) { field in
                            Text(field.rawValue).tag(field)
                        }
                    }
                    
                    Toggle("Ascending", isOn: $state.sortAscending)
                }
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 12))
                    .frame(width: 26, height: 26)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(6)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 26)
            .help("Preferences & Sorting")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color(nsColor: .separatorColor)),
            alignment: .bottom
        )
    }
}
