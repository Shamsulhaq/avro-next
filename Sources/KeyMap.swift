import Foundation

/// Maps a typed character to riti's virtual key code (see riti/include/riti.h).
enum KeyMap {
    private static let table: [Character: UInt16] = {
        var t: [Character: UInt16] = [
            "`": 41, "~": 1, "!": 59, "@": 60, "#": 61, "$": 62, "%": 63, "^": 64,
            "&": 65, "*": 66, "(": 67, ")": 68, "_": 87, "+": 88, "-": 12, "=": 13,
            "[": 26, "]": 27, "\\": 43, "{": 91, "}": 92, "|": 93, ";": 39, "'": 40,
            ",": 51, ".": 52, "/": 53, ":": 99, "\"": 100, "<": 101, ">": 102, "?": 103,
            "1": 2, "2": 3, "3": 4, "4": 5, "5": 6, "6": 7, "7": 8, "8": 9, "9": 10, "0": 11,
        ]
        for (i, c) in "abcdefghijklmnopqrstuvwxyz".enumerated() {
            t[c] = UInt16(41110 + i)
            t[Character(c.uppercased())] = UInt16(41140 + i)
        }
        return t
    }()

    static func code(for character: Character) -> UInt16? { table[character] }
}
