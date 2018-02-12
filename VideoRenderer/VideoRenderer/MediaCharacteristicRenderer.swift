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
    
    public let unselectedAudibleOptions: [Option]
    public let selectedAudibleOption: Option?
    public let unselectedLegibleOptions: [Option]
    public let selectedLegibleOption: Option?
}

class MediaCharacteristicRenderer {
    typealias Option = AvailableMediaOptions.Option
    
    struct Props {
        let item: AVPlayerItem
        let didStartMediaOptionsDiscovery: () -> ()
        let didDiscoverMediaOptions: (AvailableMediaOptions) -> ()
        var selectedAudibleOption: Option?
        var selectedLegibleOption: Option?
    }
    
    struct MediaOptionCache {
        let item: AVPlayerItem
        var audibleOptions: [Option: AVMediaSelectionOption] = [:]
        var legibleOptions: [Option: AVMediaSelectionOption] = [:]
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
                    
                    let audibleGroup = item.asset.mediaSelectionGroup(forMediaCharacteristic: AVMediaCharacteristicAudible)
                    let legibleGroup = item.asset.mediaSelectionGroup(forMediaCharacteristic: AVMediaCharacteristicLegible)
                    
                    let audibleOptions = audibleGroup?.options ?? []
                    let legibleOptions = legibleGroup?.options.filter(AVMediaSelectionOption.hasLanguageTag) ?? []
                    
                    let audibleOptionsPairs = audibleOptions.map { option in
                        (Option(name: option.displayName), option)
                    }
                    
                    var legibleOptionsPairs = legibleOptions.map { option in
                        (Option(name: option.displayName), option)
                    }
                    legibleOptionsPairs.insert((Option(name: "None"), AVMediaSelectionOption()), at: 0)
                    
                    self.mediaOptionCache = MediaOptionCache(
                        item: item,
                        audibleOptions: Dictionary(uniqueKeysWithValues: audibleOptionsPairs),
                        legibleOptions: Dictionary(uniqueKeysWithValues: legibleOptionsPairs)
                    )
                    
                    let selectedAudibleOption = audibleGroup.flatMap { item.selectedMediaOption(in: $0) }
                    let selectedLegibleOption = legibleGroup.flatMap { item.selectedMediaOption(in: $0) }
                    
                    let unselectedAudibleOptionsPairs = audibleOptionsPairs.filter {
                        $0.1 != selectedAudibleOption
                    }
                    
                    let selectedAudibleOptionPair = audibleOptionsPairs.first {
                        $0.1 == selectedAudibleOption
                    }
                    
                    let unselectedLegibleOptionsPairs = legibleOptionsPairs.filter {
                        $0.1 != selectedLegibleOption
                    }
                    
                    // Selected 'None' as default
                    let selectedLegibleOptionsPair = legibleOptionsPairs.first
                    
                    let availableOptions = AvailableMediaOptions(
                        unselectedAudibleOptions: unselectedAudibleOptionsPairs.map(first),
                        selectedAudibleOption: selectedAudibleOptionPair?.0,
                        unselectedLegibleOptions: unselectedLegibleOptionsPairs.map(first),
                        selectedLegibleOption: selectedLegibleOptionsPair?.0)
                    
                    self.props?.didDiscoverMediaOptions(availableOptions)
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
