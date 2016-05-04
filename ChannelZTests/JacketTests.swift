//
//  JacketTests.swift
//  ChannelZ
//
//  Created by Marc Prud'hommeaux on 5/1/16.
//  Copyright © 2016 glimpse.io. All rights reserved.
//

import ChannelZ
import XCTest


// MARK: Jacket Test Data Model


typealias PersonID = String

struct Directory {
    var author: Person
    var companies: [Company]
}

struct Company {
    var employees: [PersonID: Person]
    var ceoID: PersonID
    var ctoID: PersonID?
    var address: Address
}

struct Person {
    var firstName: String
    var lastName: String
    var gender: Gender
    var homeAddress: Address
    var workAddress: Address?
    var previousAddresses: [Address]
    enum Gender { case Male, Female }
}

struct Address {
    var line1: String
    var line2: String?
    var postalCode: String
}


extension ChannelType where Source.Element == Directory, Source : StateContainer, Pulse : StatePulseType, Pulse.T == Source.Element {
    var authorZ: Channel<LensSource<Self, Person>, StatePulse<Person>> { return channelZLens({ $0.author }, { $0.author = $1 }) }
    var companiesZ: Channel<LensSource<Self, [Company]>, StatePulse<[Company]>> { return channelZLens({ $0.companies }, { $0.companies = $1 }) }
}

extension ChannelType where Source.Element == Company, Source : StateContainer, Pulse : StatePulseType, Pulse.T == Source.Element {
    var addressZ: Channel<LensSource<Self, Address>, StatePulse<Address>> { return channelZLens({ $0.address }, { $0.address = $1 }) }
    var employeesZ: Channel<LensSource<Self, [PersonID: Person]>, StatePulse<[PersonID: Person]>> { return channelZLens({ $0.employees }, { $0.employees = $1 }) }
}

extension ChannelType where Source.Element == Person, Source : StateContainer, Pulse : StatePulseType, Pulse.T == Source.Element {
    var firstNameZ: Channel<LensSource<Self, String>, StatePulse<String>> { return channelZLens({ $0.firstName }, { $0.firstName = $1 }) }
    var lastNameZ: Channel<LensSource<Self, String>, StatePulse<String>> { return channelZLens({ $0.lastName }, { $0.lastName = $1 }) }
    var genderZ: Channel<LensSource<Self, Person.Gender>, StatePulse<Person.Gender>> { return channelZLens({ $0.gender }, { $0.gender = $1 }) }
    var homeAddressZ: Channel<LensSource<Self, Address>, StatePulse<Address>> { return channelZLens({ $0.homeAddress }, { $0.homeAddress = $1 }) }
    var workAddressZ: Channel<LensSource<Self, Address?>, StatePulse<Address?>> { return channelZLens({ $0.workAddress }, { $0.workAddress = $1 }) }
    var previousAddressesZ: Channel<LensSource<Self, [Address]>, StatePulse<[Address]>> { return channelZLens({ $0.previousAddresses }, { $0.previousAddresses = $1 }) }
}

extension ChannelType where Source.Element == Address, Source : StateContainer, Pulse : StatePulseType, Pulse.T == Source.Element {
    var line1Z: Channel<LensSource<Self, String>, StatePulse<String>> { return channelZLens({ $0.line1 }, { $0.line1 = $1 }) }
    var line2Z: Channel<LensSource<Self, String?>, StatePulse<String?>> { return channelZLens({ $0.line2 }, { $0.line2 = $1 }) }
    var postalCodeZ: Channel<LensSource<Self, String>, StatePulse<String>> { return channelZLens({ $0.postalCode }, { $0.postalCode = $1 }) }
}



///// A van Laarhoven Prism type
//public protocol PrismType {
//    associatedtype A
//    associatedtype B
//
//    @warn_unused_result func set(target: A, _ value: B) -> A
//
//    @warn_unused_result func get(target: A) -> B
//
//}
//
///// A prism provides the ability to access and modify a sub-element of an immutable data structure
//public struct Prism<A, B> : PrismType {
//    private let getter: A -> B
//    private let setter: (A, B) -> A
//
//    public init(get: A -> B, set: (A, B) -> A) {
//        self.getter = get
//        self.setter = set
//    }
//
//    public init(_ get: A -> B, _ set: (inout A, B) -> ()) {
//        self.getter = get
//        self.setter = { var copy = $0; set(&copy, $1); return copy }
//    }
//
//    @warn_unused_result public func set(target: A, _ value: B) -> A {
//        return setter(target, value)
//    }
//
//    @warn_unused_result public func get(target: A) -> B {
//        return getter(target)
//    }
//}
//
//public protocol PrismSourceType : StateContainer {
//    associatedtype Owner : ChannelType
//
//    /// All lens channels have an owner that is itself a StateSource
//    var channel: Owner { get }
//}
//

