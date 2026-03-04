//
//  ShelfItemView.swift
//  boringNotch
//
//  Created by Alexander on 2025-09-24.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

private let shelfInternalDragIdentifier = "theboringteam.boringnotch.shelf-item"
private let shelfInternalPasteboardType = NSPasteboard.PasteboardType(shelfInternalDragIdentifier)

struct ShelfView: View {
    @EnvironmentObject var vm: BoringViewModel
    @StateObject var tvm = ShelfStateViewModel.shared
    @StateObject var selection = ShelfSelectionModel.shared
    @StateObject private var quickLookService = QuickLookService()
    @State private var clearConfirmationArmed = false
    @State private var clearConfirmationTask: Task<Void, Never>?
    private let spacing: CGFloat = 8
    private let clearConfirmTimeout: Duration = .seconds(4)

    var body: some View {
        HStack(spacing: 12) {
            FileShareView()
                .aspectRatio(1, contentMode: .fit)
                .environmentObject(vm)
            panel
            ShelfDeleteDropView(isTargeted: $vm.shelfRemoveTargeting) { providers in
                handleDeleteDrop(providers: providers)
            }
            .frame(width: 86)
            .aspectRatio(0.82, contentMode: .fit)
        }
        // Bind Quick Look to shelf selection
        .onChange(of: selection.selectedIDs) {
            updateQuickLookSelection()
        }
        .onDisappear {
            clearConfirmationTask?.cancel()
            clearConfirmationTask = nil
            vm.shelfRemoveTargeting = false
        }
        .quickLookPresenter(using: quickLookService)
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard !selection.isDragging else { return false }
        vm.dropEvent = true
        ShelfStateViewModel.shared.load(providers)
        return true
    }

    private func handleDeleteDrop(providers: [NSItemProvider]) -> Bool {
        vm.dropEvent = true

        if handleInternalDeleteDrop() {
            return true
        }

        guard !providers.isEmpty else { return false }
        Task {
            await ShelfStateViewModel.shared.removeItemsMatchingDroppedProviders(providers)
            selection.clear()
            selection.clearDragSnapshot()
        }
        return true
    }

    private func handleInternalDeleteDrop() -> Bool {
        let draggedItems = selection.draggedItems(in: tvm.items)
        let recentDraggedItems = selection.recentDraggedItems(in: tvm.items, within: 1.5)
        let itemsToRemove = !draggedItems.isEmpty ? draggedItems : recentDraggedItems
        guard !itemsToRemove.isEmpty else { return false }

        vm.dropEvent = true
        for item in itemsToRemove {
            ShelfStateViewModel.shared.remove(item)
        }
        selection.clear()
        selection.clearDragSnapshot()
        return true
    }

    private func handleClearTap() {
        if clearConfirmationArmed {
            clearConfirmationTask?.cancel()
            clearConfirmationTask = nil
            clearConfirmationArmed = false
            ShelfStateViewModel.shared.clearAll()
            selection.clear()
            return
        }

        clearConfirmationArmed = true
        clearConfirmationTask?.cancel()
        clearConfirmationTask = Task { @MainActor in
            try? await Task.sleep(for: clearConfirmTimeout)
            guard !Task.isCancelled else { return }
            clearConfirmationArmed = false
            clearConfirmationTask = nil
        }
    }
    
    private func updateQuickLookSelection() {
        guard quickLookService.isQuickLookOpen && !selection.selectedIDs.isEmpty else { return }
        
        let selectedItems = selection.selectedItems(in: tvm.items)
        let urls: [URL] = selectedItems.compactMap { item in
            if let fileURL = item.fileURL {
                return fileURL
            }
            if case .link(let url) = item.kind {
                return url
            }
            return nil
        }
        
        if !urls.isEmpty {
            quickLookService.updateSelection(urls: urls)
        }
    }

