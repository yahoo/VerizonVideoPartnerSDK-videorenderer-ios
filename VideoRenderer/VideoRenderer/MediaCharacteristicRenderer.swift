//  Copyright © 2016 One by Aol : Publishers. All rights reserved.

import AVFoundation

private let assetKey = "availableMediaCharacteristicsWithMediaSelectionOptions"

public protocol UUIDPhantom: Hashable {
    var uuid: UUID { get }
}

extension UUIDPhantom {
    public var hashValue: Int { return uuid.hashValue }
    public static func ==(left: Self, right: Self) -> Bool {
        return left.uuid == right.uuid
    }
}

func first<T, U>(pair: (T, U)) -> T { return pair.0 }
func second<T, U>(pair: (T, U)) -> U { return pair.1 }

public struct AvailableMediaOptions {
    public struct Option: UUIDPhantom {
        public let uuid: UUID
        public let name: String
        
        public init(uuid: UUID = UUID(), name: String) {
            self.uuid = uuid
            self.name = name
        }
    }
    
    public let unselectedOptions: [Option]
    public let selectedOption: Option?
}

class MediaCharacteristicRenderer {
    typealias Option = AvailableMediaOptions.Option
    
    struct Props {
        let item: AVPlayerItem
        let didStartMediaOptionsDiscovery: () -> ()
        let didDiscoverAudibleOptions: (AvailableMediaOptions) -> ()
        let didDiscoverLegibleOptions: (AvailableMediaOptions) -> ()
        var selectedAudibleOption: Option?
        var selectedLegibleOption: Option?
    }
    
    struct MediaOptionCache {
        let item: AVPlayerItem
        var audibleOptions: [Option: AVMediaSelectionOption] = [:]
        var legibleOptions: [Option: AVMediaSelectionOption] = [:]
        
        init(item: AVPlayerItem) {
            self.item = item
        }
    }
    
    var mediaOptionCache: MediaOptionCache?
    
    var props: Props? {
        didSet {
            /// Verify that we have item to look for
            guard let item = props?.item else {
                self.mediaOptionCache = nil
                return
            }
            
            if item != mediaOptionCache?.item { mediaOptionCache = nil }
            
            switch item.asset.statusOfValue(forKey: assetKey, error: nil) {
            /// Load options
            case .unknown:
                props?.didStartMediaOptionsDiscovery()
                item.asset.loadValuesAsynchronously(forKeys: [assetKey]) {
                    // Ignore results that are not actual anymore
                    guard self.props?.item == item else { return }
                    
                    let status = item.asset.statusOfValue(forKey: assetKey, error: nil)
                    // Ignore failed results
                    guard case .loaded = status else { return }
                    
                    self.mediaOptionCache = MediaOptionCache(item: item)
                    
                    func audibleOptions() -> AvailableMediaOptions {
                        let audibleGroup = item.asset.mediaSelectionGroup(forMediaCharacteristic: AVMediaCharacteristicAudible)
                        let audibleOptions = audibleGroup?.options ?? []
                        let audibleOptionsPairs = audibleOptions.map { option in
                            (Option(name: option.displayName), option)
                        }
                        self.mediaOptionCache?.audibleOptions = Dictionary(uniqueKeysWithValues: audibleOptionsPairs)
                        let selectedAudibleOption = audibleGroup.flatMap { item.selectedMediaOption(in: $0) }
                        let selectedAudibleOptionPair = audibleOptionsPairs.first {
                            $0.1 == selectedAudibleOption
                        }
                        let unselectedAudibleOptionsPairs = audibleOptionsPairs.filter {
                            $0.1 != selectedAudibleOption
                        }
                        return .init(
                            unselectedOptions: unselectedAudibleOptionsPairs.map(first),
                            selectedOption: selectedAudibleOptionPair?.0)
                    }
                    
                    func legibleOptions() -> AvailableMediaOptions {
                        let legibleGroup = item.asset.mediaSelectionGroup(forMediaCharacteristic: AVMediaCharacteristicLegible)
                        let legibleOptions = legibleGroup?.options.filter(AVMediaSelectionOption.hasLanguageTag) ?? []
                        var legibleOptionsPairs = legibleOptions.map { option in
                            (Option(name: option.displayName), option)
                        }
                        // Selected 'None' as default
                        let selectedAudibleOptionPair = (Option(name: "None"), AVMediaSelectionOption())
                        legibleOptionsPairs.insert(selectedAudibleOptionPair, at: 0)
                        
                        self.mediaOptionCache?.legibleOptions = Dictionary(uniqueKeysWithValues: legibleOptionsPairs)
                        return .init(
                            unselectedOptions: legibleOptionsPairs.map(first),
                            selectedOption: selectedAudibleOptionPair.0)
                    }
                    
                    self.props?.didDiscoverAudibleOptions(audibleOptions())
                    self.props?.didDiscoverLegibleOptions(legibleOptions())
                }
            case .loading: break // Do nothing
            case .loaded:
                if let group = item.asset.mediaSelectionGroup(forMediaCharacteristic: AVMediaCharacteristicAudible) {
                    let selectedOption = props?.selectedAudibleOption.flatMap {
                        mediaOptionCache?.audibleOptions[$0]
                    }
                    
                    item.select(selectedOption, in: group)
                }
                
                if let group = item.asset.mediaSelectionGroup(forMediaCharacteristic: AVMediaCharacteristicLegible) {
                    let selectedOption = props?.selectedLegibleOption.flatMap {
                        mediaOptionCache?.legibleOptions[$0]
                    }
                    
                    item.select(selectedOption, in: group)
                }
                
            case .failed: break // Maybe we should notify failure via props?
            case .cancelled: break}
        }
    }
}
