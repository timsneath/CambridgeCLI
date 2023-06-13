//
//  main.swift
//  CambridgeCLI
//
// Runs the ZEXDOC and ZEXALL test suites.
//
//  Created by Tim Sneath on 6/12/23.
//

import Foundation
import z80

let cpuSpeed = 3500000 // Zilog Z80A used in ZX Spectrum clocked at 3.5MHz
let cyclesPerStep = cpuSpeed / 50
let maxStringLength = 100

var isDone: Bool = false

/// The test suite uses two CP/M BDOS calls, which we emulate here. Per
/// https://www.seasip.info/Cpm/bdos.html, to make a CP/M system call, you load C
/// with the chosen function, DE with a parameter, and then CALL 5.
///
/// The function that is set below calls IN, which is trapped by this function.
/// - function 2: print ASCII character in E to screen
/// - function 9: print dollar-terminated string pointed to by DE to screen

func emulate(_ file: URL) {
    var total = 0

    print("Testing \(file.lastPathComponent)...")

    // Load file into memory, starting at 0x100
    z80.pc = 0x100
    guard let data = try? Data(contentsOf: file) else {
        return
    }
    data.forEach {
        z80.memory.writeByte(z80.pc, $0)
        z80.pc += 1
    }
    z80.pc = 0x100

    // Patch memory locations to handle CP/M BDOS calls.
    // Reset at 0x0000 (RST 0h) is trapped by an OUT which will stop emulation.
    // CALL 5 is trapped by an IN.
    z80.memory.writeByte(0, 0xd3) /* OUT (00h), A */
    z80.memory.writeByte(1, 0x00)

    z80.memory.writeByte(5, 0xdb) /* IN A, (00h) */
    z80.memory.writeByte(6, 0x00)
    z80.memory.writeByte(7, 0xc9) /* RET */

    // First member of ZEXTEST is state, so this is safe.
    repeat {
        _ = z80.executeNextInstruction()
        total += 1
    } while !isDone
    print("\n\(total) cycle(s) emulated.\n" +
        "For a Z80 running at \(cpuSpeed / 1000000)MHz, " +
        "that would be \(total / cpuSpeed) seconds " +
        "or \(total / (3600 * cpuSpeed)) hour(s).")
}

func portRead(_ port: UInt16) -> UInt8 {
    switch z80.c {
        case 2:
            print(String(bytes: [z80.e], encoding: .ascii) ?? "", terminator: "")
            return 0
        case 9:
            var charCount = 0
            var addr = z80.de
            do {
                addr += 1
                let char = String(bytes: [z80.memory.readByte(addr)], encoding: .ascii) ?? " "
                if char == "$" || charCount >= maxStringLength { break }
                charCount += 1
                print(char, terminator: "")
            }

            return 0
        default:
            return 0
    }
    return 0
}

func portWrite(_ addr: UInt16, _ value: UInt8) {
    isDone = true
}

print("Hello, World!")
var z80 = Z80(portRead: portRead, portWrite: portWrite)
let file = URL(filePath: "/Users/timsneath/src/swift/CambridgeCLI/CambridgeCLI/zex/zexdoc.z80")
let start = Date()
emulate(file)
let stop = Date()
let duration = stop.timeIntervalSince(start)
print("Emulating zexdoc took a total of \(duration.rounded()) seconds")
