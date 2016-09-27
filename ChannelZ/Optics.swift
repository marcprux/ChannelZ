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
        return Lens<A?, B?>(get: { $0.flatMap(self.get) }) { (whole, part) in
            if let whole = whole, let part = part {
                return self.set(whole, part)
            } else {
                return whole
            }
        }
    }
}

/// A lens provides the ability to access and modify a sub-element of an immutable data structure.
/// Optics composition in Swift is somewhat limited due to the lack of Higher Kinded Types, but
/// they can be used to great effect with a state channel in order to provide owner access and
/// conditional creation for complex immutable state structures.
///
/// See Also: https://github.com/apple/swift/blob/master/docs/GenericsManifesto.md#higher-kinded-types
public struct Lens<A, B> : LensType {
    fileprivate let getter: (A) -> B
    fileprivate let setter: (A, B) -> A

    public init(get: @escaping (A) -> B, create: @escaping (A, B) -> A) {
        self.getter = get
        self.setter = create
    }

    public init(_ get: @escaping (A) -> B, _ set: @escaping (inout A, B) -> ()) {
        self.getter = get
        self.setter = { var copy = $0; set(&copy, $1); return copy }
    }

    public func set(_ target: A, _ value: B) -> A {
        return setter(target, value)
    }

    public func get(_ target: A) -> B {
        return getter(target)
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
public struct LensSource<C: ChannelType, T>: LensSourceType where C.Source : TransceiverType, C.Pulse : MutationType, C.Pulse.Element == C.Source.Element {
    public typealias Owner = C
    public let channel: C
    public let lens: Lens<C.Source.Element, T>

    public func receive(_ x: T) {
        self.$ = x
    }

    public var $: T {
        get { return lens.get(channel.$) }
        nonmutating set { channel.$ = lens.set(channel.$, newValue) }
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
public typealias LensChannel<C: ChannelType, X> = Channel<LensSource<C, X>, Mutation<X>> where C.Source : TransceiverType, C.Pulse : MutationType, C.Pulse.Element == C.Source.Element

public extension ChannelType where Source : TransceiverType, Pulse: MutationType, Pulse.Element == Source.Element {
    public typealias FocusChannel<X> = LensChannel<Self, X>
}

/// A Prism on a state channel, which can be used create a property channel on a specific
/// piece of the source state; a LensSource itself does not manage any receivers, but instead
/// relies on the source of the underlying channel.
public struct PrismSource<C: ChannelType, T>: LensSourceType where C.Source : TransceiverType, C.Pulse : MutationType, C.Pulse.Element == C.Source.Element {
    public typealias Owner = C
    public let channel: C
    public let lens: Lens<C.Source.Element, T>
    public typealias Pulse = T

    public func receive(_ x: T) {
        self.$ = x
    }

    public var $: T {
        get { return lens.get(channel.$) }
        nonmutating set { channel.$ = lens.set(channel.$, newValue) }
    }

    /// Creates a state tranceiver to the focus of this lens, allowing the access and modification
    /// of a subset of a product type.
    public func transceive() -> Channel<PrismSource, Mutation<T>> {
        return channel.map({ pulse in
            Mutation(old: pulse.old.flatMap(self.lens.get), new: self.lens.get(pulse.new))
        }).resource({ _ in self })
    }
}

public extension ChannelType where Source : TransceiverType, Pulse: MutationType, Pulse.Element == Source.Element {

    /// A pure channel (whose element is the same as the source) can be lensed such that a derivative
    /// channel can modify sub-elements of a complex data structure
    public func focus<X>(lens: Lens<Source.Element, X>) -> LensChannel<Self, X> {
        return LensSource(channel: self, lens: lens).transceive()
    }

    /// Constructs a Lens channel using a getter and an inout setter
    public func focus<X>(_ get: @escaping (Source.Element) -> X, _ set: @escaping (inout Source.Element, X) -> ()) -> LensChannel<Self, X> {
        return focus(lens: Lens(get, set))
    }

//    public func focuz<X>(_ get: @escaping (Source.Element) -> X) -> (_ set: @escaping (inout Source.Element, X) -> ()) -> LensChannel<Self, X> {
//        return { self.focus(lens: Lens(get, $0)) }
//    }

    /// Constructs a Lens channel using a getter and a tranformation setter
    public func focus<X>(get: @escaping (Source.Element) -> X, create: @escaping (Source.Element, X) -> Source.Element) -> LensChannel<Self, X> {
        return focus(lens: Lens(get: get, create: create))
    }
}

public extension ChannelType where Source : LensSourceType {
    /// Simple alias for `source.channel.source`; useful for ascending a lens ownership hierarchy
    public var owner: Source.Owner { return source.channel }
}

// MARK: Jacket Channel extensions for Lens/Prism/Optional access

public extension ChannelType where Source.Element : _WrapperType, Source : TransceiverType, Pulse: MutationType, Pulse.Element == Source.Element {

    /// Converts an optional state channel into a non-optional one by replacing nil elements
    /// with the result of the constructor function
    public func coalesce(_ template: @escaping (Self) -> Source.Element.Wrapped) -> LensChannel<Self, Source.Element.Wrapped> {
        return focus(get: { $0.flatMap({ $0 }) ?? template(self) }, create: { (_, value) in Source.Element(value) })
    }

    /// Converts an optional state channel into a non-optional one by replacing nil elements
    /// with the constant of the value; alias for `coalesce`
    public func coalesce(_ value: Source.Element.Wrapped) -> LensChannel<Self, Source.Element.Wrapped> {
        return coalesce({ _ in value })
    }
}

public extension ChannelType where Source : TransceiverType, Pulse: MutationType, Pulse.Element == Source.Element {

    /// Given two channels that can find and update values based on the specified getters & updaters, create
    /// a `Transceiver` channel that provides access to the underlying merged elements.
    public func join<T, Join: ChannelType>(_ locator: Join, finder: @escaping (Self.Source.Element, Join.Source.Element) -> T, updater: @escaping ((Self.Source.Element, Join.Source.Element), T) -> (Self.Source.Element, Join.Source.Element)) -> LensChannel<Self, T> where Join.Source : StateEmitterType, Join.Pulse : MutationType, Join.Pulse.Element == Join.Source.Element {

        // the selection lens value is a prism over the current selection and the current elements
        let lens = Lens<Pulse.Element, T>(get: { elements in
            finder(elements, locator.source.$)
        }) { (elements, values) in
            updater((elements, locator.source.$), values).0
        }

        let sel = focus(lens: lens)

        return sel.either(locator).resource({ $0.0 }).map {
            switch $0 {
            case .v1(let v): // change in elements
                return v // the raw values are already resolved by the lens
            case .v2(let i): // change in locator; need to perform another lookup
                return Mutation(old: i.old.flatMap({ finder(self.source.$, $0) }), new: finder(self.source.$, i.new))
            }
        }
    }
}

public extension ChannelType where Source : TransceiverType, Source.Element == Pulse.Element, Pulse: MutationType, Pulse.Element : Sequence, Pulse.Element : Collection {

    /// Combines this sequence state source with a channel of indices and combines them into a prism
    /// where the subselection will be issued whenever a change in either the selection or the underlying
    /// elements occurs; indices that are invalid or become invalid will be silently ignored.
    public func match<Join: ChannelType>(_ locator: Join, setter: @escaping (Source.Element, Source.Element.Index, Source.Element.Iterator.Element?) -> Source.Element, getter: @escaping (Pulse.Element, Pulse.Element.Index) -> Pulse.Element.Iterator.Element?) -> LensChannel<Self, [Self.Pulse.Element.Iterator.Element]> where Join.Source : StateEmitterType, Join.Source.Element : Sequence, Join.Pulse.Element.Iterator.Element == Source.Element.Index, Join.Pulse : MutationType, Join.Pulse.Element == Join.Source.Element {

        typealias Output = [Source.Element.Iterator.Element]
        typealias Query = (input: Source.Element, indices: Join.Source.Element)

        func query(_ query: Query) -> Output {
            var elements = Output()
            elements.reserveCapacity(query.indices.underestimatedCount)
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

        return join(locator, finder: query, updater: update)
    }
}

public extension ChannelType where Source : TransceiverType, Source.Element == Pulse.Element, Pulse: MutationType, Pulse.Element : Collection, Pulse.Element.Indices.Iterator.Element == Pulse.Element.Index {

    /// Combines this collection state source with a channel of indices and combines them into a prism
    /// where the subselection will be issued whenever a change in either the selection or the underlying
    /// elements occurs; indices that are invalid or become invalid will be silently ignored.
    public func find<C: ChannelType>(_ locator: C, setter: @escaping (Source.Element, Source.Element.Index, Source.Element.Iterator.Element?) -> Source.Element)  -> LensChannel<Self, [Self.Pulse.Element.Iterator.Element]> where C.Source : StateEmitterType, C.Source.Element : Sequence, C.Pulse.Element.Iterator.Element == Source.Element.Index, C.Pulse : MutationType, C.Pulse.Element == C.Source.Element {

        return match(locator, setter: setter) { collection, index in
            if collection.indices.contains(index) {
                return collection[index]
            } else {
                return nil
            }
        }
    }
}

public extension ChannelType where Source.Element : MutableCollection, Source : TransceiverType, Pulse: MutationType, Pulse.Element == Source.Element, Pulse.Element.Indices.Iterator.Element == Pulse.Element.Index {

    /// Combines this collection state source with a channel of indices and combines them into a prism
    /// where the subselection will be issued whenever a change in either the selection or the underlying
    /// elements occurs; indices that are invalid or become invalid will be silently ignored.
    /// Array elements cannot be removed, so updated with a mismatched number of indices will be ignored.
    public func fixed<C: ChannelType>(_ indices: C) -> LensChannel<Self, [Self.Pulse.Element.Iterator.Element]> where C.Source : StateEmitterType, C.Source.Element : Sequence, C.Source.Element.Iterator.Element == Source.Element.Index, C.Pulse : MutationType, C.Pulse.Element == C.Source.Element {
        return find(indices) { (seq, idx, val) in
            var seq = seq
            if let val = val, seq.indices.contains(idx) {
                seq[idx] = val // FIXME: what to do with missing values?
            }
            return seq
        }
    }
}

public extension ChannelType where Source.Element : KeyIndexed, Source.Element.Key : Hashable, Source.Element : Collection, Source.Element.Index : KeyIndexedIndexType, Source.Element.Key == Source.Element.Index.Key, Source.Element.Value == Source.Element.Index.Value, Source : TransceiverType, Pulse: MutationType, Pulse.Element == Source.Element, Pulse.Element.Indices.Iterator.Element == Pulse.Element.Index {

    /// Combines this collection state source with a channel of indices and combines them into a prism
    /// where the subselection will be issued whenever a change in either the selection or the underlying
    /// elements occurs; indices that are invalid or become invalid will be represented by nil in the
    /// pulsed collection; nulling out individual members of existant keys will have no effect.
    public func keyed<Join: ChannelType>(_ indices: Join) -> LensChannel<Self, [Self.Pulse.Element.Value?]> where Join.Source : StateEmitterType, Join.Source.Element : Sequence, Join.Source.Element.Iterator.Element == Source.Element.Key, Join.Pulse : MutationType, Join.Pulse.Element == Join.Source.Element {

        func find(_ dict: Pulse.Element, keys: Join.Pulse.Element) -> [Pulse.Element.Value?] {

            var values: [Pulse.Element.Value?] = []
            for key in keys {
                values.append(dict[key])
            }
            return values
        }

        func update(_ vk: (dict: Pulse.Element, keys: Join.Pulse.Element), values: [Pulse.Element.Value?]) -> (Pulse.Element, Join.Pulse.Element) {
            var dict = vk.dict
            for (key, value) in Swift.zip(vk.keys, values) {
                dict[key] = value
            }
            return (dict, vk.keys)
        }

        return join(indices, finder: find, updater: update)
    }
}

public extension ChannelType where Source.Element : RangeReplaceableCollection, Source : TransceiverType, Pulse: MutationType, Pulse.Element == Source.Element, Pulse.Element.Indices.Iterator.Element == Pulse.Element.Index {

    /// Combines this collection state source with a channel of indices and combines them into a prism
    /// where the subselection will be issued whenever a change in either the selection or the underlying
    /// elements occurs; indices that are invalid or become invalid will be silently ignored.
    public func indexed<C: ChannelType>(_ indices: C) -> LensChannel<Self, [Self.Pulse.Element.Iterator.Element]> where C.Source : StateEmitterType, C.Source.Element : Sequence, C.Source.Element.Iterator.Element == Source.Element.Index, C.Pulse : MutationType, C.Pulse.Element == C.Source.Element {
        return find(indices) { (seq, idx, val) in
            var seq = seq
            if seq.indices.contains(idx) {
                seq.replaceSubrange(idx...idx, with: [val].flatMap({ $0 }))
            }
            return seq
        }
    }

    // FIXME: replace with identical indexed() function once crashing compiler bug with generic specialization is fixed
    private func indexedCRASH(_ indices: TransceiverChannel<[Self.Pulse.Element.Index]>) -> LensChannel<Self, [Self.Pulse.Element.Iterator.Element]> {
        // return indexed(indices) // CRASH
        return find(indices) { (seq, idx, val) in
            var seq = seq
            if seq.indices.contains(idx) {
                seq.replaceSubrange(idx...idx, with: [val].flatMap({ $0 }))
            }
            return seq
        }
    }

    /// Returns an accessor to the collection's static indices of elements
    public func indices(_ indices: [Source.Element.Index]) -> LensChannel<Self, [Self.Pulse.Element.Iterator.Element]> {
        return indexedCRASH(transceive(indices))
    }

    /// Creates a channel to the underlying collection type where the channel creates an optional
    /// to a given index; setting to nil removes the index, and setting to a certain value
    /// sets the index
    ///
    /// - Note: When setting the value of an index outside the current indices, any
    ///         intervening gaps will be filled with the value
    public func index(_ index: Source.Element.Index) -> LensChannel<Self, Source.Element.Iterator.Element?> {

        let lens: Lens<Source.Element, Source.Element.Iterator.Element?> = Lens(get: { target in
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
    public func prism<T>(_ lens: Lens<Source.Element.Iterator.Element, T>) -> LensChannel<Self, [T]> {
        let prismLens = Lens<Source.Element, [T]>({ $0.map(lens.get) }) {
            (elements: inout Source.Element, values: [T]) in
            var vals = values.makeIterator()
            for i in elements.indices {
                if let val = vals.next() {
                    elements.replaceSubrange(i...i, with: [lens.set(elements[i], val)])
                }
            }
        }
        return focus(lens: prismLens)
    }
}

public extension ChannelType where Source.Element : RangeReplaceableCollection, Source : TransceiverType, Pulse: MutationType, Pulse.Element == Source.Element, Source.Element.SubSequence.Iterator.Element == Source.Element.Iterator.Element, Pulse.Element.Indices.Iterator.Element == Pulse.Element.Index {

    /// Returns an accessor to the collection's range of elements
    public func range(_ range: Range<Source.Element.Index>) -> LensChannel<Self, Source.Element.SubSequence> {
        let rangeLens = Lens<Source.Element, Source.Element.SubSequence>({ $0[range] }) {
            (elements: inout Source.Element, values: Source.Element.SubSequence) in
            elements.replaceSubrange(range, with: Array(values))
        }
        return focus(lens: rangeLens)
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

public extension ChannelType where Source.Element : KeyIndexed, Source : TransceiverType, Pulse: MutationType, Pulse.Element == Source.Element {
    /// Creates a state channel to the given key in the underlying `KeyIndexed` dictionary
    public func at(_ key: Source.Element.Key) -> LensChannel<Self, Source.Element.Value?> {

        let lens: Lens<Source.Element, Source.Element.Value?> = Lens(get: { target in
            target[key]
            }, create: { (target, item) in
                var target = target
                target[key] = item
                return target
        })

        return focus(lens: lens)
    }
}

public extension ChannelType where Source.Element : Choose1Type, Source : TransceiverType, Pulse : MutationType, Pulse.Element == Source.Element {
    /// Channel for the first option of N choices
    public var v1Z: LensChannel<Self, Source.Element.T1?> {
        return focus({ (x: Pulse.Element) in x.v1 }, { (x: inout Pulse.Element, y: Pulse.Element.T1?) in x.v1 = y })
    }
}

public extension ChannelType where Source.Element : Choose2Type, Source : TransceiverType, Pulse : MutationType, Pulse.Element == Source.Element {
    /// Channel for the second option of N choices
    public var v2Z: LensChannel<Self, Source.Element.T2?> {
        return focus({ $0.v2 }, { (x: inout Pulse.Element, y: Pulse.Element.T2?) in x.v2 = y })
    }
}

public extension ChannelType where Source.Element : Choose3Type, Source : TransceiverType, Pulse : MutationType, Pulse.Element == Source.Element {
    /// Channel for the third option of N choices
    public var v3Z: LensChannel<Self, Source.Element.T3?> {
        return focus({ $0.v3 }, { (x: inout Pulse.Element, y: Pulse.Element.T3?) in x.v3 = y })
    }
}

public extension ChannelType where Source.Element : Choose4Type, Source : TransceiverType, Pulse : MutationType, Pulse.Element == Source.Element {
    /// Channel for the fourth option of N choices
    public var v4Z: LensChannel<Self, Source.Element.T4?> {
        return focus({ $0.v4 }, { (x: inout Pulse.Element, y: Pulse.Element.T4?) in x.v4 = y })
    }
}

public extension ChannelType where Source.Element : Choose5Type, Source : TransceiverType, Pulse : MutationType, Pulse.Element == Source.Element {
    /// Channel for the fifth option of N choices
    public var v5Z: LensChannel<Self, Source.Element.T5?> {
        return focus({ $0.v5 }, { (x: inout Pulse.Element, y: Pulse.Element.T5?) in x.v5 = y })
    }
}

public extension ChannelType where Source.Element : Choose6Type, Source : TransceiverType, Pulse : MutationType, Pulse.Element == Source.Element {
    /// Channel for the sixth option of N choices
    public var v6Z: LensChannel<Self, Source.Element.T6?> {
        return focus({ $0.v6 }, { (x: inout Pulse.Element, y: Pulse.Element.T6?) in x.v6 = y })
    }
}

public extension ChannelType where Source.Element : Choose7Type, Source : TransceiverType, Pulse : MutationType, Pulse.Element == Source.Element {
    /// Channel for the seventh option of N choices
    public var v7Z: LensChannel<Self, Source.Element.T7?> {
        return focus({ $0.v7 }, { (x: inout Pulse.Element, y: Pulse.Element.T7?) in x.v7 = y })
    }
}

public extension ChannelType where Source.Element : Choose8Type, Source : TransceiverType, Pulse : MutationType, Pulse.Element == Source.Element {
    /// Channel for the eighth option of N choices
    public var v8Z: LensChannel<Self, Source.Element.T8?> {
        return focus({ $0.v8 }, { (x: inout Pulse.Element, y: Pulse.Element.T8?) in x.v8 = y })
    }
}

public extension ChannelType where Source.Element : Choose9Type, Source : TransceiverType, Pulse : MutationType, Pulse.Element == Source.Element {
    /// Channel for the ninth option of N choices
    public var v9Z: LensChannel<Self, Source.Element.T9?> {
        return focus({ $0.v9 }, { (x: inout Pulse.Element, y: Pulse.Element.T9?) in x.v9 = y })
    }
}

public extension ChannelType where Source.Element : Choose10Type, Source : TransceiverType, Pulse : MutationType, Pulse.Element == Source.Element {
    /// Channel for the tenth option of N choices
    public var v10Z: LensChannel<Self, Source.Element.T10?> {
        return focus({ $0.v10 }, { (x: inout Pulse.Element, y: Pulse.Element.T10?) in x.v10 = y })
    }
}

public extension ChannelType where Source.Element : Choose11Type, Source : TransceiverType, Pulse : MutationType, Pulse.Element == Source.Element {
    /// Channel for the eleventh option of N choices
    public var v11Z: LensChannel<Self, Source.Element.T11?> {
        return focus({ $0.v11 }, { (x: inout Pulse.Element, y: Pulse.Element.T11?) in x.v11 = y })
    }
}

public extension ChannelType where Source.Element : Choose12Type, Source : TransceiverType, Pulse : MutationType, Pulse.Element == Source.Element {
    /// Channel for the twelfth option of N choices
    public var v12Z: LensChannel<Self, Source.Element.T12?> {
        return focus({ $0.v12 }, { (x: inout Pulse.Element, y: Pulse.Element.T12?) in x.v12 = y })
    }
}

public extension ChannelType where Source.Element : Choose13Type, Source : TransceiverType, Pulse : MutationType, Pulse.Element == Source.Element {
    /// Channel for the thirteenth option of N choices
    public var v13Z: LensChannel<Self, Source.Element.T13?> {
        return focus({ $0.v13 }, { (x: inout Pulse.Element, y: Pulse.Element.T13?) in x.v13 = y })
    }
}

public extension ChannelType where Source.Element : Choose14Type, Source : TransceiverType, Pulse : MutationType, Pulse.Element == Source.Element {
    /// Channel for the fourteenth option of N choices
    public var v14Z: LensChannel<Self, Source.Element.T14?> {
        return focus({ $0.v14 }, { (x: inout Pulse.Element, y: Pulse.Element.T14?) in x.v14 = y })
    }
}

public extension ChannelType where Source.Element : Choose15Type, Source : TransceiverType, Pulse : MutationType, Pulse.Element == Source.Element {
    /// Channel for the fifteenth option of N choices
    public var v15Z: LensChannel<Self, Source.Element.T15?> {
        return focus({ $0.v15 }, { (x: inout Pulse.Element, y: Pulse.Element.T15?) in x.v15 = y })
    }
}

public extension ChannelType where Source.Element : Choose16Type, Source : TransceiverType, Pulse : MutationType, Pulse.Element == Source.Element {
    /// Channel for the sixteenth option of N choices
    public var v16Z: LensChannel<Self, Source.Element.T16?> {
        return focus({ $0.v16 }, { (x: inout Pulse.Element, y: Pulse.Element.T16?) in x.v16 = y })
    }
}

public extension ChannelType where Source.Element : Choose17Type, Source : TransceiverType, Pulse : MutationType, Pulse.Element == Source.Element {
    /// Channel for the seventeenth option of N choices
    public var v17Z: LensChannel<Self, Source.Element.T17?> {
        return focus({ $0.v17 }, { (x: inout Pulse.Element, y: Pulse.Element.T17?) in x.v17 = y })
    }
}

public extension ChannelType where Source.Element : Choose18Type, Source : TransceiverType, Pulse : MutationType, Pulse.Element == Source.Element {
    /// Channel for the eighteenth option of N choices
    public var v18Z: LensChannel<Self, Source.Element.T18?> {
        return focus({ $0.v18 }, { (x: inout Pulse.Element, y: Pulse.Element.T18?) in x.v18 = y })
    }
}

public extension ChannelType where Source.Element : Choose19Type, Source : TransceiverType, Pulse : MutationType, Pulse.Element == Source.Element {
    /// Channel for the nineteenth option of N choices
    public var v19Z: LensChannel<Self, Source.Element.T19?> {
        return focus({ $0.v19 }, { (x: inout Pulse.Element, y: Pulse.Element.T19?) in x.v19 = y })
    }
}

public extension ChannelType where Source.Element : Choose20Type, Source : TransceiverType, Pulse : MutationType, Pulse.Element == Source.Element {
    /// Channel for the twentieth option of N choices
    public var v20Z: LensChannel<Self, Source.Element.T20?> {
        return focus({ $0.v20 }, { (x: inout Pulse.Element, y: Pulse.Element.T20?) in x.v20 = y })
    }
}
