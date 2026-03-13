//
//  StaggeredList.swift
//  Pulse
//

import SwiftUI

/// A container view that animates its children in sequentially with a slide-up + fade effect.
struct StaggeredList<Items: RandomAccessCollection, ID: Hashable, RowContent: View>: View {
    let items: Items
    let idKeyPath: KeyPath<Items.Element, ID>
    let staggerDelay: TimeInterval
    let initialDelay: TimeInterval
    let content: (Items.Element) -> RowContent

    @State private var appearedIds: Set<ID> = []

    init(
        items: Items,
        id: KeyPath<Items.Element, ID>,
        staggerDelay: TimeInterval = 0.08,
        initialDelay: TimeInterval = 0.1,
        @ViewBuilder content: @escaping (Items.Element) -> RowContent
    ) {
        self.items = items
        self.idKeyPath = id
        self.staggerDelay = staggerDelay
        self.initialDelay = initialDelay
        self.content = content
    }

    var body: some View {
        let itemsArray = Array(items)
        let appeared = !appearedIds.isEmpty
        ForEach(itemsArray.indices, id: \.self) { index in
            let item = itemsArray[index]
            let itemId = item[keyPath: idKeyPath]
            let shouldAnimate = !appeared

            content(item)
                .modifier(StaggeredModifier(
                    delay: shouldAnimate ? initialDelay + Double(index) * staggerDelay : 0,
                    animate: shouldAnimate
                ))
                .onAppear {
                    appearedIds.insert(itemId)
                }
        }
    }
}

// MARK: - StaggeredItem

/// A wrapper that applies a slide-up + fade entrance animation to a single item.
struct StaggeredItem<Content: View>: View {
    let delay: TimeInterval
    let animate: Bool
    @ViewBuilder let content: Content

    var body: some View {
        content
            .modifier(StaggeredModifier(
                delay: delay,
                animate: animate
            ))
    }
}

// MARK: - StaggeredModifier

/// A modifier that applies a slide-up + fade entrance animation to a single item.
private struct StaggeredModifier: ViewModifier {
    let delay: TimeInterval
    let animate: Bool

    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 20)
            .onAppear {
                guard !isVisible else { return }
                if animate {
                    withAnimation(.easeOut(duration: 0.35).delay(delay)) {
                        isVisible = true
                    }
                } else {
                    isVisible = true
                }
            }
    }
}
