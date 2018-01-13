//
//  OpticsTests.swift
//  ChannelZ
//
//  Created by Marc Prud'hommeaux on 5/1/16.
//  Copyright © 2016 glimpse.io. All rights reserved.
//

import ChannelZ
import XCTest

// MARK: Optics Test Data Model

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
    enum Gender { case male, female }
}

struct Address {
    var line1: String
    var line2: String?
    var postalCode: String
}

extension Directory : Focusable {
    static let authorZ = lenZ(\.author)
    static let companiesZ = lenZ(\.companies)
}

//extension ChannelType where Source.Element == Directory, Source : TransceiverType, Pulse : MutationType, Pulse.Element == Source.Element {
//    var authorZ: LensChannel<Self, Person> { return focus(Directory.authorZ) }
//    var companiesZ: LensChannel<Self, [Company]> { return focus(Directory.companiesZ) }
//}

extension Company : Focusable {
    static let addressZ = lenZ(\.address)
    static let employeesZ = lenZ(\.employees)
    static let ceoIDZ = lenZ(\.ceoID)
    static let ctoIDZ = lenZ(\.ctoID)
}

//extension ChannelType where Source.Element == Company, Source : TransceiverType, Pulse : MutationType, Pulse.Element == Source.Element {
//    var addressZ: LensChannel<Self, Address> { return focus(Company.addressZ) }
//    var employeesZ: LensChannel<Self, [PersonID: Person]> { return focus(Company.employeesZ) }
//    var ceoIDZ: LensChannel<Self, PersonID> { return focus(Company.ceoIDZ) }
//    var ctoIDZ: LensChannel<Self, PersonID?> { return focus(Company.ctoIDZ) }
//}

extension Person : Focusable {
    static let firstNameZ = lenZ(\.firstName)
    static let lastNameZ = lenZ(\.lastName)
    static let genderZ = lenZ(\.gender)
    static let homeAddressZ = lenZ(\.homeAddress)
    static let workAddressZ = lenZ(\.workAddress)
    static let previousAddressesZ = lenZ(\.previousAddresses)
}

//extension Lens {
//    func focus<C: ChannelType>(_ channel: C) -> LensChannel<A, B> where C.Source.Element == A, C.Source : TransceiverType, C.Pulse : MutationType, C.Pulse.Element == C.Source.Element {
//        fatalError()
////        return channel.focus(lens: self)
//    }
//}

//extension ChannelType where Source.Element == Person, Source : TransceiverType, Pulse : MutationType, Pulse.Element == Source.Element {
////    var XXX = Person.firstNameZ.focus(self)
//    var firstNameZ: LensChannel<Self, String> { return focus(Person.firstNameZ) }
//    var lastNameZ: LensChannel<Self, String> { return focus(Person.lastNameZ) }
//    var genderZ: LensChannel<Self, Person.Gender> { return focus(Person.genderZ) }
//    var homeAddressZ: LensChannel<Self, Address> { return focus(Person.homeAddressZ) }
//    var workAddressZ: LensChannel<Self, Address?> { return focus(Person.workAddressZ) }
//    var previousAddressesZ: LensChannel<Self, [Address]> { return focus(Person.previousAddressesZ) }
//}

extension Address : Focusable {
    static let line1Z = lenZ(\.line1)
    static let line2Z = lenZ(\.line2)
    static let postalCodeZ = lenZ(\.postalCode)
}

//extension ChannelType where Source.Element == Address, Source : TransceiverType, Pulse : MutationType, Pulse.Element == Source.Element {
//    var line1Z: LensChannel<Self, String> { return focus(Address.line1Z) }
//    var line2Z: LensChannel<Self, String?> { return focus(Address.line2Z) }
//    var postalCodeZ: LensChannel<Self, String> { return focus(Address.postalCodeZ) }
//}

