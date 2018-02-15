//
//  Optics.swift
//  ChannelZ
//
//  Created by Marc Prud'hommeaux on 7/5/16.
//  Copyright © 2016 glimpse.io. All rights reserved.
//

// MARK: Lens Support


/// A van Laarhoven Lens type
public protocol LensType {
    associatedtype A
    associatedtype B

    func set(_ target: A, _ value: B) -> A

    func get(_ target: A) -> B

}

public extension LensType {
    /// Converts this lens to an optional prism that allows lossy getting/setting of optional values
    ///
    /// - See Also: `ChannelType.prism`
    public var prism : Lens<A?, B?> {
        return Lens<A?, B?>(get: { $0.flatMap(self.get) }, create: { (whole, part) in
            if let whole = whole, let part = part {
                return self.set(whole, part)
            } else {
                return whole
            }
        })
    }

    /// Maps this lens to a new lens with the given pair of recripocal functions.
    public func map<C>(_ getmap: @escaping (B) -> C, _ setmap: @escaping (C) -> B) -> Lens<A, C> {
        return Lens(get: { getmap(self.get($0)) }, create: { self.set($0, setmap($1)) })
    }
}

public extension LensType where B : _OptionalType {

    /// Maps this lens to a new lens with the given pair of recripocal functions that operate on optional types.
    public func flatMap<C>(_ getmap: @escaping (B.Wrapped) -> C, _ setmap: @escaping (C) -> B.Wrapped) -> Lens<A, C?> {
        return Lens(get: { a in self.get(a).flatMap(getmap) }, create: { a, c in self.set(a, c.flatMap(setmap).map(B.init) ?? nil) })
    }
}

/// A lens provides the ability to access and modify a sub-element of an immutable data structure.
/// Optics composition in Swift is somewhat limited due to the lack of Higher Kinded Types, but
/// they can be used to great effect with a state channel in order to provide owner access and
/// conditional creation for complex immutable state structures.
///
/// See Also: https://github.com/apple/swift/blob/master/docs/GenericsManifesto.md#higher-kinded-types
public struct Lens<A, B> : LensType {
    private let getter: (A) -> B
    private let setter: (A, B) -> A

    public init(get: @escaping (A) -> B, create: @escaping (A, B) -> A) {
        self.getter = get
        self.setter = create
    }

    public init(get: @escaping (A) -> B, set: @escaping (inout A, B) -> ()) {
        self.getter = get
        self.setter = { var copy = $0; set(&copy, $1); return copy }
    }

    public init(kp: WritableKeyPath<A, B>) {
        self.getter = { $0[keyPath: kp] }
        self.setter = { var copy = $0; copy[keyPath: kp] = $1; return copy }
    }

    public func set(_ target: A, _ value: B) -> A {
        return setter(target, value)
    }

    public func get(_ target: A) -> B {
        return getter(target)
    }
}

/// A `Focusable` instance is able focus on individual properties of the model
public protocol Focusable {
}

public extension Focusable {
    /// Takes a setter & getter for a property of this instance and returns a lens than encapsulates the action
    public static func lenZ<T>(_ get: @escaping (Self) -> T, _ set: @escaping (inout Self, T) -> Void) -> Lens<Self, T> {
        return Lens(get: get, set: set)
    }
    
    /// Takes a writeable keypath for a property of this instance and returns a lens than encapsulates the action
    public static func lenZ<T>(_ kp: WritableKeyPath<Self, T>) -> Lens<Self, T> {
        return Lens(kp: kp)
    }
}


public protocol LensSourceType : TransceiverType {
    associatedtype Owner : ChannelType

    /// All lens channels have an owner that is itself a TransceiverType
    var channel: Owner { get }
}

/// A Lens on a state channel, which can be used create a property channel on a specific
/// piece of the source state; a LensSource itself does not manage any receivers, but instead
/// relies on the source of the underlying channel.
///
/// The associated lens is used both for getting/setting the source state directly as well
/// as modifying the old/new state pulse values. A lens can be thought of as a 2-way `map` for state values.
public struct LensSource<C: ChannelType, T>: LensSourceType where C.Source : TransceiverType, C.Pulse : MutationType, C.Pulse.Value == C.Source.Value {
    public typealias Owner = C
    public let channel: C
    public let lens: Lens<C.Source.Value, T>