    var panel: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    vm.dragDetectorTargeting
                        ? Color.accentColor.opacity(0.9)
                        : Color.white.opacity(0.1),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [10])
                )
                .overlay {
                    content
                        .padding()
                }
                .transaction { transaction in
                    transaction.animation = vm.animation
                }
                .contentShape(Rectangle())
                .onDrop(of: [.item, .fileURL, .url, .utf8PlainText, .plainText, .text, .data], isTargeted: $vm.dragDetectorTargeting) { providers in
                    handleDrop(providers: providers)
                }
                .onTapGesture {
                    selection.clear()
                    clearConfirmationArmed = false
                    clearConfirmationTask?.cancel()
                    clearConfirmationTask = nil
                    vm.shelfRemoveTargeting = false
                }

            if !tvm.isEmpty {
                clearButton
                    .padding(.top, 8)
                    .padding(.trailing, 12)
            }
        }
    }

    var content: some View {
        Group {
            if tvm.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "tray.and.arrow.down")
                        .symbolVariant(.fill)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.white, .gray)
                        .imageScale(.large)
                    
                    Text("Drop files here")
                        .foregroundStyle(.gray)
                        .font(.system(.title3, design: .rounded))
                        .fontWeight(.medium)
                }
            } else {
                ScrollView(.horizontal) {
                    LazyHStack(spacing: spacing) {
                        ForEach(tvm.items) { item in
                            ShelfItemView(item: item)
                                .environmentObject(quickLookService)
                        }
                    }
                }
                .padding(-spacing)
                .scrollIndicators(.never)
            }
        }
        .onAppear {
            ShelfStateViewModel.shared.cleanupInvalidItems()
        }
    }

    private var clearButton: some View {
        Button(role: .destructive) {
            handleClearTap()
        } label: {
            Label(clearConfirmationArmed ? "Confirm?" : "Clear", systemImage: clearConfirmationArmed ? "exclamationmark.triangle.fill" : "trash")
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(clearConfirmationArmed ? Color.orange.opacity(0.18) : Color.red.opacity(0.12))
                )
                .overlay(
                    Capsule()
                        .stroke(clearConfirmationArmed ? Color.orange.opacity(0.45) : Color.red.opacity(0.30), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .foregroundStyle(clearConfirmationArmed ? Color.orange.opacity(0.98) : Color.red.opacity(0.95))
        .shadow(color: .black.opacity(0.18), radius: 6, x: 0, y: 2)
    }
}

private struct ShelfDeleteDropView: View {
    @Binding var isTargeted: Bool
    let onDrop: ([NSItemProvider]) -> Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(colors: [Color.black.opacity(0.30), Color.black.opacity(0.18)], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            isTargeted
                                ? Color.red.opacity(0.95)
                                : Color.white.opacity(0.10),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [10])
                        )
                )

            VStack(spacing: 5) {
                Circle()
                    .fill(isTargeted ? Color.red.opacity(0.18) : Color.white.opacity(0.09))
                    .frame(width: 42, height: 42)
                    .overlay {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(isTargeted ? Color.red : Color.gray)
                    }

                Text(isTargeted ? localizedDropHint : localizedRemoveLabel)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .foregroundStyle(Color.white.opacity(0.75))
            }
            .padding(8)

            ShelfDeleteDropReceiver(isTargeted: $isTargeted, onDrop: onDrop)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .onReceive(Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()) { _ in
            if ShelfSelectionModel.shared.isDragging {
                let targetState = ShelfSelectionModel.shared.isPointInRemoveDropArea(NSEvent.mouseLocation)
                if isTargeted != targetState {
                    isTargeted = targetState
                }
            } else if !ShelfSelectionModel.shared.isDragRecentlyEnded(within: 0.2) {
                if isTargeted {
                    isTargeted = false
                }
            }
        }
    }

    private var localizedRemoveLabel: String {
        let lang = Locale.preferredLanguages.first?.lowercased() ?? "en"
        switch lang {
        case let l where l.hasPrefix("zh"):
            return "从暂存区移除"
        case let l where l.hasPrefix("de"):
            return "Aus Ablage entfernen"
        case let l where l.hasPrefix("ko"):
            return "보관함에서 제거"
        default:
            return "Remove from Shelf"
        }
    }

    private var localizedDropHint: String {
        let lang = Locale.preferredLanguages.first?.lowercased() ?? "en"
        switch lang {
        case let l where l.hasPrefix("zh"):
            return "松手即可移除"
        case let l where l.hasPrefix("de"):
            return "Loslassen zum Entfernen"
        case let l where l.hasPrefix("ko"):
            return "놓으면 제거됩니다"
        default:
            return "Drop to remove from Shelf"
        }
    }
}

