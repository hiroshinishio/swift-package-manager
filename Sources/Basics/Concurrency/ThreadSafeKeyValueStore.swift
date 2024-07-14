//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift open source project
//
// Copyright (c) 2020-2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import _Concurrency
import class Foundation.NSLock

/// Thread-safe dictionary with async memoization
public actor ThrowingAsyncKeyValueMemoizer<Key: Hashable & Sendable, Value: Sendable> {
    var stored: [Key: ValueStorage] = [:]

    public init() {
        self.stored = [:]
    }

    enum ValueStorage {
    case inProgress([CheckedContinuation<Value, Error>])
    case complete(Result<Value, Error>)
    }

    public func memoize(_ key: Key, body: @Sendable () async throws -> Value) async throws -> Value {
        guard let value = self.stored[key] else {
            self.stored[key] = .inProgress([])

            let result: Result<Value, Error>
            do {
                result = try await .success(body())
            } catch {
                result = .failure(error)
            }
            if case .inProgress(let array) = self.stored[key] {
                self.stored[key] = .complete(result)
                array.forEach { $0.resume(with: result)}
            }
            return try result.get()
        }

        switch value {

        case .inProgress(let existing):
            return try await withCheckedThrowingContinuation {
                self.stored[key] = .inProgress(existing + [$0])
            }
        case .complete(let result):
            return try result.get()
        }
    }
}

public actor AsyncKeyValueMemoizer<Key: Hashable & Sendable, Value: Sendable> {
    var stored: [Key: ValueStorage] = [:]

    public init() {
        self.stored = [:]
    }

    enum ValueStorage {
    case inProgress([CheckedContinuation<Value, Never>])
    case complete(Value)
    }

    public func memoize(_ key: Key, body: @Sendable () async -> Value) async -> Value {
        guard let value = self.stored[key] else {
            self.stored[key] = .inProgress([])

            let result = await body()
            if case .inProgress(let array) = self.stored[key] {
                self.stored[key] = .complete(result)
                array.forEach { $0.resume(returning: result)}
            }
            return result
        }

        switch value {

        case .inProgress(let existing):
            return await withCheckedContinuation {
                self.stored[key] = .inProgress(existing + [$0])
            }
        case .complete(let result):
            return result
        }
    }
}

public actor AsyncThrowingValueMemoizer<Value: Sendable> {
    var stored: ValueStorage?

    enum ValueStorage {
    case inProgress([CheckedContinuation<Value, Error>])
    case complete(Result<Value, Error>)
    }

    public init() {}

    public func memoize(body: @Sendable () async throws -> Value) async throws -> Value {
        guard let stored else {
            self.stored = .inProgress([])
            let result: Result<Value, Error>
            do {
                result = try await .success(body())
            } catch {
                result = .failure(error)
            }
            if case .inProgress(let array) = self.stored {
                self.stored = .complete(result)
                array.forEach { $0.resume(with: result)}
            }
            return try result.get()
        }
        switch stored {

        case .inProgress(let existing):
            return try await withCheckedThrowingContinuation {
                self.stored = .inProgress(existing + [$0])
            }
        case .complete(let result):
            return try result.get()
        }
    }
}



/// Thread-safe dictionary like structure
public final class ThreadSafeKeyValueStore<Key, Value> where Key: Hashable {
    private var underlying: [Key: Value]
    private let lock = NSLock()

    public init(_ seed: [Key: Value] = [:]) {
        self.underlying = seed
    }

    public func get() -> [Key: Value] {
        self.lock.withLock {
            self.underlying
        }
    }

    public subscript(key: Key) -> Value? {
        get {
            self.lock.withLock {
                self.underlying[key]
            }
        } set {
            self.lock.withLock {
                self.underlying[key] = newValue
            }
        }
    }

    @discardableResult
    public func memoize(_ key: Key, body: () throws -> Value) rethrows -> Value {
        try self.lock.withLock {
            try self.underlying.memoize(key: key, body: body)
        }
    }

    @discardableResult
    public func removeValue(forKey key: Key) -> Value? {
        self.lock.withLock {
            self.underlying.removeValue(forKey: key)
        }
    }

    @discardableResult
    public func clear() -> [Key: Value] {
        self.lock.withLock {
            let underlying = self.underlying
            self.underlying.removeAll()
            return underlying
        }
    }

    public var count: Int {
        self.lock.withLock {
            self.underlying.count
        }
    }

    public var isEmpty: Bool {
        self.lock.withLock {
            self.underlying.isEmpty
        }
    }

    public func contains(_ key: Key) -> Bool {
        self.lock.withLock {
            self.underlying.keys.contains(key)
        }
    }

    public func map<T>(_ transform: ((key: Key, value: Value)) throws -> T) rethrows -> [T] {
        try self.lock.withLock {
            try self.underlying.map(transform)
        }
    }

    public func mapValues<T>(_ transform: (Value) throws -> T) rethrows -> [Key: T] {
        try self.lock.withLock {
            try self.underlying.mapValues(transform)
        }
    }
}

extension ThreadSafeKeyValueStore: @unchecked Sendable where Key: Sendable, Value: Sendable {}