    public func receive(_ x: T) {
        self.value = x
    }

    public var value: T {
        get { return lens.get(channel.value) }
        nonmutating set { channel.value = lens.set(channel.value, newValue) }
    }

    /// Creates a state tranceiver to the focus of this lens, allowing the access and modification
    /// of a subset of a product type.
    public func transceive() -> LensChannel<C, T> {
        return channel.map({ pulse in
            Mutation(old: pulse.old.flatMap(self.lens.get), new: self.lens.get(pulse.new))
        }).resource({ _ in self })
    }
}

/// A `LensChannel` simplifies the type of a channel over a mutating LensSource
public typealias LensChannel<C: ChannelType, X> = Channel<LensSource<C, X>, Mutation<X>> where C.Source : TransceiverType, C.Pulse : MutationType, C.Pulse.Value == C.Source.Value

public extension ChannelType where Source : TransceiverType, Pulse : MutationType, Pulse.Value == Source.Value {
    /// A channel that focused from the current channel through to the given pulse type
    public typealias FocusChannel<X> = LensChannel<Self, X>
}

/// A Prism on a state channel, which can be used create a property channel on a specific
/// piece of the source state; a LensSource itself does not manage any receivers, but instead
/// relies on the source of the underlying channel.
public struct PrismSource<C: ChannelType, T>: LensSourceType where C.Source : TransceiverType, C.Pulse : MutationType, C.Pulse.Value == C.Source.Value {
    public typealias Owner = C
    public let channel: C
    public let lens: Lens<C.Source.Value, T>
    public typealias Pulse = T

    public func receive(_ x: T) {
        self.value = x
    }

    public var value: T {
        get { return lens.get(channel.value) }
        nonmutating set { channel.value = lens.set(channel.value, newValue) }
    }

    /// Creates a state tranceiver to the focus of this lens, allowing the access and modification
    /// of a subset of a product type.
    public func transceive() -> Channel<PrismSource, Mutation<T>> {
        return channel.map({ pulse in
            Mutation(old: pulse.old.flatMap(self.lens.get), new: self.lens.get(pulse.new))
        }).resource({ _ in self })
    }
}

public extension ChannelType where Source : TransceiverType, Pulse : MutationType, Pulse.Value == Source.Value {

    /// A pure channel (whose element is the same as the source) can be lensed such that a derivative
    /// channel can modify sub-elements of a complex data structure
    public func focus<X>(lens: Lens<Pulse.Value, X>) -> FocusChannel<X> {
        return LensSource(channel: self, lens: lens).transceive()
    }

    /// Constructs a Lens channel using a getter and an inout setter
    public func focus<X>(_ kp: WritableKeyPath<Pulse.Value, X>) -> FocusChannel<X> {
        return focus(lens: Lens(kp: kp))
    }

    /// Constructs a Lens channel using a getter and an inout setter
    public func focus<X>(get: @escaping (Pulse.Value) -> X, set: @escaping (inout Pulse.Value, X) -> ()) -> FocusChannel<X> {
        return focus(lens: Lens(get: get, set: set))
    }

//    public func focuz<X>(_ get: @escaping (Value) -> X) -> (_ set: @escaping (inout Value, X) -> ()) -> FocusChannel<X> {
//        return { self.focus(lens: Lens(get, $0)) }
//    }

    /// Constructs a Lens channel using a getter and a tranformation setter
    public func focus<X>(get: @escaping (Pulse.Value) -> X, create: @escaping (Pulse.Value, X) -> Pulse.Value) -> FocusChannel<X> {
        return focus(lens: Lens(get: get, create: create))
    }
}

public extension ChannelType where Source : TransceiverType, Pulse : MutationType, Pulse.Value == Source.Value {

    /// Creates an optionally casting prism focus
    public func cast<T>(_ type: T.Type) -> FocusChannel<T?> {
        let optionalLens = Lens<Pulse.Value, T?>(get: { $0 as? T }, set: { (x: inout Pulse.Value, y: T?) in
            if let z = y as? Pulse.Value {
                x = z
            }
        })
        return focus(lens: optionalLens)
    }

}