private struct ShelfDeleteDropReceiver: NSViewRepresentable {
    @Binding var isTargeted: Bool
    let onDrop: ([NSItemProvider]) -> Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(isTargeted: $isTargeted, onDrop: onDrop)
    }

    func makeNSView(context: Context) -> ReceiverView {
        let view = ReceiverView()
        view.coordinator = context.coordinator
        return view
    }

    func updateNSView(_ nsView: ReceiverView, context: Context) {
        context.coordinator.isTargeted = $isTargeted
        context.coordinator.onDrop = onDrop
        nsView.coordinator = context.coordinator
    }

    final class Coordinator {
        var isTargeted: Binding<Bool>
        var onDrop: ([NSItemProvider]) -> Bool

        init(isTargeted: Binding<Bool>, onDrop: @escaping ([NSItemProvider]) -> Bool) {
            self.isTargeted = isTargeted
            self.onDrop = onDrop
        }
    }

    final class ReceiverView: NSView {
        var coordinator: Coordinator?

        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            registerForDraggedTypes([
                shelfInternalPasteboardType,
                .fileURL,
                .URL,
                .string,
                NSPasteboard.PasteboardType(UTType.item.identifier),
                NSPasteboard.PasteboardType(UTType.text.identifier),
                NSPasteboard.PasteboardType(UTType.utf8PlainText.identifier),
                NSPasteboard.PasteboardType(UTType.plainText.identifier),
                NSPasteboard.PasteboardType(UTType.data.identifier),
                NSPasteboard.PasteboardType(UTType.image.identifier)
            ])
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            updateDropFrameInSelectionModel()
        }

        override func layout() {
            super.layout()
            updateDropFrameInSelectionModel()
        }

        override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
            coordinator?.isTargeted.wrappedValue = true
            return preferredDropOperation(for: sender)
        }

        override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
            coordinator?.isTargeted.wrappedValue = true
            return preferredDropOperation(for: sender)
        }

        override func draggingExited(_ sender: NSDraggingInfo?) {
            coordinator?.isTargeted.wrappedValue = false
        }

        override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
            true
        }

        override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
            coordinator?.isTargeted.wrappedValue = false
            // Internal shelf drags are handled by shared selection state.
            if sender.draggingPasteboard.availableType(from: [shelfInternalPasteboardType]) != nil {
                return coordinator?.onDrop([]) ?? false
            }
            let providers = Self.makeItemProviders(from: sender.draggingPasteboard)
            return coordinator?.onDrop(providers) ?? false
        }

        override func concludeDragOperation(_ sender: NSDraggingInfo?) {
            coordinator?.isTargeted.wrappedValue = false
        }

        private func updateDropFrameInSelectionModel() {
            guard let window else {
                ShelfSelectionModel.shared.updateRemoveDropFrameInScreen(.null)
                return
            }
            let frameInWindow = convert(bounds, to: nil)
            let frameInScreen = window.convertToScreen(frameInWindow)
            ShelfSelectionModel.shared.updateRemoveDropFrameInScreen(frameInScreen)
        }

        private func preferredDropOperation(for sender: NSDraggingInfo) -> NSDragOperation {
            if sender.draggingPasteboard.availableType(from: [shelfInternalPasteboardType]) != nil {
                return .move
            }
            return .copy
        }

        private static func makeItemProviders(from pasteboard: NSPasteboard) -> [NSItemProvider] {
            guard let items = pasteboard.pasteboardItems else { return [] }

            return items.compactMap { pasteboardItem in
                let provider = NSItemProvider()
                var hasRepresentation = false

                for type in pasteboardItem.types {
                    if let data = pasteboardItem.data(forType: type) {
                        hasRepresentation = true
                        provider.registerDataRepresentation(forTypeIdentifier: type.rawValue, visibility: .all) { completion in
                            completion(data, nil)
                            return nil
                        }
                        continue
                    }

                    if let string = pasteboardItem.string(forType: type) {
                        hasRepresentation = true
                        let data = Data(string.utf8)
                        provider.registerDataRepresentation(forTypeIdentifier: type.rawValue, visibility: .all) { completion in
                            completion(data, nil)
                            return nil
                        }
                    }
                }

                return hasRepresentation ? provider : nil
            }
        }
    }
}
