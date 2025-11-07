//
//  NotchMemoView.swift
//  boringNotch
//
//  Persistent memo widget for the notch header
//

import SwiftUI
import Defaults

struct NotchMemoView: View {
    @ObservedObject var memoManager = MemoManager.shared
    @State private var isExpanded = false
    @State private var showingAddSheet = false
    @State private var editingItem: MemoItem?
    @State private var newMemoText = ""
    @State private var editMemoText = ""
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            if !memoManager.items.isEmpty {
                // Compact view showing memo count
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isExpanded.toggle()
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "note.text")
                            .font(.system(size: 12, weight: .medium))
                        Text("\(memoManager.items.count)")
                            .font(.system(size: 11, weight: .semibold))
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.white.opacity(0.1))
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .help("メモ")
            }

            // Add button (always visible)
            Button(action: {
                showingAddSheet = true
                newMemoText = ""
            }) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
            .buttonStyle(PlainButtonStyle())
            .help("メモを追加")
        }
        .popover(isPresented: $isExpanded, arrowEdge: .bottom) {
            MemoListPopover(
                memoManager: memoManager,
                editingItem: $editingItem,
                editMemoText: $editMemoText
            )
        }
        .sheet(isPresented: $showingAddSheet) {
            AddMemoSheet(
                newMemoText: $newMemoText,
                isTextFieldFocused: _isTextFieldFocused,
                onAdd: {
                    if !newMemoText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        memoManager.addItem(text: newMemoText)
                        showingAddSheet = false
                        newMemoText = ""
                    }
                },
                onCancel: {
                    showingAddSheet = false
                    newMemoText = ""
                }
            )
        }
        .sheet(item: $editingItem) { item in
            EditMemoSheet(
                editMemoText: $editMemoText,
                isTextFieldFocused: _isTextFieldFocused,
                onSave: {
                    if !editMemoText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        memoManager.updateItem(id: item.id, text: editMemoText)
                        editingItem = nil
                    }
                },
                onCancel: {
                    editingItem = nil
                }
            )
        }
    }
}

// MARK: - Memo List Popover
struct MemoListPopover: View {
    @ObservedObject var memoManager: MemoManager
    @Binding var editingItem: MemoItem?
    @Binding var editMemoText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("メモ")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                if !memoManager.items.isEmpty {
                    Button(action: {
                        memoManager.clearAll()
                    }) {
                        Text("全て削除")
                            .font(.system(size: 11))
                            .foregroundColor(.red.opacity(0.8))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            // List
            if memoManager.items.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "note.text")
                        .font(.system(size: 32))
                        .foregroundColor(.gray.opacity(0.5))
                    Text("メモがありません")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 120)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(memoManager.items) { item in
                            MemoItemRow(
                                item: item,
                                onEdit: {
                                    editMemoText = item.text
                                    editingItem = item
                                },
                                onDelete: {
                                    memoManager.deleteItem(id: item.id)
                                }
                            )
                            if item.id != memoManager.items.last?.id {
                                Divider()
                                    .padding(.leading, 16)
                            }
                        }
                    }
                }
                .frame(height: min(CGFloat(memoManager.items.count * 60), 300))
            }
        }
        .frame(width: 320)
        .background(.ultraThinMaterial)
    }
}

// MARK: - Memo Item Row
struct MemoItemRow: View {
    let item: MemoItem
    let onEdit: () -> Void
    let onDelete: () -> Void
    @State private var isHovering = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.text)
                    .font(.system(size: 13))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(timeAgo(from: item.updatedAt))
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
            }

            Spacer()

            if isHovering {
                HStack(spacing: 8) {
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(.system(size: 12))
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("編集")

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("削除")
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
        }
    }

    private func timeAgo(from date: Date) -> String {
        let seconds = Date().timeIntervalSince(date)
        if seconds < 60 {
            return "今"
        } else if seconds < 3600 {
            return "\(Int(seconds / 60))分前"
        } else if seconds < 86400 {
            return "\(Int(seconds / 3600))時間前"
        } else {
            return "\(Int(seconds / 86400))日前"
        }
    }
}

// MARK: - Add Memo Sheet
struct AddMemoSheet: View {
    @Binding var newMemoText: String
    @FocusState var isTextFieldFocused: Bool
    let onAdd: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("新しいメモ")
                .font(.system(size: 16, weight: .semibold))

            TextEditor(text: $newMemoText)
                .font(.system(size: 14))
                .frame(height: 120)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                .focused($isTextFieldFocused)

            HStack(spacing: 12) {
                Button("キャンセル") {
                    onCancel()
                }
                .keyboardShortcut(.escape)

                Button("追加") {
                    onAdd()
                }
                .keyboardShortcut(.return)
                .disabled(newMemoText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 400)
        .onAppear {
            isTextFieldFocused = true
        }
    }
}

// MARK: - Edit Memo Sheet
struct EditMemoSheet: View {
    @Binding var editMemoText: String
    @FocusState var isTextFieldFocused: Bool
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("メモを編集")
                .font(.system(size: 16, weight: .semibold))

            TextEditor(text: $editMemoText)
                .font(.system(size: 14))
                .frame(height: 120)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                .focused($isTextFieldFocused)

            HStack(spacing: 12) {
                Button("キャンセル") {
                    onCancel()
                }
                .keyboardShortcut(.escape)

                Button("保存") {
                    onSave()
                }
                .keyboardShortcut(.return)
                .disabled(editMemoText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 400)
        .onAppear {
            isTextFieldFocused = true
        }
    }
}

#Preview {
    NotchMemoView()
        .frame(width: 600, height: 100)
        .background(.black)
}