public extension ChannelType where Source : LensSourceType {
    /// Simple alias for `source.channel.source`; useful for ascending a lens ownership hierarchy
    public var owner: Source.Owner { return source.channel }
}

// MARK: Jacket Channel extensions for Lens/Prism/Optional access

public extension ChannelType where Source.Value : _WrapperType, Source : TransceiverType, Pulse : MutationType, Pulse.Value == Source.Value {

    /// Converts an optional state channel into a non-optional one by replacing nil elements
    /// with the result of the constructor function
    public func coalesce(_ template: @escaping (Self) -> Pulse.Value.Wrapped) -> FocusChannel<Pulse.Value.Wrapped> {
        return focus(get: { $0.flatMap({ $0 }) ?? template(self) }, create: { (_, value) in Source.Value(value) })
    }

    /// Converts an optional state channel into a non-optional one by replacing nil elements
    /// with the constant of the value; alias for `coalesce`
    public func coalesce(_ value: Pulse.Value.Wrapped) -> FocusChannel<Pulse.Value.Wrapped> {
        return coalesce({ _ in value })
    }
}

public extension ChannelType where Source : TransceiverType, Pulse : MutationType, Pulse.Value == Source.Value {

    /// Given two channels that can find and update values based on the specified getters & updaters, create
    /// a `Transceiver` channel that provides access to the underlying merged elements.
    public func join<T, Join: ChannelType>(_ locator: Join, finder: @escaping (Self.Pulse.Value, Join.Pulse.Value) -> T, updater: @escaping ((Self.Pulse.Value, Join.Pulse.Value), T) -> (Self.Pulse.Value, Join.Pulse.Value)) -> FocusChannel<T> where Join.Source : StateEmitterType, Join.Pulse : MutationType, Join.Pulse.Value == Join.Source.Value {

        // the selection lens value is a prism over the current selection and the current elements
        let lens = Lens<Pulse.Value, T>(get: { elements in
            finder(elements, locator.source.value)
        }) { (elements, values) in
            updater((elements, locator.source.value), values).0
        }

        let sel = focus(lens: lens)

        return sel.either(locator).resource({ $0.0 }).map {
            switch $0 {
            case .v1(let v): // change in elements
                return v // the raw values are already resolved by the lens
            case .v2(let i): // change in locator; need to perform another lookup
                return Mutation(old: i.old.flatMap({ finder(self.source.value, $0) }), new: finder(self.source.value, i.new))
            }
        }
    }
}

public extension ChannelType where Source.Value : RangeReplaceableCollection, Source : TransceiverType, Pulse : MutationType, Pulse.Value == Source.Value {

    /// Combines this sequence state source with a channel of indices and combines them into a prism
    /// where the subselection will be issued whenever a change in either the selection or the underlying
    /// elements occurs; indices that are invalid or become invalid will be silently ignored.
    public func match<Join: ChannelType>(_ locator: Join, setter: @escaping (Pulse.Value, Pulse.Value.Index, Pulse.Value.Element?) -> Pulse.Value, getter: @escaping (Pulse.Value, Pulse.Value.Index) -> Pulse.Value.Element?) -> FocusChannel<Pulse.Value> where Join.Source : StateEmitterType, Join.Pulse.Value : Sequence, Join.Pulse.Value.Element == Pulse.Value.Index, Join.Pulse : MutationType, Join.Pulse.Value == Join.Source.Value {

        typealias Output = Pulse.Value
        typealias Query = (input: Pulse.Value, indices: Join.Pulse.Value)

        func query(_ query: Query) -> Output {
            var elements = Output()
            for index in query.indices {
                if let value = getter(query.input, index) {
                    elements.append(value)
                }
            }
            // assert(elements.count == Array(query.indices).count)
            return elements
        }

        func update(_ query: Query, output: Output) -> Query {
            // assert(output.count == Array(query.indices).count)
            var updated = query.input
            for (index, element) in Swift.zip(query.indices, output) {
                updated = setter(updated, index, element)
            }
            return (updated, query.indices)
        }

        return join(locator, finder: { query(($0, $1)) }, updater: update)
    }

