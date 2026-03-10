//
//  ShelfItemView.swift
//  boringNotch
//
//  Created by Alexander on 2025-09-24.
//

import SwiftUI
import AppKit

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
                .onDrop(of: [.fileURL, .url, .utf8PlainText, .plainText, .data], isTargeted: $vm.dragDetectorTargeting) { providers in
                    handleDrop(providers: providers)
                }
        }
        // Bind Quick Look to shelf selection
        .onChange(of: selection.selectedIDs) {
            updateQuickLookSelection()
        }
        .onDisappear {
            clearConfirmationTask?.cancel()
            clearConfirmationTask = nil
            clearConfirmationArmed = false
        }
        .quickLookPresenter(using: quickLookService)
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard !selection.isDragging else { return false }
        vm.dropEvent = true
        ShelfStateViewModel.shared.load(providers)
        return true
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

    private func handleClearTap() {
        guard !tvm.isEmpty else { return }

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

    private var panelStrokeColor: Color {
        vm.dragDetectorTargeting ? Color.accentColor.opacity(0.9) : Color.white.opacity(0.1)
    }

    private var clearButtonTitle: String {
        clearConfirmationArmed ? "Confirm?" : String(localized: "Clear slot")
    }

    private var clearButtonIcon: String {
        clearConfirmationArmed ? "exclamationmark.triangle.fill" : "trash"
    }

    private var clearButtonFill: Color {
        clearConfirmationArmed ? Color.orange.opacity(0.18) : Color.red.opacity(0.12)
    }

    private var clearButtonStroke: Color {
        clearConfirmationArmed ? Color.orange.opacity(0.45) : Color.red.opacity(0.30)
    }

    private var clearButtonForeground: Color {
        clearConfirmationArmed ? Color.orange.opacity(0.98) : Color.red.opacity(0.95)
    }

    @ViewBuilder
    private var clearButtonOverlay: some View {
        if !tvm.isEmpty {
            Button(role: .destructive) {
                handleClearTap()
            } label: {
                Label(clearButtonTitle, systemImage: clearButtonIcon)
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(clearButtonFill))
                    .overlay(
                        Capsule()
                            .stroke(clearButtonStroke, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .foregroundStyle(clearButtonForeground)
            .padding(.top, 10)
            .padding(.trailing, 12)
            .allowsHitTesting(!vm.dragDetectorTargeting)
        }
    }

    var panel: some View {
        RoundedRectangle(cornerRadius: 16)
            .stroke(panelStrokeColor, style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [10]))
            .overlay {
                content
                    .padding()
            }
            .overlay(alignment: .topTrailing) {
                clearButtonOverlay
            }
            .transaction { transaction in
                transaction.animation = vm.animation
            }
            .contentShape(Rectangle())
            .onTapGesture {
                selection.clear()
                clearConfirmationArmed = false
                clearConfirmationTask?.cancel()
                clearConfirmationTask = nil
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
                    HStack(spacing: spacing) {
                        ForEach(tvm.items) { item in
                            ShelfItemView(item: item)
                                .environmentObject(quickLookService)
                        }
                    }
                }
                .padding(-spacing)
                .scrollIndicators(.never)
                .onDrop(of: [.fileURL, .url, .utf8PlainText, .plainText, .data], isTargeted: $vm.dragDetectorTargeting) { providers in
                    handleDrop(providers: providers)
                }
            }
        }
        .onAppear {
            ShelfStateViewModel.shared.cleanupInvalidItems()
        }
    }
}