//public extension ChannelType where Source.Element : RangeReplaceableCollectionType, Source : StateContainer, Pulse: StatePulseType, Pulse.T == Source.Element {
//
//    /// Creates a channel to the underlying collection type where the given index will be
//    /// lazily created when it does not exist with the given template; any gaps in the
//    /// indices will also be filled with the template.
//    public func indexed() -> Channel<LensSource<Self, (Source.Element.Index, Source.Element.Generator.Element)>, StatePulse<(Source.Element.Index, Source.Element.Generator.Element)>> {
//
////        let lens: Lens<Source.Element, Source.Element.Generator.Element> = Lens(get: { target in
////            target.indices.contains(index) ? target[index] : template()
////        }) { (target, item) in
////            var target = target
////            while !target.indices.contains(index) {
////                // fill in the gaps
////                target.append(template())
////            }
////            // set the target index item
////            target.replaceRange(index...index, with: [item])
////            return target
////        }
////
////        return channelZLens(lens)
//
//        fatalError()
//    }
//}


extension ChannelTests {
    func testJacket() {


        let bebe = Person(firstName: "Beatrice", lastName: "Walter",
                          gender: .Female,
                          homeAddress: Address(line1: "123 Finite Loop", line2: nil, postalCode: "11223"),
                          workAddress: nil,
                          previousAddresses: [])

        var dir = Directory(author: bebe,
                            companies: [
                                Company(employees: [
                                    "359414": Person(firstName: "Marc", lastName: "Walter",
                                        gender: .Male,
                                        homeAddress: Address(line1: "123 Finite Loop", line2: nil, postalCode: "11223"),
                                        workAddress: Address(line1: "123 Finite Loop", line2: nil, postalCode: "11223"),
                                        previousAddresses: [])
                                    ],
                                    ceoID: "359414",
                                    ctoID: nil,
                                    address: Address(line1: "1 NaN Loop", line2: nil, postalCode: "99999"))
            ]
        )

        dump(dir)
        dir.companies[0].employees[dir.companies[0].ceoID]?.workAddress?.line2 = "Suite #111"
        dump(dir)

        // let dirZ = channelZPropertyState(dir)

        do {
            let dirz = channelZPropertyState(dir)

            let bebeZ = dirz.authorZ

            bebeZ.homeAddressZ.line1Z.$ = "Foo"
            bebeZ.homeAddressZ.line2Z.$ = "Bar"
            XCTAssertEqual("Foo", bebeZ.$.homeAddress.line1)
            XCTAssertEqual("Bar", bebeZ.$.homeAddress.line2)

            XCTAssertEqual(nil, bebeZ.$.workAddress?.line1)

            XCTAssertEqual(nil, bebeZ.$.workAddress?.line1)
            XCTAssertEqual(nil, bebeZ.$.workAddress?.line2)

            let defaddr = Address(line1: "", line2: nil, postalCode: "")
            bebeZ.workAddressZ.option({ defaddr }).line1Z.$ = "AAA"
            bebeZ.workAddressZ.option({ defaddr }).line2Z.$ = "BBB"

            XCTAssertEqual("AAA", bebeZ.$.workAddress?.line1)
            XCTAssertEqual("BBB", bebeZ.$.workAddress?.line2)

            let a1 = bebeZ.homeAddressZ.line1Z.sieve(!=).new()
            let a2 = bebeZ.workAddressZ.option({ defaddr }).line1Z.sieve(!=).new()

            let b1 = bebeZ.homeAddressZ.line2Z.sieve(!=).new()
            let b2 = bebeZ.workAddressZ.option({ defaddr }).line2Z.sieve(!=).new()

            a1.bind(a2) // works from home
            b1.bind(b2) // works from home

            bebeZ.$.workAddress?.line1 = "XXX"
            XCTAssertEqual("XXX", bebeZ.$.homeAddress.line1)
            XCTAssertEqual("XXX", bebeZ.$.workAddress?.line1)

            bebeZ.homeAddressZ.line1Z.$ = "YYY"
            XCTAssertEqual("YYY", bebeZ.$.homeAddress.line1)
            XCTAssertEqual("YYY", bebeZ.$.workAddress?.line1)

            bebeZ.workAddressZ.option({ defaddr }).line1Z.$ = "ZZZ"
            XCTAssertEqual("ZZZ", bebeZ.$.homeAddress.line1)
            XCTAssertEqual("ZZZ", bebeZ.$.workAddress?.line1)


            bebeZ.previousAddressesZ.index(1).option({ defaddr }).line2Z.sieve(!=).anyState().receive {
                print("#### index 1 value", $0.new)
            }

//            bebeZ.previousAddressesZ.indexed().map({ $0.$.1 })

            XCTAssertEqual(0, bebeZ.$.previousAddresses.count)
            bebeZ.previousAddressesZ.index(2).option({ defaddr }).line1Z.$ = "XYZ"
            XCTAssertEqual(3, bebeZ.$.previousAddresses.count)
            XCTAssertEqual("XYZ", bebeZ.$.previousAddresses[0].line1)
            XCTAssertEqual("XYZ", bebeZ.$.previousAddresses[1].line1)
            XCTAssertEqual("XYZ", bebeZ.$.previousAddresses[2].line1)

            bebeZ.$.previousAddresses[1].line2 = "ABC"

            dirz.companiesZ.index(0).option({ nil as Company! }).employeesZ.at("359414").value().some().receive {
                print("emp #359414", $0)
            }

            let empnameZ = dirz.companiesZ.index(0).option({ nil as Company! }).employeesZ.at("359414").option({ nil as Person! }).firstNameZ
            empnameZ.$ = "Marcus"

            XCTAssertEqual("Marcus", dirz.$.companies.first?.employees["359414"]?.firstName)
        }

    }
}