    /// Combines this collection state source with a channel of indices and combines them into a prism
    /// where the subselection will be issued whenever a change in either the selection or the underlying
    /// elements occurs; indices that are invalid or become invalid will be silently ignored.
    public func subselect<C: ChannelType>(_ locator: C, setter: @escaping (Pulse.Value, Pulse.Value.Index, Pulse.Value.Element?) -> Pulse.Value) -> FocusChannel<Pulse.Value> where C.Source : StateEmitterType, C.Pulse.Value : Sequence, C.Pulse.Value.Element == Pulse.Value.Index, C.Pulse : MutationType, C.Pulse.Value == C.Source.Value {

        return match(locator, setter: setter) { collection, index in
            if collection.indices.contains(index) {
                return collection[index]
            } else {
                return nil
            }
        }
    }
    
    /// Combines this collection state source with a channel of indices and combines them into a prism
    /// where the subselection will be issued whenever a change in either the selection or the underlying
    /// elements occurs; indices that are invalid or become invalid will be silently ignored.
    public func indices<C: ChannelType>(_ indices: C) -> FocusChannel<Pulse.Value> where C.Source : StateEmitterType, C.Source.Value : Sequence, C.Source.Value.Element == Source.Value.Index, C.Pulse : MutationType, C.Pulse.Value == C.Source.Value {
        return subselect(indices) { (seq, idx, val) in
            if seq.indices.contains(idx) {
                var s = seq
                s.replaceSubrange(idx...idx, with: CollectionOfOne(val).flatMap({ $0 }))
                return s
            } else {
                return seq
            }
        }
    }
    
    /// Combines this collection state source with a channel of a single index and combines them into a prism
    /// where the subselection will be issued whenever a change in either the selection or the underlying
    /// elements occurs; indices that are invalid or become invalid will be silently ignored.
    public func index<C: ChannelType>(_ index: C) -> LensChannel<FocusChannel<Pulse.Value>, Pulse.Value.Element?> where C.Source : TransceiverType, C.Pulse : MutationType, C.Source.Value == C.Pulse.Value, C.Source.Value == Source.Value.Index? {
        
        // TODO: this should return FocusChannel<Value.Element?> instead of LensChannel<FocusChannel<Self.Pulse.Value>, Self.Pulse.Value.Element?>, but since we are relying on the indices function for the subselection implementation, we need to have an extra level of indirection. For example, an integer indexed indexOf currently returns:
        //   Channel<LensSource<Channel<LensSource<Channel<ValueTransceiver<[String]>, Mutation<[String]>>, [String]>, Mutation<[String]>>, String?>, Mutation<String?>>
        // but it should just return:
        //   Channel<LensSource<Channel<ValueTransceiver<[String]>, Mutation<[String]>>, [String]>, Mutation<[String]>>
        
        // optional channel -> collection channel
        let idx: C.FocusChannel<[Source.Value.Index]> = index.focus(get: { v in v.flatMap({ [$0] }) ?? [] }, set: { v, c in v = c.first ?? .none })
        
        let ichan: FocusChannel<Pulse.Value> = self.indices(idx)
        
        // collection channel -> optional channel
        let fchan: LensChannel<FocusChannel<Pulse.Value>, Pulse.Value.Element?> = ichan.focus(get: { c in c.first ?? .none }, set: { c, v in
            c.replaceSubrange(c.startIndex..<c.endIndex, with: v.flatMap({ [$0] }) ?? [])
        })
        
        return fchan
    }
    
    
    /// Creates a channel to the underlying collection type where the channel creates an optional
    /// to a given static index; setting to nil removes the index, and setting to a certain value
    /// sets the index
    ///
    /// - Note: When setting the value of an index outside the current indices, any
    ///         intervening gaps will be filled with the duplicated value
    public func indexOf(_ index: Pulse.Value.Index) -> FocusChannel<Pulse.Value.Element?> {
        
        let lens: Lens<Pulse.Value, Pulse.Value.Element?> = Lens(get: { target in
            target.indices.contains(index) ? target[index] : nil
        }, create: { (target, item) in
            var target = target
            if let item = item {
                while !target.indices.contains(index) {
                    // fill in the gaps
                    target.append(item)
                }
                // set the target index item
                target.replaceSubrange(index...index, with: [item])
            } else {
                if target.indices.contains(index) {
                    target.remove(at: index)
                }
            }
            return target
        })
        
        return focus(lens: lens)
    }
    
