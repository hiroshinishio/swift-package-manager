//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

struct ProgressAdapter {
    var rootTask: ProgressTask
//    var animation: any ProgressAnimationProtocol3

    /// Update the animation with a new event.
    func update(
        id: Int,
        name: String,
        event: ProgressTaskState,
        at time: ContinuousClock.Instant
    ) {

    }

    /// Complete the animation.
    func complete() {
        // self.animation.complete(state: self.state)
    }

    // FIXME: Remove
    /// Draw the animation.
    func draw() {
        // self.animation.draw(state: self.state)
    }

    // FIXME: Remove
    /// Clear the animation.
    func clear() {
        // self.animation.clear(state: self.state)
    }
}
