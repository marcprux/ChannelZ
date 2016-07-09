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

    @warn_unused_result func set(target: A, _ value: B) -> A

    @warn_unused_result func get(target: A) -> B

}

public extension LensType {
    /// Converts this lens to an optional prism that allows lossy getting/setting of optional values
    ///
    /// - See Also: `ChannelType.prism`
    public var prism : Lens<A?, B?> {
        return Lens<A?, B?>(get: { $0.flatMap(self.get) }) { (whole, part) in
            if let whole = whole, part = part {
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
    private let getter: A -> B
    private let setter: (A, B) -> A

    public init(get: A -> B, create: (A, B) -> A) {
        self.getter = get
        self.setter = create
    }

    public init(_ get: A -> B, _ set: (inout A, B) -> ()) {
        self.getter = get
        self.setter = { var copy = $0; set(&copy, $1); return copy }
    }

    @warn_unused_result public func set(target: A, _ value: B) -> A {
        return setter(target, value)
    }

    @warn_unused_result public func get(target: A) -> B {
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
public struct LensSource<C: ChannelType, T where C.Source : TransceiverType, C.Pulse : MutationType, C.Pulse.Element == C.Source.Element>: LensSourceType {
    public typealias Owner = C
    public let channel: C
    public let lens: Lens<C.Source.Element, T>

    public func receive(x: T) {
        self.$ = x
    }

    public var $: T {
        get { return lens.get(channel.$) }
        nonmutating set { channel.$ = lens.set(channel.$, newValue) }
    }

    /// Creates a state tranceiver to the focus of this lens, allowing the access and modification
    /// of a subset of a product type.
    @warn_unused_result public func transceive() -> Channel<LensSource, Mutation<T>> {
        return channel.map({ pulse in
            Mutation(old: pulse.old.flatMap(self.lens.get), new: self.lens.get(pulse.new))
        }).resource({ _ in self })
    }
}

///// A Prism on a state channel, which can be used create a property channel on a specific
///// piece of the source state; a LensSource itself does not manage any receivers, but instead
///// relies on the source of the underlying channel.
//public struct PrismSource<C: ChannelType, T where C.Source : TransceiverType, C.Pulse : MutationType, C.Pulse.Element == C.Source.Element>: LensSourceType {
//    public typealias Owner = C
//    public let channel: C
//    public let lens: Lens<C.Source.Element, T>
//
//    public func receive(x: T) {
//        self.$ = x
//    }
//
//    public var $: T {
//        get { return lens.get(channel.$) }
//        nonmutating set { channel.$ = lens.set(channel.$, newValue) }
//    }
//
//    /// Creates a state tranceiver to the focus of this lens, allowing the access and modification
//    /// of a subset of a product type.
//    @warn_unused_result public func transceive() -> Channel<PrismSource, Mutation<T>> {
//        return channel.map({ pulse in
//            Mutation(old: pulse.old.flatMap(self.lens.get), new: self.lens.get(pulse.new))
//        }).resource({ _ in self })
//    }
//}

public extension ChannelType where Source : TransceiverType, Pulse: MutationType, Pulse.Element == Source.Element {
    /// A pure channel (whose element is the same as the source) can be lensed such that a derivative
    /// channel can modify sub-elements of a complex data structure
    @warn_unused_result public func focus<X>(lens: Lens<Source.Element, X>) -> Channel<LensSource<Self, X>, Mutation<X>> {
        return LensSource(channel: self, lens: lens).transceive()
    }

    /// Constructs a Lens channel using a getter and an inout setter
    @warn_unused_result public func focus<X>(get: Source.Element -> X, _ set: (inout Source.Element, X) -> ()) -> Channel<LensSource<Self, X>, Mutation<X>> {
        return focus(Lens(get, set))
    }

    /// Constructs a Lens channel using a getter and a tranformation setter
    @warn_unused_result public func focus<X>(get get: Source.Element -> X, create: (Source.Element, X) -> Source.Element) -> Channel<LensSource<Self, X>, Mutation<X>> {
        return focus(Lens(get: get, create: create))
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
    @warn_unused_result public func coalesce(template: Self -> Source.Element.Wrapped) -> Channel<LensSource<Self, Source.Element.Wrapped>, Mutation<Source.Element.Wrapped>> {
        return focus(get: { $0.flatMap({ $0 }) ?? template(self) }, create: { (_, value) in Source.Element(value) })
    }

    /// Converts an optional state channel into a non-optional one by replacing nil elements
    /// with the constant of the value; alias for `coalesce`
    @warn_unused_result public func coalesce(value: Source.Element.Wrapped) -> Channel<LensSource<Self, Source.Element.Wrapped>, Mutation<Source.Element.Wrapped>> {
        return coalesce({ _ in value })
    }
}

public extension ChannelType where Source : TransceiverType, Pulse: MutationType, Pulse.Element == Source.Element {

    /// Given two channels that can find and update values based on the specified getters & updaters, create
    /// a `Transceiver` channel that provides access to the underlying merged elements.
    @warn_unused_result public func join<T, Join: ChannelType where Join.Source : StateEmitterType, Join.Pulse : MutationType, Join.Pulse.Element == Join.Source.Element>(locator: Join, finder: (Self.Source.Element, Join.Source.Element) -> T, updater: ((Self.Source.Element, Join.Source.Element), T) -> (Self.Source.Element, Join.Source.Element)) -> Channel<LensSource<Self, T>, Mutation<T>> {

        // the selection lens value is a prism over the current selection and the current elements
        let lens = Lens<Pulse.Element, T>(get: { elements in
            finder(elements, locator.source.$)
        }) { (elements, values) in
            updater((elements, locator.source.$), values).0
        }

        let sel: Channel<LensSource<Self, T>, Mutation<T>> = focus(lens)

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

public extension ChannelType where Source : TransceiverType, Source.Element == Pulse.Element, Pulse: MutationType, Pulse.Element : SequenceType, Pulse.Element : Indexable {

    /// Combines this sequence state source with a channel of indices and combines them into a prism
    /// where the subselection will be issued whenever a change in either the selection or the underlying
    /// elements occurs; indices that are invalid or become invalid will be silently ignored.
    @warn_unused_result public func match<Join: ChannelType where Join.Source : StateEmitterType, Join.Source.Element : SequenceType, Join.Pulse.Element.Generator.Element == Source.Element.Index, Join.Pulse : MutationType, Join.Pulse.Element == Join.Source.Element>(locator: Join, setter: (Source.Element, Source.Element.Index, Source.Element.Generator.Element?) -> Source.Element, getter: (Pulse.Element, Pulse.Element.Index) -> Pulse.Element.Generator.Element?) -> Channel<LensSource<Self, [Self.Pulse.Element.Generator.Element]>, Mutation<[Self.Pulse.Element.Generator.Element]>> {

        typealias Output = [Source.Element.Generator.Element]
        typealias Query = (input: Source.Element, indices: Join.Source.Element)

        func query(query: Query) -> Output {
            var elements = Output()
            elements.reserveCapacity(query.indices.underestimateCount())
            for index in query.indices {
                if let value = getter(query.input, index) {
                    elements.append(value)
                }
            }
            // assert(elements.count == Array(query.indices).count)
            return elements
        }

        func update(query: Query, output: Output) -> Query {
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

public extension ChannelType where Source : TransceiverType, Source.Element == Pulse.Element, Pulse: MutationType, Pulse.Element : CollectionType {

    /// Combines this collection state source with a channel of indices and combines them into a prism
    /// where the subselection will be issued whenever a change in either the selection or the underlying
    /// elements occurs; indices that are invalid or become invalid will be silently ignored.
    @warn_unused_result public func find<C: ChannelType where C.Source : StateEmitterType, C.Source.Element : SequenceType, C.Pulse.Element.Generator.Element == Source.Element.Index, C.Pulse : MutationType, C.Pulse.Element == C.Source.Element>(locator: C, setter: (Source.Element, Source.Element.Index, Source.Element.Generator.Element?) -> Source.Element)  -> Channel<LensSource<Self, [Self.Pulse.Element.Generator.Element]>, Mutation<[Self.Pulse.Element.Generator.Element]>> {

        return match(locator, setter: setter) { collection, index in
            if collection.indices.contains(index) {
                return collection[index]
            } else {
                return nil
            }
        }
    }
}

public extension ChannelType where Source.Element : MutableCollectionType, Source : TransceiverType, Pulse: MutationType, Pulse.Element == Source.Element {

    /// Combines this collection state source with a channel of indices and combines them into a prism
    /// where the subselection will be issued whenever a change in either the selection or the underlying
    /// elements occurs; indices that are invalid or become invalid will be silently ignored.
    /// Array elements cannot be removed, so updated with a mismatched number of indices will be ignored.
    @warn_unused_result public func fixed<C: ChannelType where C.Source : StateEmitterType, C.Source.Element : SequenceType, C.Source.Element.Generator.Element == Source.Element.Index, C.Pulse : MutationType, C.Pulse.Element == C.Source.Element>(indices: C) -> Channel<LensSource<Self, [Self.Pulse.Element.Generator.Element]>, Mutation<[Self.Pulse.Element.Generator.Element]>> {
        return find(indices) { (seq, idx, val) in
            var seq = seq
            if let val = val where seq.indices.contains(idx) {
                seq[idx] = val // FIXME: what to do with missing values?
            }
            return seq
        }
    }
}

public extension ChannelType where Source.Element : KeyIndexed, Source.Element.Key : Hashable, Source.Element : CollectionType, Source.Element.Index : KeyIndexedIndexType, Source.Element.Key == Source.Element.Index.Key, Source.Element.Value == Source.Element.Index.Value, Source : TransceiverType, Pulse: MutationType, Pulse.Element == Source.Element {

    /// Combines this collection state source with a channel of indices and combines them into a prism
    /// where the subselection will be issued whenever a change in either the selection or the underlying
    /// elements occurs; indices that are invalid or become invalid will be represented by nil in the
    /// pulsed collection; nulling out individual members of existant keys will have no effect.
    @warn_unused_result public func keyed<Join: ChannelType where Join.Source : StateEmitterType, Join.Source.Element : SequenceType, Join.Source.Element.Generator.Element == Source.Element.Key, Join.Pulse : MutationType, Join.Pulse.Element == Join.Source.Element>(indices: Join) -> Channel<LensSource<Self, [Self.Pulse.Element.Value?]>, Mutation<[Self.Pulse.Element.Value?]>> {

        func find(dict: Pulse.Element, keys: Join.Pulse.Element) -> [Pulse.Element.Value?] {

            var values: [Pulse.Element.Value?] = []
            for key in keys {
                values.append(dict[key])
            }
            return values
        }

        func update(vk: (dict: Pulse.Element, keys: Join.Pulse.Element), values: [Pulse.Element.Value?]) -> (Pulse.Element, Join.Pulse.Element) {
            var dict = vk.dict
            for (key, value) in Swift.zip(vk.keys, values) {
                dict[key] = value
            }
            return (dict, vk.keys)
        }

        return join(indices, finder: find, updater: update)
    }
}

public extension ChannelType where Source.Element : RangeReplaceableCollectionType, Source : TransceiverType, Pulse: MutationType, Pulse.Element == Source.Element {

    /// Combines this collection state source with a channel of indices and combines them into a prism
    /// where the subselection will be issued whenever a change in either the selection or the underlying
    /// elements occurs; indices that are invalid or become invalid will be silently ignored.
    @warn_unused_result public func indexed<C: ChannelType where C.Source : StateEmitterType, C.Source.Element : SequenceType, C.Source.Element.Generator.Element == Source.Element.Index, C.Pulse : MutationType, C.Pulse.Element == C.Source.Element>(indices: C) -> Channel<LensSource<Self, [Self.Pulse.Element.Generator.Element]>, Mutation<[Self.Pulse.Element.Generator.Element]>> {
        return find(indices) { (seq, idx, val) in
            var seq = seq
            if seq.indices.contains(idx) {
                seq.replaceRange(idx...idx, with: [val].flatMap({ $0 }))
            }
            return seq
        }
    }


    /// Returns an accessor to the collection's static indices of elements
    @warn_unused_result public func indices(indices: [Source.Element.Index]) -> Channel<LensSource<Self, [Self.Pulse.Element.Generator.Element]>, Mutation<[Self.Pulse.Element.Generator.Element]>> {
        return indexed(transceive(indices))
    }

    /// Creates a channel to the underlying collection type where the channel creates an optional
    /// to a given index; setting to nil removes the index, and setting to a certain value
    /// sets the index
    ///
    /// - Note: When setting the value of an index outside the current indices, any
    ///         intervening gaps will be filled with the value
    @warn_unused_result public func index(index: Source.Element.Index) -> Channel<LensSource<Self, Source.Element.Generator.Element?>, Mutation<Source.Element.Generator.Element?>> {

        let lens: Lens<Source.Element, Source.Element.Generator.Element?> = Lens(get: { target in
            target.indices.contains(index) ? target[index] : nil
            }, create: { (target, item) in
                var target = target
                if let item = item {
                    while !target.indices.contains(index) {
                        // fill in the gaps
                        target.append(item)
                    }
                    // set the target index item
                    target.replaceRange(index...index, with: [item])
                } else {
                    if target.indices.contains(index) {
                        target.removeAtIndex(index)
                    }
                }
                return target
        })

        return focus(lens)
    }

    /// Creates a prism lens channel, allowing access to a collection's mapped lens
    @warn_unused_result public func prism<T>(lens: Lens<Source.Element.Generator.Element, T>) -> Channel<LensSource<Self, [T]>, Mutation<[T]>> {
        let prismLens = Lens<Source.Element, [T]>({ $0.map(lens.get) }) {
            (elements, values) in
            var vals = values.generate()
            for i in elements.startIndex..<elements.endIndex {
                if let val = vals.next() {
                    elements.replaceRange(i...i, with: [lens.set(elements[i], val)])
                }
            }
        }
        return focus(prismLens)
    }
}

public extension ChannelType where Source.Element : RangeReplaceableCollectionType, Source : TransceiverType, Pulse: MutationType, Pulse.Element == Source.Element, Source.Element.SubSequence.Generator.Element == Source.Element.Generator.Element {

    /// Returns an accessor to the collection's range of elements
    @warn_unused_result public func range(range: Range<Source.Element.Index>) -> Channel<LensSource<Self, Source.Element.SubSequence>, Mutation<Source.Element.SubSequence>> {
        let rangeLens = Lens<Source.Element, Source.Element.SubSequence>({ $0[range] }) {
            (elements, values) in
            elements.replaceRange(range, with: Array(values))
        }
        return focus(rangeLens)
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

public protocol KeyIndexedIndexType : ForwardIndexType, Comparable {
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
    @warn_unused_result public func at(key: Source.Element.Key) -> Channel<LensSource<Self, Source.Element.Value?>, Mutation<Source.Element.Value?>> {

        let lens: Lens<Source.Element, Source.Element.Value?> = Lens(get: { target in
            target[key]
            }, create: { (target, item) in
                var target = target
                target[key] = item
                return target
        })

        return focus(lens)
    }
}

public extension ChannelType where Source.Element : Choose1Type, Source : TransceiverType, Pulse : MutationType, Pulse.Element == Source.Element {
    /// Channel for the first option of N choices
    public var v1Z: Channel<LensSource<Self, Optional<Source.Element.T1>>, Mutation<Optional<Source.Element.T1>>> { return focus({ $0.v1 }, { $0.v1 = $1 }) }
}

public extension ChannelType where Source.Element : Choose2Type, Source : TransceiverType, Pulse : MutationType, Pulse.Element == Source.Element {
    /// Channel for the second option of N choices
    public var v2Z: Channel<LensSource<Self, Optional<Source.Element.T2>>, Mutation<Optional<Source.Element.T2>>> { return focus({ $0.v2 }, { $0.v2 = $1 }) }
}

public extension ChannelType where Source.Element : Choose3Type, Source : TransceiverType, Pulse : MutationType, Pulse.Element == Source.Element {
    /// Channel for the third option of N choices
    public var v3Z: Channel<LensSource<Self, Optional<Source.Element.T3>>, Mutation<Optional<Source.Element.T3>>> { return focus({ $0.v3 }, { $0.v3 = $1 }) }
}

public extension ChannelType where Source.Element : Choose4Type, Source : TransceiverType, Pulse : MutationType, Pulse.Element == Source.Element {
    /// Channel for the fourth option of N choices
    public var v4Z: Channel<LensSource<Self, Optional<Source.Element.T4>>, Mutation<Optional<Source.Element.T4>>> { return focus({ $0.v4 }, { $0.v4 = $1 }) }
}

public extension ChannelType where Source.Element : Choose5Type, Source : TransceiverType, Pulse : MutationType, Pulse.Element == Source.Element {
    /// Channel for the fifth option of N choices
    public var v5Z: Channel<LensSource<Self, Optional<Source.Element.T5>>, Mutation<Optional<Source.Element.T5>>> { return focus({ $0.v5 }, { $0.v5 = $1 }) }
}

public extension ChannelType where Source.Element : Choose6Type, Source : TransceiverType, Pulse : MutationType, Pulse.Element == Source.Element {
    /// Channel for the sixth option of N choices
    public var v6Z: Channel<LensSource<Self, Optional<Source.Element.T6>>, Mutation<Optional<Source.Element.T6>>> { return focus({ $0.v6 }, { $0.v6 = $1 }) }
}

public extension ChannelType where Source.Element : Choose7Type, Source : TransceiverType, Pulse : MutationType, Pulse.Element == Source.Element {
    /// Channel for the seventh option of N choices
    public var v7Z: Channel<LensSource<Self, Optional<Source.Element.T7>>, Mutation<Optional<Source.Element.T7>>> { return focus({ $0.v7 }, { $0.v7 = $1 }) }
}

public extension ChannelType where Source.Element : Choose8Type, Source : TransceiverType, Pulse : MutationType, Pulse.Element == Source.Element {
    /// Channel for the eighth option of N choices
    public var v8Z: Channel<LensSource<Self, Optional<Source.Element.T8>>, Mutation<Optional<Source.Element.T8>>> { return focus({ $0.v8 }, { $0.v8 = $1 }) }
}

public extension ChannelType where Source.Element : Choose9Type, Source : TransceiverType, Pulse : MutationType, Pulse.Element == Source.Element {
    /// Channel for the ninth option of N choices
    public var v9Z: Channel<LensSource<Self, Optional<Source.Element.T9>>, Mutation<Optional<Source.Element.T9>>> { return focus({ $0.v9 }, { $0.v9 = $1 }) }
}

public extension ChannelType where Source.Element : Choose10Type, Source : TransceiverType, Pulse : MutationType, Pulse.Element == Source.Element {
    /// Channel for the tenth option of N choices
    public var v10Z: Channel<LensSource<Self, Optional<Source.Element.T10>>, Mutation<Optional<Source.Element.T10>>> { return focus({ $0.v10 }, { $0.v10 = $1 }) }
}

public extension ChannelType where Source.Element : Choose11Type, Source : TransceiverType, Pulse : MutationType, Pulse.Element == Source.Element {
    /// Channel for the eleventh option of N choices
    public var v11Z: Channel<LensSource<Self, Optional<Source.Element.T11>>, Mutation<Optional<Source.Element.T11>>> { return focus({ $0.v11 }, { $0.v11 = $1 }) }
}

public extension ChannelType where Source.Element : Choose12Type, Source : TransceiverType, Pulse : MutationType, Pulse.Element == Source.Element {
    /// Channel for the twelfth option of N choices
    public var v12Z: Channel<LensSource<Self, Optional<Source.Element.T12>>, Mutation<Optional<Source.Element.T12>>> { return focus({ $0.v12 }, { $0.v12 = $1 }) }
}

public extension ChannelType where Source.Element : Choose13Type, Source : TransceiverType, Pulse : MutationType, Pulse.Element == Source.Element {
    /// Channel for the thirteenth option of N choices
    public var v13Z: Channel<LensSource<Self, Optional<Source.Element.T13>>, Mutation<Optional<Source.Element.T13>>> { return focus({ $0.v13 }, { $0.v13 = $1 }) }
}

public extension ChannelType where Source.Element : Choose14Type, Source : TransceiverType, Pulse : MutationType, Pulse.Element == Source.Element {
    /// Channel for the fourteenth option of N choices
    public var v14Z: Channel<LensSource<Self, Optional<Source.Element.T14>>, Mutation<Optional<Source.Element.T14>>> { return focus({ $0.v14 }, { $0.v14 = $1 }) }
}

public extension ChannelType where Source.Element : Choose15Type, Source : TransceiverType, Pulse : MutationType, Pulse.Element == Source.Element {
    /// Channel for the fifteenth option of N choices
    public var v15Z: Channel<LensSource<Self, Optional<Source.Element.T15>>, Mutation<Optional<Source.Element.T15>>> { return focus({ $0.v15 }, { $0.v15 = $1 }) }
}

public extension ChannelType where Source.Element : Choose16Type, Source : TransceiverType, Pulse : MutationType, Pulse.Element == Source.Element {
    /// Channel for the sixteenth option of N choices
    public var v16Z: Channel<LensSource<Self, Optional<Source.Element.T16>>, Mutation<Optional<Source.Element.T16>>> { return focus({ $0.v16 }, { $0.v16 = $1 }) }
}

public extension ChannelType where Source.Element : Choose17Type, Source : TransceiverType, Pulse : MutationType, Pulse.Element == Source.Element {
    /// Channel for the seventeenth option of N choices
    public var v17Z: Channel<LensSource<Self, Optional<Source.Element.T17>>, Mutation<Optional<Source.Element.T17>>> { return focus({ $0.v17 }, { $0.v17 = $1 }) }
}

public extension ChannelType where Source.Element : Choose18Type, Source : TransceiverType, Pulse : MutationType, Pulse.Element == Source.Element {
    /// Channel for the eighteenth option of N choices
    public var v18Z: Channel<LensSource<Self, Optional<Source.Element.T18>>, Mutation<Optional<Source.Element.T18>>> { return focus({ $0.v18 }, { $0.v18 = $1 }) }
}

public extension ChannelType where Source.Element : Choose19Type, Source : TransceiverType, Pulse : MutationType, Pulse.Element == Source.Element {
    /// Channel for the nineteenth option of N choices
    public var v19Z: Channel<LensSource<Self, Optional<Source.Element.T19>>, Mutation<Optional<Source.Element.T19>>> { return focus({ $0.v19 }, { $0.v19 = $1 }) }
}

public extension ChannelType where Source.Element : Choose20Type, Source : TransceiverType, Pulse : MutationType, Pulse.Element == Source.Element {
    /// Channel for the twentieth option of N choices
    public var v20Z: Channel<LensSource<Self, Optional<Source.Element.T20>>, Mutation<Optional<Source.Element.T20>>> { return focus({ $0.v20 }, { $0.v20 = $1 }) }
}