    /// Creates a prism lens channel, allowing access to a collection's mapped lens
    public func prism<T>(_ lens: Lens<Pulse.Value.Element, T>) -> FocusChannel<[T]> {
        let prismLens = Lens<Pulse.Value, [T]>(get: { $0.map(lens.get) }) {
            (elements: inout Pulse.Value, values: [T]) in
            var vals = values.makeIterator()
            for i in elements.indices {
                if let val = vals.next() {
                    elements.replaceSubrange(i...i, with: [lens.set(elements[i], val)])
                }
            }
        }
        return focus(lens: prismLens)
    }
    
    /// Creates a prism lens channel from the given keypath, allowing access to a collection's mapped lens
    public func prism<T>(_ kp: WritableKeyPath<Pulse.Value.Element, T>) -> FocusChannel<[T]> {
        return prism(Lens(kp: kp))
    }
    
    /// Returns an accessor to the collection's range of elements
    public func range(_ range: ClosedRange<Pulse.Value.Index>) -> FocusChannel<Pulse.Value.SubSequence> {
        let rangeLens = Lens<Pulse.Value, Pulse.Value.SubSequence>(get: { $0[range] }) {
            (elements: inout Pulse.Value, values: Pulse.Value.SubSequence) in
            elements.replaceSubrange(range, with: Array(values))
        }
        return focus(lens: rangeLens)
    }
}

public extension ChannelType where Source.Value : MutableCollection, Source : TransceiverType, Pulse : MutationType, Pulse.Value == Source.Value {

    /// Combines this collection state source with a channel of indices and combines them into a prism
    /// where the subselection will be issued whenever a change in either the selection or the underlying
    /// elements occurs; indices that are invalid or become invalid will be silently ignored.
    /// Array elements cannot be removed, so updated with a mismatched number of indices will be ignored.
//    public func fixed<C: ChannelType>(_ indices: C) -> FocusChannel<[Self.Value.Element]> where C.Source : StateEmitterType, C.Value : Sequence, C.Value.Element == Value.Index, C.Pulse : MutationType, C.Value == C.Value {
//        return subselect(indices) { (seq, idx, val) in
//            var seq = seq
//            if let val = val, seq.indices.contains(idx) {
//                seq[idx] = val // FIXME: what to do with missing values?
//            }
//            return seq
//        }
//    }
}

@available(*, deprecated, message: "crashes always!")
func todo<T>() -> T { fatalError("TODO: \(T.self)") }

public extension ChannelType where Source.Value : KeyIndexed & Collection, Source.Value.Index : KeyIndexedIndexType, Source.Value.Key == Source.Value.Index.Key, Source.Value.Value == Source.Value.Index.Value, Source : TransceiverType, Pulse : MutationType, Pulse.Value == Source.Value {

    /// Combines this collection state source with a channel of indices and combines them into a prism
    /// where the subselection will be issued whenever a change in either the selection or the underlying
    /// elements occurs; indices that are invalid or become invalid will be represented by nil in the
    /// pulsed collection; nulling out individual members of existant keys will have no effect.
    public func keyed<S: Sequence>(_ indices: TransceiverChannel<S>) -> FocusChannel<[Pulse.Value.Value?]> where S.Iterator.Element == Pulse.Value.Key {

        return join(indices, finder: { dict, keys in
            var values: [Pulse.Value.Value?] = []
            for key in keys {
                values.append(dict[key])
            }
            return values
            }, updater: { dkeys, values in
                var dict = dkeys.0
                for (key, value) in Swift.zip(dkeys.1, values) {
                    dict[key] = value
                }
                return (dict, dkeys.1)
        })
    }
}