//extension ChannelType where Source.Element == Address?, Source : TransceiverType, Pulse : MutationType, Pulse.Element == Source.Element {
//    var line1Z: LensChannel<Self, String?> {
//        let xxx: Lens<Address?, String> = Address.line1Z.maybe()
//        let yyy = focus(lens: xxx)
//        return yyy
//    }
////    var line1Z: LensChannel<Self, String?> { return focus(lens: Address.line1Z.maybe()) }
////    var line2Z: LensChannel<Self, String??> { return focus(lens: Address.line2Z.maybe()) }
////    var postalCodeZ: LensChannel<Self, String?> { return focus(lens: Address.postalCodeZ.maybe()) }
//}

extension ChannelType where Source.Element == Address?, Source : TransceiverType, Pulse : MutationType, Pulse.Element == Source.Element {
//    var line1Z: LensChannel<Self, String?> { return focus(get: { a in a?.line1 }, set: { (a: inout Address?, b: String?) in if let b = b { a?.line1 = b } }) }
//    var line2Z: LensChannel<Self, String??> { return focus(get: { a in a?.line2 }, set: { (a: inout Address?, b: String??) in if let b = b { a?.line2 = b } }) }

//    var line2Z: LensChannel<Self, String??> { return focus({ $0?.line2 }, { if let value = $1 { $0?.line2 = value }  }) }
//    var postalCodeZ: LensChannel<Self, String?> { return focus({ $0?.postalCode }, { if let value = $1 { $0?.postalCode = value }  }) }
}


////protocol Focusable {
////
////}
////
////extension Focusable {
////    static func lens<B>(lens: Lens<Self, B>) -> Lens<Self, B> {
////        return lens
////    }
////
////    static func lensZ<X, Source : StateEmitterType where Source.Element == Self>(lens: Lens<Self, X>) -> Channel<Source, Mutation<Source.Element>> -> Channel<LensSource<Channel<Source, Mutation<Source.Element>>, X>, Mutation<X>> {
////        return { channel in focus(channel)(lens) }
////    }
////
////    static func focus<X, Source : StateEmitterType where Source.Element == Self>(channel: Channel<Source, Mutation<Source.Element>>) -> (Lens<Source.Element, X>) -> Channel<LensSource<Channel<Source, Mutation<Source.Element>>, X>, Mutation<X>> {
////        return channel.focus
////    }
////}
////
////extension Person : Focusable {
////    static let firstNameX = Person.lens(Lens({ $0.firstName }, { $0.firstName = $1 }))
////}

class OpticsTests : ChannelTestCase {
    func createModel() -> Directory {
        let bebe = Person(firstName: "Beatrice", lastName: "Walter",
                          gender: .female,
                          homeAddress: Address(line1: "123 Finite Loop", line2: nil, postalCode: "11223"),
                          workAddress: nil,
                          previousAddresses: [])
        
        let dir = Directory(author: bebe,
                            companies: [
                                Company(employees: [
                                    "359414": Person(firstName: "Marc", lastName: "Walter",
                                                     gender: .male,
                                                     homeAddress: Address(line1: "123 Finite Loop", line2: nil, postalCode: "11223"),
                                                     workAddress: Address(line1: "123 Finite Loop", line2: nil, postalCode: "11223"),
                                                     previousAddresses: [])
                                    ],
                                        ceoID: "359414",
                                        ctoID: nil,
                                        address: Address(line1: "1 NaN Loop", line2: nil, postalCode: "99999"))
            ]
        )

        return dir
    }
    
    func testKeyPathOptics() {
        var dir = createModel()

        let nameKp: WritableKeyPath<Directory, String> = \Directory.author.firstName
        
        XCTAssertEqual("Beatrice", dir[keyPath: nameKp])
        
        dir[keyPath: nameKp] = "Beatrix"
        XCTAssertEqual("Beatrix", dir[keyPath: nameKp])
        
        
    }
    
