// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import CoreData
import Pulse
import Combine
import SwiftUI

final class ConsoleFiltersViewModel: ObservableObject {
    @Published var criteria: ConsoleFilters = .default
    @Published var isButtonResetEnabled = false

    private(set) var defaultCriteria: ConsoleFilters = .default

    let dataNeedsReload = PassthroughSubject<Void, Never>()

    let labels: ManagedObjectsObserver<LoggerLabelEntity>
    let domains: ManagedObjectsObserver<NetworkDomainEntity>

    private let store: LoggerStore
    private var cancellables: [AnyCancellable] = []

    init(store: LoggerStore) {
        self.store = store

        self.labels = ManagedObjectsObserver(context: store.viewContext, sortDescriptior: NSSortDescriptor(keyPath: \LoggerLabelEntity.name, ascending: true))
        self.domains = ManagedObjectsObserver(context: store.viewContext, sortDescriptior: NSSortDescriptor(keyPath: \NetworkDomainEntity.count, ascending: false))

#warning("TODO: can this be simplified?")
        if store === LoggerStore.shared {
            criteria.shared.dates = .session
            defaultCriteria.shared.dates = .session
        }

#warning("TODO: rework how reset is enabled (we have hashable for this)")
        $criteria.dropFirst().sink { [weak self] _ in
            self?.isButtonResetEnabled = true
            DispatchQueue.main.async { // important!
                self?.dataNeedsReload.send()
            }
        }.store(in: &cancellables)
    }

#warning("TODO: return different value based on the mod")
    var isDefaultAll: Bool {
        criteria == defaultCriteria
    }

    #warning("TODO: remove this")
    var isDefaultForMessages: Bool {
        criteria.messages == defaultCriteria.messages
    }

    var isDefaultForNetwork: Bool {
        criteria.network == defaultCriteria.network
    }

    func resetAll() {
        criteria = defaultCriteria
        isButtonResetEnabled = false
    }

    func removeAllPins() {
        store.pins.removeAllPins()

#if os(iOS)
        runHapticFeedback(.success)
        ToastView {
            HStack {
                Image(systemName: "trash")
                Text("All pins removed")
            }
        }.show()
#endif
    }

    // MARK: Binding (ConsoleFilters.LogLevel)

    func binding(forLevel level: LoggerStore.Level) -> Binding<Bool> {
        Binding(get: {
            self.criteria.messages.logLevels.levels.contains(level)
        }, set: { isOn in
            if isOn {
                self.criteria.messages.logLevels.levels.insert(level)
            } else {
                self.criteria.messages.logLevels.levels.remove(level)
            }
        })
    }

    /// Returns binding for toggling all log levels.
    var bindingForTogglingAllLevels: Binding<Bool> {
        Binding(get: {
            self.criteria.messages.logLevels.levels.count == LoggerStore.Level.allCases.count
        }, set: { isOn in
            if isOn {
                self.criteria.messages.logLevels.levels = Set(LoggerStore.Level.allCases)
            } else {
                self.criteria.messages.logLevels.levels = Set()
            }
        })
    }

    // MARK: Binding (ConsoleFilters.Labels)

    func binding(forLabel label: String) -> Binding<Bool> {
        Binding(get: {
            if let focused = self.criteria.messages.labels.focused {
                return label == focused
            } else {
                return !self.criteria.messages.labels.hidden.contains(label)
            }
        }, set: { isOn in
            self.criteria.messages.labels.focused = nil
            if isOn {
                self.criteria.messages.labels.hidden.remove(label)
            } else {
                self.criteria.messages.labels.hidden.insert(label)
            }
        })
    }

    var bindingForTogglingAllLabels: Binding<Bool> {
        Binding(get: {
            self.criteria.messages.labels.hidden.isEmpty
        }, set: { isOn in
            self.criteria.messages.labels.focused = nil
            if isOn {
                self.criteria.messages.labels.hidden = []
            } else {
                self.criteria.messages.labels.hidden = Set(self.labels.objects.map(\.name))
            }
        })
    }

    // MARK: Custom Filters

#warning("TODO: move to the view & use binding for this")
    func remove(_ filter: ConsoleCustomMessageFilter) {
        if let index = criteria.messages.custom.filters.firstIndex(where: { $0.id == filter.id }) {
            criteria.messages.custom.filters.remove(at: index)
        }
        if criteria.messages.custom.filters.isEmpty {
            criteria.messages.custom = .default
        }
    }

    // MARK: Custom Network Filters

    func removeFilter(_ filter: ConsoleCustomNetworkFilter) {
        if let index = criteria.network.customNetworkFilters.filters.firstIndex(where: { $0.id == filter.id }) {
            criteria.network.customNetworkFilters.filters.remove(at: index)
        }
#warning("TODO: is this needed? enable remove only when 2+ items")
        if criteria.network.customNetworkFilters.filters.isEmpty {
            criteria.network.customNetworkFilters = .default
        }
    }

#warning("TODO: move to ConsoleFilters+extensions")
    var programmaticFilters: [ConsoleCustomNetworkFilter]? {
        let programmaticFilters = criteria.network.customNetworkFilters.filters.filter { $0.isProgrammatic && !$0.value.isEmpty }
        guard !programmaticFilters.isEmpty && criteria.network.customNetworkFilters.isEnabled else {
            return nil
        }
        return programmaticFilters
    }

    // MARK: Bindings

    func binding(forDomain domain: String) -> Binding<Bool> {
        Binding(get: {
            !self.criteria.network.host.ignoredHosts.contains(domain)
        }, set: { newValue in
            if self.criteria.network.host.ignoredHosts.remove(domain) == nil {
                self.criteria.network.host.ignoredHosts.insert(domain)
            }
        })
    }
}