/// Bogus protocol since, unlike Array -> CollectionType, Dictionary doesn't have any protocol.
/// Exists merely for the `ChannelType.at` prism.
public protocol KeyIndexed {
    associatedtype Key : Hashable
    associatedtype Value
    subscript (key: Key) -> Value? { get set }
}

extension Dictionary : KeyIndexed {
}

public protocol KeyIndexedIndexType : Comparable {
    associatedtype Key : Hashable
    associatedtype Value

    /// This function is a side-effect of the inability to adopt a protocol and conform
    /// to same-named associatedtypes unless there is a function returning the values.
    func __this() -> DictionaryIndex<Key, Value>
}

extension DictionaryIndex : KeyIndexedIndexType {

    public func __this() -> DictionaryIndex<Key, Value> {
        return self
    }

}

public extension ChannelType where Source.Value : KeyIndexed, Source : TransceiverType, Pulse : MutationType, Pulse.Value == Source.Value {
    /// Creates a state channel to the given key in the underlying `KeyIndexed` dictionary
    public func atKey(_ key: Pulse.Value.Key) -> FocusChannel<Pulse.Value.Value?> {

        let lens: Lens<Pulse.Value, Pulse.Value.Value?> = Lens(get: { target in
            target[key]
            }, create: { (target, item) in
                var target = target
                target[key] = item
                return target
        })

        return focus(lens: lens)
    }

//    /// Combines this collection state source with a channel of indices and combines them into a prism
//    /// where the subselection will be issued whenever a change in either the selection or the underlying
//    /// elements occurs; indices that are invalid or become invalid will be silently ignored.
//    public func sub<C: ChannelType>(_ index: C) -> FocusChannel<[Value.Value]> where C.Source : TransceiverType, C.Pulse : MutationType, C.Source.Value == C.Pulse.Value, C.Source.Value == [Source.Value.Key] {
//        return todo()
//    }
//
//    /// Combines this collection state source with a channel of indices and combines them into a prism
//    /// where the subselection will be issued whenever a change in either the selection or the underlying
//    /// elements occurs; indices that are invalid or become invalid will be silently ignored.
//    public func at<C: ChannelType>(_ index: C) -> FocusChannel<Value.Value?> where C.Source : TransceiverType, C.Pulse : MutationType, C.Source.Value == C.Pulse.Value, C.Source.Value == Source.Value.Key? {
//
////        return sub.focus(lens: Lens(get: { _ in todo() }, set: { _, _ in todo() }))
//
//        // TODO: this should return FocusChannel<Value.Element?> instead of LensChannel<FocusChannel<Self.Pulse.Value>, Self.Pulse.Value.Element?>, but since we are relying on the indices function for the subselection implementation, we need to have an extra level of indirection. For example, an integer indexed indexOf currently returns:
//        //   Channel<LensSource<Channel<LensSource<Channel<ValueTransceiver<[String]>, Mutation<[String]>>, [String]>, Mutation<[String]>>, String?>, Mutation<String?>>
//        // but it should just return:
//        //   Channel<LensSource<Channel<ValueTransceiver<[String]>, Mutation<[String]>>, [String]>, Mutation<[String]>>
//
////        // optional channel -> collection channel
////        let idx: C.FocusChannel<[Source.Value.Index]> = index.focus(get: { v in v.flatMap({ [$0] }) ?? [] }, set: { v, c in v = c.first ?? .none })
////
////        let ichan: FocusChannel<Value> = self.indices(idx)
////
////        // collection channel -> optional channel
////        let fchan: LensChannel<FocusChannel<Value>, Value.Element?> = ichan.focus(get: { c in c.first ?? .none }, set: { c, v in
////            c.replaceSubrange(c.startIndex..<c.endIndex, with: v.flatMap({ [$0] }) ?? [])
////        })
////
////        return fchan
//
//        return todo()
//    }

}

public protocol Optical : class {
    associatedtype T: ChannelType where T.Source : TransceiverType, T.Pulse : MutationType, T.Pulse.Value == T.Source.Value
    
    var optic: T { get }
    
    init(_ optical: T)
}

