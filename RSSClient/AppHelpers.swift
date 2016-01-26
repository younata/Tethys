import rNewsKit
import AVFoundation

func enclosureIsSupported(enclosure: Enclosure) -> Bool {
    return AVURLAsset.audiovisualMIMETypes().contains(enclosure.kind) && enclosure.kind.hasPrefix("video")
}