    func testOptics() {
        var dir = createModel()

//        let firstNameLens = Lens<Person, String>({ $0.firstName }, { $0.firstName = $1 })
//        let lastNameLens = Person.lastNameZ

        dir.companies[0].employees[dir.companies[0].ceoID]?.workAddress?.line2 = "Suite #111"

        do {
            let dirZ = transceive(dir)

            let bebeZ = dirZ.focus(\.author)
            //            let workAddressKP: WritableKeyPath<Person, String?> = \Person.workAddress?.line1 // FIXME: not writeable
            
//            let waddrl1 = waddr.focus(\?.line1)

            
//            bebeZ.focus(Person.homeAddressZ).focus(Address.line1Z).value = "Foo"
            bebeZ.focus(\.homeAddress.line1).value = "Foo"
            bebeZ.focus(\.homeAddress.line2).value = "Bar"
            XCTAssertEqual("Foo", bebeZ.value.homeAddress.line1)
            XCTAssertEqual("Bar", bebeZ.value.homeAddress.line2)

            XCTAssertEqual(nil, bebeZ.value.workAddress?.line1)

            XCTAssertEqual(nil, bebeZ.value.workAddress?.line1)
            XCTAssertEqual(nil, bebeZ.value.workAddress?.line2)

//            bebeZ.focus(\.workAddress?.line1).receive { _ in
//                print("### changed work address)
//            }

            let defaddr = Address(line1: "", line2: nil, postalCode: "")
            bebeZ.focus(\.workAddress).coalesce({ _ in defaddr }).focus(\.line1).value = "AAA"
//            bebeZ.focus(\.workAddress?.line1).value = "AAA"
            bebeZ.focus(\.workAddress).coalesce({ _ in defaddr }).focus(\.line2).value = "BBB"

            XCTAssertEqual("AAA", bebeZ.value.workAddress?.line1)
            XCTAssertEqual("BBB", bebeZ.value.workAddress?.line2)

//            let a1 = bebeZ.focus(Person.homeAddressZ).focus(Address.lenZ(\Address.line1)).sieve(!=).new()
            let a1: Channel<LensSource<Channel<LensSource<Channel<ValueTransceiver<Directory>, Mutation<Directory>>, Person>, Mutation<Person>>, String>, String> = bebeZ.focus(\.homeAddress.line1).sieve(!=).new()
            let a2: Channel<LensSource<Channel<LensSource<Channel<LensSource<Channel<LensSource<Channel<ValueTransceiver<Directory>, Mutation<Directory>>, Person>, Mutation<Person>>, Address?>, Mutation<Address?>>, Address>, Mutation<Address>>, String>, String> = bebeZ.focus(Person.workAddressZ).coalesce({ _ in defaddr }).focus(Address.line1Z).sieve(!=).new()
            let b1 = bebeZ.focus(\.homeAddress.line2).sieve(!=).new()
            let b2 = bebeZ.focus(Person.workAddressZ).coalesce({ _ in defaddr }).focus(Address.line2Z).sieve(!=).new()

//            bebeZ.focus(\.homeAddress).bind(bebeZ.focus(\.workAddress))
            
            a1.bind(a2) // works from home
            b1.bind(b2) // works from home

            bebeZ.value.workAddress?.line1 = "XXX"
            XCTAssertEqual("XXX", bebeZ.value.homeAddress.line1)
            XCTAssertEqual("XXX", bebeZ.value.workAddress?.line1)

            bebeZ.focus(\.homeAddress.line1).value = "YYY"
            XCTAssertEqual("YYY", bebeZ.value.homeAddress.line1)
            XCTAssertEqual("YYY", bebeZ.value.workAddress?.line1)

            bebeZ.focus(Person.workAddressZ).coalesce({ _ in defaddr }).focus(Address.line1Z).value = "ZZZ"
            XCTAssertEqual("ZZZ", bebeZ.value.homeAddress.line1)
            XCTAssertEqual("ZZZ", bebeZ.value.workAddress?.line1)

//            let prevZ = bebeZ.previousAddressesZ
            let prevZ = bebeZ.focus(Person.previousAddressesZ)

            var lines: [String?] = []

            prevZ.index(1).focus(Address.line1Z.prism).sieve().new().receive({ lines.append($0) })
            //prevZ.focus(\.[1].line1).sieve().new().receive({ lines.append($0) }) // works, but crashes when getting with no index #1

            XCTAssertEqual(0, bebeZ.value.previousAddresses.count)
            prevZ.index(2).coalesce({ _ in defaddr }).focus(Address.line1Z).value = "XYZ"
            XCTAssertEqual(3, bebeZ.value.previousAddresses.count)
            XCTAssertEqual(["XYZ", "XYZ", "XYZ"], bebeZ.value.previousAddresses.map({ $0.line1 }))

            prevZ.index(1).coalesce({ _ in defaddr }).focus(Address.line1Z).value = "ABC"
            XCTAssertEqual(["XYZ", "ABC", "XYZ"], bebeZ.value.previousAddresses.map({ $0.line1 }))


            XCTAssertEqual(["XYZ", "ABC"].flatMap({ $0 }), lines.flatMap({ $0 }))

            let line1sZ = prevZ.prism(Address.line1Z)

            XCTAssertEqual(["XYZ", "ABC", "XYZ"], line1sZ.value)

            line1sZ.value = ["123", "123", "123"]
            XCTAssertEqual(["123", "123", "123"], line1sZ.value)

            line1sZ.value = ["QQQ"] // a prism set to a subset will only apply to the subset
            XCTAssertEqual(["QQQ", "123", "123"], line1sZ.value)


            // sets the last two elements of the lensed collection, ignoring any trail-offs
            //            prevZ.range(1...2).prism(Address.line1Z).$ = ["PRQ", "PRQ", "PRQ", "PRQ"] // FIXME: closed range error
            prevZ.indices([1,2]).prism(Address.line1Z).value = ["PRQ", "PRQ", "PRQ", "PRQ"]
            XCTAssertEqual(["QQQ", "PRQ", "PRQ"], line1sZ.value)


            // check non-contiguous index access
            prevZ.indices([2, 0, 1]).prism(Address.line1Z).value = ["Z", "X", "Y"]
            XCTAssertEqual(["X", "Y", "Z"], line1sZ.value)

            // creates a "select" combination of collection and index channels
            let indexChannel = transceive([0])
            let selectZ = prevZ.indexed(indexChannel).prism(Address.line1Z) // Swift 3 compiler crash!

            let seltrap = selectZ.trap(Int.max)
            
            XCTAssertEqual(["X"], selectZ.value)

            XCTAssertEqual(2, seltrap.caught.count)

            // changing the index changes the underlying prism
            indexChannel.value = [2, 0]
            XCTAssertEqual(["Z", "X"], selectZ.value)
            XCTAssertEqual(3, seltrap.caught.count)


            // changing the values changes the underlying prism
            line1sZ.value = ["A", "B", "C"]
            XCTAssertEqual(["C", "A"], selectZ.value)
            XCTAssertEqual(["A", "B", "C"], line1sZ.value)
            XCTAssertEqual(4, seltrap.caught.count)

            selectZ.value = ["Q", "T"]
            XCTAssertEqual(["Q", "T"], selectZ.value)
            XCTAssertEqual(["T", "B", "Q"], line1sZ.value)
            XCTAssertEqual(5, seltrap.caught.count)

            // invalidating an index drops the last selection
            prevZ.value.removeLast()
            XCTAssertEqual(["T"], selectZ.value)
            XCTAssertEqual(6, seltrap.caught.count)

            indexChannel.value = Array((0...999).reversed()) // go outside the bounds
            XCTAssertEqual(["B", "T"], selectZ.value)
            XCTAssertEqual(["T", "B"], line1sZ.value)

            selectZ.value = [ "Y", "X" ] // does nothing, since 999 & 998 are outside the range
            XCTAssertEqual(["T", "B"], line1sZ.value)

            indexChannel.value = Array((0...999)) // go outside the bounds
            selectZ.value = [ "Y", "X" ] // does nothing, since 999 & 998 are outside the range
            XCTAssertEqual(["Y", "X"], line1sZ.value)

            selectZ.value = Array(repeating: "T", count: 2)
            XCTAssertEqual(["T", "T"], line1sZ.value)

            var persons: [Person] = []
            let company = dirZ.focus(Directory.companiesZ).index(0).coalesce({ _ in nil as Company! })

            company.focus(Company.employeesZ).at("359414").val().some().receive { person in
                persons.append(person)
            }

            let empnameZ = company.focus(Company.employeesZ).at("359414").coalesce({ _ in nil as Person! }).focus(Person.firstNameZ)
            empnameZ.value = "Marcus"

            XCTAssertEqual("Marcus", dirZ.value.companies.first?.employees["359414"]?.firstName)

            // now add two more employees and edit mutliple aspects of them

            let doeHome = Address(line1: "123 Doe Lane", line2: nil, postalCode: "44556")

            company.focus(Company.employeesZ).value["888888"] = Person(firstName: "John", lastName: "Doe", gender: .male, homeAddress: doeHome, workAddress: nil, previousAddresses: [])
            company.focus(Company.employeesZ).value["999999"] = Person(firstName: "Jane", lastName: "Doe", gender: .female, homeAddress: doeHome, workAddress: nil, previousAddresses: [])

            XCTAssertEqual(dirZ.value.companies.flatMap({ $0.employees.values }).count, 3)

            // TODO: generalize select() to work on collections and dictionaries
            let keysChannel = transceive(["888888"])
            let keyedZ: Channel<LensSource<Channel<LensSource<Channel<LensSource<Channel<LensSource<Channel<LensSource<Channel<ValueTransceiver<Directory>, Mutation<Directory>>, [Company]>, Mutation<[Company]>>, Company?>, Mutation<Company?>>, Company>, Mutation<Company>>, [PersonID : Person]>, Mutation<[PersonID : Person]>>, [Person?]>, Mutation<[Person?]>> = company.focus(Company.employeesZ).keyed(keysChannel) // Swift 3 compiler crash

            let empselZ = keyedZ.prism(Person.lastNameZ.prism)
            let empseltrap = empselZ.trap(Int.max)

            XCTAssertEqual(3, company.focus(Company.employeesZ).value.count)

            XCTAssertEqual(2, empseltrap.caught.count)
            XCTAssertEqual(["Doe"], empseltrap.value?.new.flatMap({ $0 }) ?? [])

            keysChannel.value += ["NaN", "999999"]
            XCTAssertEqual(3, empseltrap.caught.count)
            XCTAssertEqual(["Doe", "Doe"], empseltrap.value?.new.flatMap({ $0 }) ?? [])

            empselZ.value = ["A", "B"] // missing key won't be updated
            XCTAssertEqual(4, empseltrap.caught.count)
            XCTAssertEqual(3, company.focus(Company.employeesZ).value.count)

            XCTAssertEqual(["A", "Doe"], empseltrap.value?.new.flatMap({ $0 }) ?? [])

            empselZ.value = ["X", "Y", "Z"]
            XCTAssertEqual(5, empseltrap.caught.count)
            XCTAssertEqual(3, company.focus(Company.employeesZ).value.count)
            XCTAssertEqual("X", empseltrap.value?.new[0])
            XCTAssertEqual(nil, empseltrap.value?.new[1])
            XCTAssertEqual("Z", empseltrap.value?.new[2])

            empselZ.value = [nil, nil, nil] // no effect since lastName is non-nullable
            XCTAssertEqual(6, empseltrap.caught.count)
            XCTAssertEqual(3, company.focus(Company.employeesZ).value.count)
            XCTAssertEqual(3, empseltrap.value?.new.count)
            if empseltrap.value?.new.count == 3 {
                XCTAssertEqual("X", empseltrap.value?.new[0])
                XCTAssertEqual(nil, empseltrap.value?.new[1])
                XCTAssertEqual("Z", empseltrap.value?.new[2])
            }

            // include duplicates in the channel
            keysChannel.value = ["999999", "888888", "999999", "888888", "999999"]
            empselZ.value = ["A", "B", "C", "D", "E"]
            XCTAssertEqual(5, empseltrap.value?.new.count)
            if empseltrap.value?.new.count == 5 {
                XCTAssertEqual("E", empseltrap.value?.new[0])
                XCTAssertEqual("D", empseltrap.value?.new[1])
                XCTAssertEqual("E", empseltrap.value?.new[2])
                XCTAssertEqual("D", empseltrap.value?.new[3])
                XCTAssertEqual("E", empseltrap.value?.new[4])
            }
            XCTAssertEqual(company.focus(Company.employeesZ).value["888888"]?.lastName, "D")
            XCTAssertEqual(company.focus(Company.employeesZ).value["999999"]?.lastName, "E")
        }
    }

//    func testLensChannels() {
//        let prop = transceive((int: 1, dbl: 2.2, str: "Foo", sub: (a: true, b: 22, c: "")))
//
//        let str = prop.focus({ $0.str }, { $0.str = $1 })
//        let int = prop.focus({ $0.int }, { $0.int = $1 })
//        let dbl = prop.focus({ $0.dbl }, { $0.dbl = $1 })
//        let sub = prop.focus({ $0.sub }, { $0.sub = $1 })
//        let suba = sub.focus({ $0.a }, { $0.a = $1 })
//        let subb = sub.focus({ $0.b }, { $0.b = $1 })
//        let subc = sub.focus({ $0.c }, { $0.c = $1 })
//
//        // subc = Channel<LensSource<Channel<LensSource<Channel<ValueTransceiver<X>, Mutation<X>>, Y>, Mutation<Y>>, String>, Mutation<String>>
//
//        str.$ = "Bar"
//        int.$ = 2
//        dbl.$ = 5.5
//
//        suba.$ = false
//        subb.$ = 999
//        subc.$ = "x"
//
//        XCTAssertEqual(prop.$.str, "Bar")
//        XCTAssertEqual(prop.$.int, 2)
//        XCTAssertEqual(prop.$.dbl, 5.5)
//
//        XCTAssertEqual(prop.$.sub.a, false)
//        XCTAssertEqual(prop.$.sub.b, 999)
//        XCTAssertEqual(prop.$.sub.c, "x")
//
//        // children can affect parent values and it will update state and fire receivers
//        var strUpdates = 0
//        var strChanges = 0
//        str.subsequent().receive({ _ in strUpdates += 1 })
//        str.subsequent().sieve(!=).receive({ _ in strChanges += 1 })
//        XCTAssertEqual(0, strChanges)
//
//        subc.owner.owner.$.str = "Baz"
//        XCTAssertEqual(prop.$.str, "Baz")
//        XCTAssertEqual(1, strUpdates)
//        XCTAssertEqual(1, strChanges)
//
//        subc.owner.$.b = 7
//        XCTAssertEqual(prop.$.sub.b, 7)
//        XCTAssertEqual(2, strUpdates) // note that str changes even when a different property changed
//        XCTAssertEqual(1, strChanges) // so we sieve for changes
//
//        subc.owner.owner.$.str = "Baz"
//
//        let compound = str.new() & subb.new()
////        dump(compound)
//        compound.receive { str, int in
//            XCTAssertEqual("Baz", str)
//            XCTAssertEqual(7, int)
//        }
//
////        dump(compound.$)
////        let MVλ = 1
//    }
}