public extension ChannelType where Source.Value : Choose1Type, Source : TransceiverType, Pulse : MutationType, Pulse.Value == Source.Value {
    /// Channel for the first option of N choices
    public var v1Z: FocusChannel<Pulse.Value.T1?> {
        return focus(get: { (x: Pulse.Value) in x.v1 }, set: { (x: inout Pulse.Value, y: Pulse.Value.T1?) in x.v1 = y })
    }
}

public extension ChannelType where Source.Value : Choose2Type, Source : TransceiverType, Pulse : MutationType, Pulse.Value == Source.Value {
    /// Channel for the second option of N choices
    public var v2Z: FocusChannel<Pulse.Value.T2?> {
        return focus(get: { $0.v2 }, set: { (x: inout Pulse.Value, y: Pulse.Value.T2?) in x.v2 = y })
    }
}

public extension ChannelType where Source.Value : Choose3Type, Source : TransceiverType, Pulse : MutationType, Pulse.Value == Source.Value {
    /// Channel for the third option of N choices
    public var v3Z: FocusChannel<Pulse.Value.T3?> {
        return focus(get: { $0.v3 }, set: { (x: inout Pulse.Value, y: Pulse.Value.T3?) in x.v3 = y })
    }
}

public extension ChannelType where Source.Value : Choose4Type, Source : TransceiverType, Pulse : MutationType, Pulse.Value == Source.Value {
    /// Channel for the fourth option of N choices
    public var v4Z: FocusChannel<Pulse.Value.T4?> {
        return focus(get: { $0.v4 }, set: { (x: inout Pulse.Value, y: Pulse.Value.T4?) in x.v4 = y })
    }
}

public extension ChannelType where Source.Value : Choose5Type, Source : TransceiverType, Pulse : MutationType, Pulse.Value == Source.Value {
    /// Channel for the fifth option of N choices
    public var v5Z: FocusChannel<Pulse.Value.T5?> {
        return focus(get: { $0.v5 }, set: { (x: inout Pulse.Value, y: Pulse.Value.T5?) in x.v5 = y })
    }
}

public extension ChannelType where Source.Value : Choose6Type, Source : TransceiverType, Pulse : MutationType, Pulse.Value == Source.Value {
    /// Channel for the sixth option of N choices
    public var v6Z: FocusChannel<Pulse.Value.T6?> {
        return focus(get: { $0.v6 }, set: { (x: inout Pulse.Value, y: Pulse.Value.T6?) in x.v6 = y })
    }
}

public extension ChannelType where Source.Value : Choose7Type, Source : TransceiverType, Pulse : MutationType, Pulse.Value == Source.Value {
    /// Channel for the seventh option of N choices
    public var v7Z: FocusChannel<Pulse.Value.T7?> {
        return focus(get: { $0.v7 }, set: { (x: inout Pulse.Value, y: Pulse.Value.T7?) in x.v7 = y })
    }
}

public extension ChannelType where Source.Value : Choose8Type, Source : TransceiverType, Pulse : MutationType, Pulse.Value == Source.Value {
    /// Channel for the eighth option of N choices
    public var v8Z: FocusChannel<Pulse.Value.T8?> {
        return focus(get: { $0.v8 }, set: { (x: inout Pulse.Value, y: Pulse.Value.T8?) in x.v8 = y })
    }
}

public extension ChannelType where Source.Value : Choose9Type, Source : TransceiverType, Pulse : MutationType, Pulse.Value == Source.Value {
    /// Channel for the ninth option of N choices
    public var v9Z: FocusChannel<Pulse.Value.T9?> {
        return focus(get: { $0.v9 }, set: { (x: inout Pulse.Value, y: Pulse.Value.T9?) in x.v9 = y })
    }
}

public extension ChannelType where Source.Value : Choose10Type, Source : TransceiverType, Pulse : MutationType, Pulse.Value == Source.Value {
    /// Channel for the tenth option of N choices
    public var v10Z: FocusChannel<Pulse.Value.T10?> {
        return focus(get: { $0.v10 }, set: { (x: inout Pulse.Value, y: Pulse.Value.T10?) in x.v10 = y })
    }
}

