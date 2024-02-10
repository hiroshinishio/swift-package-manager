//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift open source project
//
// Copyright (c) 2014-2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import TSCLibc
#if os(Windows)
import CRT
#endif

import protocol TSCBasic.WritableByteStream
import enum TSCBasic.ProcessEnv

/// A class to have better control on tty output streams: standard output and
/// standard error.
///
/// Allows operations like cursor movement and colored text output on tty.
final class Terminal {
    /// Pointer to output stream to operate on.
    var stream: WritableByteStream

    init(stream: WritableByteStream) {
        self.stream = stream
        Self.enableVT100Interpretation()
    }
}

extension Terminal {
    /// Width of the terminal.
    var width: Int {
        // Determine the terminal width otherwise assume a default.
        if let terminalWidth = Terminal.terminalWidth(), terminalWidth > 0 {
            return terminalWidth
        } else {
            return 80
        }
    }

    static func enableVT100Interpretation() {
#if os(Windows)
        let hOut = GetStdHandle(STD_OUTPUT_HANDLE)
        var dwMode: DWORD = 0

        guard hOut != INVALID_HANDLE_VALUE else { return nil }
        guard GetConsoleMode(hOut, &dwMode) else { return nil }

        dwMode |= DWORD(ENABLE_VIRTUAL_TERMINAL_PROCESSING)
        guard SetConsoleMode(hOut, dwMode) else { return nil }
#endif
    }

    /// Tries to get the terminal width first using COLUMNS env variable and
    /// if that fails ioctl method testing on stdout stream.
    ///
    /// - Returns: Current width of terminal if it was determinable.
    static func terminalWidth() -> Int? {
#if os(Windows)
        var csbi: CONSOLE_SCREEN_BUFFER_INFO = CONSOLE_SCREEN_BUFFER_INFO()
        if !GetConsoleScreenBufferInfo(GetStdHandle(STD_OUTPUT_HANDLE), &csbi) {
          // GetLastError()
          return nil
        }
        return Int(csbi.srWindow.Right - csbi.srWindow.Left) + 1
#else
        // Try to get from environment.
        if let columns = ProcessEnv.block["COLUMNS"], let width = Int(columns) {
            return width
        }

        // Try determining using ioctl.
        // Following code does not compile on ppc64le well. TIOCGWINSZ is
        // defined in system ioctl.h file which needs to be used. This is
        // a temporary arrangement and needs to be fixed.
#if !arch(powerpc64le)
        var ws = winsize()
#if os(OpenBSD)
        let tiocgwinsz = 0x40087468
        let err = ioctl(1, UInt(tiocgwinsz), &ws)
#else
        let err = ioctl(1, UInt(TIOCGWINSZ), &ws)
#endif
        if err == 0 {
            return Int(ws.ws_col)
        }
#endif
        return nil
#endif
    }
}
