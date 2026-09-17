import Foundation

public enum LineMap {
    /// UTF-16 offsets, matching AppKit; treat CRLF as one line break.
    public static func starts(in text: String) -> [Int] {
        var offsets = [0]
        var previous: UInt16 = 0
        for (index, unit) in text.utf16.enumerated() {
            if unit == 10 {
                if previous == 13 { offsets[offsets.count - 1] = index + 1 }
                else { offsets.append(index + 1) }
            } else if unit == 13 || unit == 0x2028 || unit == 0x2029 { offsets.append(index + 1) }
            previous = unit
        }
        return offsets
    }

    public static func index(at offset: Int, starts: [Int]) -> Int {
        var low = 0, high = starts.count
        while low < high {
            let mid = (low + high) / 2
            if starts[mid] <= offset { low = mid + 1 } else { high = mid }
        }
        return max(0, low - 1)
    }
}