public extension ChannelType where Source.Value : Choose11Type, Source : TransceiverType, Pulse : MutationType, Pulse.Value == Source.Value {
    /// Channel for the eleventh option of N choices
    public var v11Z: FocusChannel<Pulse.Value.T11?> {
        return focus(get: { $0.v11 }, set: { (x: inout Pulse.Value, y: Pulse.Value.T11?) in x.v11 = y })
    }
}

public extension ChannelType where Source.Value : Choose12Type, Source : TransceiverType, Pulse : MutationType, Pulse.Value == Source.Value {
    /// Channel for the twelfth option of N choices
    public var v12Z: FocusChannel<Pulse.Value.T12?> {
        return focus(get: { $0.v12 }, set: { (x: inout Pulse.Value, y: Pulse.Value.T12?) in x.v12 = y })
    }
}

public extension ChannelType where Source.Value : Choose13Type, Source : TransceiverType, Pulse : MutationType, Pulse.Value == Source.Value {
    /// Channel for the thirteenth option of N choices
    public var v13Z: FocusChannel<Pulse.Value.T13?> {
        return focus(get: { $0.v13 }, set: { (x: inout Pulse.Value, y: Pulse.Value.T13?) in x.v13 = y })
    }
}

public extension ChannelType where Source.Value : Choose14Type, Source : TransceiverType, Pulse : MutationType, Pulse.Value == Source.Value {
    /// Channel for the fourteenth option of N choices
    public var v14Z: FocusChannel<Pulse.Value.T14?> {
        return focus(get: { $0.v14 }, set: { (x: inout Pulse.Value, y: Pulse.Value.T14?) in x.v14 = y })
    }
}

public extension ChannelType where Source.Value : Choose15Type, Source : TransceiverType, Pulse : MutationType, Pulse.Value == Source.Value {
    /// Channel for the fifteenth option of N choices
    public var v15Z: FocusChannel<Pulse.Value.T15?> {
        return focus(get: { $0.v15 }, set: { (x: inout Pulse.Value, y: Pulse.Value.T15?) in x.v15 = y })
    }
}

public extension ChannelType where Source.Value : Choose16Type, Source : TransceiverType, Pulse : MutationType, Pulse.Value == Source.Value {
    /// Channel for the sixteenth option of N choices
    public var v16Z: FocusChannel<Pulse.Value.T16?> {
        return focus(get: { $0.v16 }, set: { (x: inout Pulse.Value, y: Pulse.Value.T16?) in x.v16 = y })
    }
}

public extension ChannelType where Source.Value : Choose17Type, Source : TransceiverType, Pulse : MutationType, Pulse.Value == Source.Value {
    /// Channel for the seventeenth option of N choices
    public var v17Z: FocusChannel<Pulse.Value.T17?> {
        return focus(get: { $0.v17 }, set: { (x: inout Pulse.Value, y: Pulse.Value.T17?) in x.v17 = y })
    }
}

public extension ChannelType where Source.Value : Choose18Type, Source : TransceiverType, Pulse : MutationType, Pulse.Value == Source.Value {
    /// Channel for the eighteenth option of N choices
    public var v18Z: FocusChannel<Pulse.Value.T18?> {
        return focus(get: { $0.v18 }, set: { (x: inout Pulse.Value, y: Pulse.Value.T18?) in x.v18 = y })
    }
}

public extension ChannelType where Source.Value : Choose19Type, Source : TransceiverType, Pulse : MutationType, Pulse.Value == Source.Value {
    /// Channel for the nineteenth option of N choices
    public var v19Z: FocusChannel<Pulse.Value.T19?> {
        return focus(get: { $0.v19 }, set: { (x: inout Pulse.Value, y: Pulse.Value.T19?) in x.v19 = y })
    }
}

public extension ChannelType where Source.Value : Choose20Type, Source : TransceiverType, Pulse : MutationType, Pulse.Value == Source.Value {
    /// Channel for the twentieth option of N choices
    public var v20Z: FocusChannel<Pulse.Value.T20?> {
        return focus(get: { $0.v20 }, set: { (x: inout Pulse.Value, y: Pulse.Value.T20?) in x.v20 = y })
    }
}
