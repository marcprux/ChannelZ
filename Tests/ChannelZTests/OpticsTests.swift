//
//  OpticsTests.swift
//  ChannelZ
//
//  Created by Marc Prud'hommeaux on 5/1/16.
//  Copyright © 2016 glimpse.io. All rights reserved.
//

import ChannelZ
import XCTest
import Foundation

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
    var thing: Thing?
    
    enum Gender { case male, female }
}

struct Address {
    var line1: String
    var line2: String?
    var postalCode: String
}

protocol Thing {
}

enum BinaryThing : Thing {
    case trueThing
    case falseThing
}

extension NSNull : Thing {
}

struct StringThing : Thing, LosslessStringConvertible {
    var description: String
    
    public init?(_ description: String) {
        self.description = description
    }
}

class AnyThing<T> : Thing {
    var it: T
    
    public init(_ it: T) {
        self.it = it
    }
}

class OpticsTests : ChannelTestCase {
    func createModel() -> Directory {
        let bebe = Person(firstName: "Beatrice", lastName: "Walter",
                          gender: .female,
                          homeAddress: Address(line1: "123 Finite Loop", line2: nil, postalCode: "11223"),
                          workAddress: nil,
                          previousAddresses: [],
                          thing: NSNull())
        
        let dir = Directory(author: bebe,
                            companies: [
                                Company(employees: [
                                    "359414": Person(firstName: "Marc", lastName: "Walter",
                                                     gender: .male,
                                                     homeAddress: Address(line1: "123 Finite Loop", line2: nil, postalCode: "11223"),
                                                     workAddress: Address(line1: "123 Finite Loop", line2: nil, postalCode: "11223"),
                                                     previousAddresses: [],
                                                     thing: NSNull())
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
            bebeZ.focus(\.homeAddress.line1).rawValue = "Foo"
            bebeZ.focus(\.homeAddress.line2).rawValue = "Bar"
            XCTAssertEqual("Foo", bebeZ.rawValue.homeAddress.line1)
            XCTAssertEqual("Bar", bebeZ.rawValue.homeAddress.line2)

            XCTAssertEqual(nil, bebeZ.rawValue.workAddress?.line1)

            XCTAssertEqual(nil, bebeZ.rawValue.workAddress?.line1)
            XCTAssertEqual(nil, bebeZ.rawValue.workAddress?.line2)

//            bebeZ.focus(\.workAddress?.line1).receive { _ in
//                print("### changed work address)
//            }

            let defaddr = Address(line1: "", line2: nil, postalCode: "")
            let defperson = Person(firstName: "", lastName: "", gender: .male, homeAddress: defaddr, workAddress: nil, previousAddresses: [], thing: nil)
            let defcompany = Company(employees: [:], ceoID: "", ctoID: nil, address: defaddr)

            bebeZ.focus(\.workAddress).coalesce({ _ in defaddr }).focus(\.line1).rawValue = "AAA"
//            bebeZ.focus(\.workAddress?.line1).value = "AAA"
            bebeZ.focus(\.workAddress).coalesce({ _ in defaddr }).focus(\.line2).rawValue = "BBB"

            XCTAssertEqual("AAA", bebeZ.rawValue.workAddress?.line1)
            XCTAssertEqual("BBB", bebeZ.rawValue.workAddress?.line2)

//            let a1 = bebeZ.focus(Person.homeAddressZ).focus(Address.lenZ(\Address.line1)).sieve(!=).new()
            let a1: Channel<LensSource<Channel<LensSource<Channel<ValueTransceiver<Directory>, Mutation<Directory>>, Person>, Mutation<Person>>, String>, String> = bebeZ.focus(\.homeAddress.line1).sieve(!=).new()
            let a2: Channel<LensSource<Channel<LensSource<Channel<LensSource<Channel<LensSource<Channel<ValueTransceiver<Directory>, Mutation<Directory>>, Person>, Mutation<Person>>, Address?>, Mutation<Address?>>, Address>, Mutation<Address>>, String>, String> = bebeZ.focus(\.workAddress).coalesce({ _ in defaddr }).focus(\.line1).sieve(!=).new()
            let b1 = bebeZ.focus(\.homeAddress.line2).sieve(!=).new()
            let b2 = bebeZ.focus(\.workAddress).coalesce({ _ in defaddr }).focus(\.line2).sieve(!=).new()

//            bebeZ.focus(\.homeAddress).bind(bebeZ.focus(\.workAddress))
            
            a1.bind(a2) // works from home
            b1.bindOptionalPulseToPulse(b2)
//            b1.bind(b2) // works from home

            bebeZ.rawValue.workAddress?.line1 = "XXX"
            XCTAssertEqual("XXX", bebeZ.rawValue.homeAddress.line1)
            XCTAssertEqual("XXX", bebeZ.rawValue.workAddress?.line1)

            bebeZ.focus(\.homeAddress.line1).rawValue = "YYY"
            XCTAssertEqual("YYY", bebeZ.rawValue.homeAddress.line1)
            XCTAssertEqual("YYY", bebeZ.rawValue.workAddress?.line1)

            bebeZ.focus(\.workAddress).coalesce({ _ in defaddr }).focus(\.line1).rawValue = "ZZZ"
            XCTAssertEqual("ZZZ", bebeZ.rawValue.homeAddress.line1)
            XCTAssertEqual("ZZZ", bebeZ.rawValue.workAddress?.line1)

//            let prevZ = bebeZ.previousAddressesZ
            let prevZ = bebeZ.focus(\.previousAddresses)

            var lines: [String?] = []

            prevZ.indexOf(1).focus(lens: Lens(kp: \.line1).prism).sieve().new().receive({ lines.append($0) })
            //prevZ.focus(\.[1].line1).sieve().new().receive({ lines.append($0) }) // works, but crashes when getting with no index #1

            XCTAssertEqual(0, bebeZ.rawValue.previousAddresses.count)
            prevZ.indexOf(2).coalesce({ _ in defaddr }).focus(\.line1).rawValue = "XYZ"
            XCTAssertEqual(3, bebeZ.rawValue.previousAddresses.count)
            XCTAssertEqual(["XYZ", "XYZ", "XYZ"], bebeZ.rawValue.previousAddresses.map({ $0.line1 }))

            prevZ.indexOf(1).coalesce({ _ in defaddr }).focus(\.line1).rawValue = "ABC"
            XCTAssertEqual(["XYZ", "ABC", "XYZ"], bebeZ.rawValue.previousAddresses.map({ $0.line1 }))


            XCTAssertEqual(["XYZ", "ABC"].compactMap({ $0 }), lines.compactMap({ $0 }))

            let line1sZ = prevZ.prism(\.line1)

            XCTAssertEqual(["XYZ", "ABC", "XYZ"], line1sZ.rawValue)

            line1sZ.rawValue = ["123", "123", "123"]
            XCTAssertEqual(["123", "123", "123"], line1sZ.rawValue)

            line1sZ.rawValue = ["QQQ"] // a prism set to a subset will only apply to the subset
            XCTAssertEqual(["QQQ", "123", "123"], line1sZ.rawValue)


            // sets the last two elements of the lensed collection, ignoring any trail-offs
            //            prevZ.range(1...2).prism(Address.line1Z).$ = ["PRQ", "PRQ", "PRQ", "PRQ"] // FIXME: closed range error
            let idx1 = transceive([1, 2])
            prevZ.indices(idx1).prism(\.line1).rawValue = ["PRQ", "PRQ", "PRQ", "PRQ"]
            XCTAssertEqual(["QQQ", "PRQ", "PRQ"], line1sZ.rawValue)
            XCTAssertEqual([1, 2], idx1.rawValue)

            // check non-contiguous index access
            let idx2 = transceive([2, 0, 1])
            prevZ.indices(idx2).prism(\.line1).rawValue = ["Z", "X", "Y"]
            XCTAssertEqual(["X", "Y", "Z"], line1sZ.rawValue)
            XCTAssertEqual([2, 0, 1], idx2.rawValue)
            
            // creates a "select" combination of collection and index channels
            let indexChannel = transceive([0])
            let selectZ = prevZ.indices(indexChannel).prism(\.line1) // Swift 3 compiler crash!

            let seltrap = selectZ.trap(Int.max)
            
            XCTAssertEqual(["X"], selectZ.rawValue)

            XCTAssertEqual(2, seltrap.caught.count)

            // changing the index changes the underlying prism
            indexChannel.rawValue = [2, 0]
            XCTAssertEqual(["Z", "X"], selectZ.rawValue)
            XCTAssertEqual(3, seltrap.caught.count)


            // changing the values changes the underlying prism
            line1sZ.rawValue = ["A", "B", "C"]
            XCTAssertEqual(["C", "A"], selectZ.rawValue)
            XCTAssertEqual(["A", "B", "C"], line1sZ.rawValue)
            XCTAssertEqual(4, seltrap.caught.count)

            selectZ.rawValue = ["Q", "T"]
            XCTAssertEqual(["Q", "T"], selectZ.rawValue)
            XCTAssertEqual(["T", "B", "Q"], line1sZ.rawValue)
            XCTAssertEqual(5, seltrap.caught.count)

            // invalidating an index drops the last selection
            prevZ.rawValue.removeLast()
            XCTAssertEqual(["T"], selectZ.rawValue)
            XCTAssertEqual(6, seltrap.caught.count)

            indexChannel.rawValue = Array((0...999).reversed()) // go outside the bounds
            XCTAssertEqual(["B", "T"], selectZ.rawValue)
            XCTAssertEqual(["T", "B"], line1sZ.rawValue)

            selectZ.rawValue = [ "Y", "X" ] // does nothing, since 999 & 998 are outside the range
            XCTAssertEqual(["T", "B"], line1sZ.rawValue)

            indexChannel.rawValue = Array((0...999)) // go outside the bounds
            selectZ.rawValue = [ "Y", "X" ] // does nothing, since 999 & 998 are outside the range
            XCTAssertEqual(["Y", "X"], line1sZ.rawValue)

            selectZ.rawValue = Array(repeating: "T", count: 2)
            XCTAssertEqual(["T", "T"], line1sZ.rawValue)

            var persons: [Person] = []
            let company = dirZ.focus(\.companies).indexOf(0).coalesce({ _ in defcompany })

            company.focus(\.employees).atKey("359414").raw().some().receive { person in
                persons.append(person)
            }

            let empnameZ = company.focus(\.employees).atKey("359414").coalesce({ _ in defperson }).focus(\.firstName)
            empnameZ.rawValue = "Marcus"

            XCTAssertEqual("Marcus", dirZ.rawValue.companies.first?.employees["359414"]?.firstName)

            // now add two more employees and edit mutliple aspects of them

            let doeHome = Address(line1: "123 Doe Lane", line2: nil, postalCode: "44556")

            let emps = company.focus(\.employees)
            let emp888888 = Person(firstName: "John", lastName: "Doe", gender: .male, homeAddress: doeHome, workAddress: nil, previousAddresses: [], thing: BinaryThing.trueThing)
            let emp999999 = Person(firstName: "Jane", lastName: "Doe", gender: .female, homeAddress: doeHome, workAddress: nil, previousAddresses: [], thing: BinaryThing.trueThing)
            emps.rawValue["888888"] = emp888888
            emps.rawValue["999999"] = emp999999

            XCTAssertEqual(dirZ.rawValue.companies.flatMap({ $0.employees.values }).count, 3)

            // TODO: generalize select() to work on collections and dictionaries
            let keysChannel = transceive(["888888"])
            
            let employeeFocus = company.focus(\.employees)
            
            let keyedZ = employeeFocus.keyed(keysChannel) // Swift 3 compiler crash

            let empselZ = keyedZ.prism(Lens(kp: \.lastName).prism)
            let empseltrap = empselZ.trap(Int.max)

            XCTAssertEqual(3, company.focus(\.employees).rawValue.count)

            XCTAssertEqual(2, empseltrap.caught.count)
            XCTAssertEqual(["Doe"], empseltrap.value?.new.compactMap({ $0 }) ?? [])

            keysChannel.rawValue += ["NaN", "999999"]
            XCTAssertEqual(3, empseltrap.caught.count)
            XCTAssertEqual(["Doe", "Doe"], empseltrap.value?.new.compactMap({ $0 }) ?? [])

            empselZ.rawValue = ["A", "B"] // missing key won't be updated
            XCTAssertEqual(4, empseltrap.caught.count)
            XCTAssertEqual(3, company.focus(\.employees).rawValue.count)

            XCTAssertEqual(["A", "Doe"], empseltrap.value?.new.compactMap({ $0 }) ?? [])

            empselZ.rawValue = ["X", "Y", "Z"]
            XCTAssertEqual(5, empseltrap.caught.count)
            XCTAssertEqual(3, company.focus(\.employees).rawValue.count)
            XCTAssertEqual("X", empseltrap.value?.new[0])
            XCTAssertEqual(nil, empseltrap.value?.new[1])
            XCTAssertEqual("Z", empseltrap.value?.new[2])

            empselZ.rawValue = [nil, nil, nil] // no effect since lastName is non-nullable
            XCTAssertEqual(6, empseltrap.caught.count)
            XCTAssertEqual(3, company.focus(\.employees).rawValue.count)
            XCTAssertEqual(3, empseltrap.value?.new.count)
            if empseltrap.value?.new.count == 3 {
                XCTAssertEqual("X", empseltrap.value?.new[0])
                XCTAssertEqual(nil, empseltrap.value?.new[1])
                XCTAssertEqual("Z", empseltrap.value?.new[2])
            }

            // include duplicates in the channel
            keysChannel.rawValue = ["999999", "888888", "999999", "888888", "999999"]
            empselZ.rawValue = ["A", "B", "C", "D", "E"]
            XCTAssertEqual(5, empseltrap.value?.new.count)
            if empseltrap.value?.new.count == 5 {
                XCTAssertEqual("E", empseltrap.value?.new[0])
                XCTAssertEqual("D", empseltrap.value?.new[1])
                XCTAssertEqual("E", empseltrap.value?.new[2])
                XCTAssertEqual("D", empseltrap.value?.new[3])
                XCTAssertEqual("E", empseltrap.value?.new[4])
            }
            XCTAssertEqual(company.focus(\.employees).rawValue["888888"]?.lastName, "D")
            XCTAssertEqual(company.focus(\.employees).rawValue["999999"]?.lastName, "E")
            
            // protocol-based value casting
            do {
                let thingZ = bebeZ.focus(\.thing)
                let thingAsStringZ = thingZ.cast(StringThing.self)
                let thingAsBinaryZ = thingZ.cast(BinaryThing.self)
                let thingAsNullZ = thingZ.cast(NSNull.self)
                let thingAsXThingZ = thingZ.cast(AnyThing<Int>.self)

                thingZ.rawValue = BinaryThing.falseThing
                XCTAssertNil(thingAsStringZ.rawValue)
                XCTAssertNotNil(thingAsBinaryZ.rawValue)
                XCTAssertEqual(thingAsBinaryZ.rawValue, .falseThing)
                XCTAssertNil(thingAsNullZ.rawValue)
                XCTAssertNil(thingAsXThingZ.rawValue)

                thingZ.rawValue = NSNull()
                XCTAssertNil(thingAsStringZ.rawValue)
                XCTAssertNil(thingAsBinaryZ.rawValue)
                XCTAssertNotNil(thingAsNullZ.rawValue)
                XCTAssertNil(thingAsXThingZ.rawValue)

                thingZ.rawValue = StringThing("Hello")
                XCTAssertEqual(thingAsStringZ.rawValue?.description, "Hello")
                XCTAssertNil(thingAsBinaryZ.rawValue)
                XCTAssertNil(thingAsNullZ.rawValue)
                XCTAssertNil(thingAsXThingZ.rawValue)

                thingZ.rawValue = AnyThing<Int>(5)
                XCTAssertNil(thingAsStringZ.rawValue)
                XCTAssertNil(thingAsBinaryZ.rawValue)
                XCTAssertNil(thingAsNullZ.rawValue)
                XCTAssertNotNil(thingAsXThingZ.rawValue)
                XCTAssertEqual(thingAsXThingZ.rawValue?.it, 5)

                thingAsStringZ.rawValue = StringThing("Goodbye")
                XCTAssertEqual(thingAsStringZ.rawValue?.description, "Goodbye")
                XCTAssertNil(thingAsBinaryZ.rawValue)
                XCTAssertNil(thingAsNullZ.rawValue)
                XCTAssertNil(thingAsXThingZ.rawValue)

                thingZ.rawValue = BinaryThing.trueThing
                XCTAssertNil(thingAsStringZ.rawValue)
                XCTAssertNotNil(thingAsBinaryZ.rawValue)
                XCTAssertEqual(thingAsBinaryZ.rawValue, .trueThing)
                XCTAssertNil(thingAsNullZ.rawValue)
                XCTAssertNil(thingAsXThingZ.rawValue)

                thingZ.rawValue = .none
                XCTAssertNil(thingAsStringZ.rawValue)
                XCTAssertNil(thingAsBinaryZ.rawValue)
                XCTAssertNil(thingAsNullZ.rawValue)
                XCTAssertNil(thingAsXThingZ.rawValue)
            }
            
            do { // now check indexed channels
                let arr = transceive(["A", "B", "C"])
                let idx = transceive([0, 1, 2])
                let ichan = arr.indices(idx)
                XCTAssertEqual(["A", "B", "C"], ichan.rawValue)
                idx.rawValue = [0, 2]
                XCTAssertEqual(["A", "C"], ichan.rawValue)
                idx.rawValue = []
                XCTAssertEqual([], ichan.rawValue)
                idx.rawValue = [0, 1, 2, 3]
                XCTAssertEqual(["A", "B", "C"], ichan.rawValue)
                
                ichan.rawValue = ["A"]
                XCTAssertEqual([0, 1, 2, 3], idx.rawValue)
            }
            
            do { // now check single indexed channels
                let arr = transceive(["A", "B", "C"])
                let idx = transceive(Optional<Int>.some(1))

                let ichan = arr.index(idx)

                XCTAssertEqual("B", ichan.rawValue)
                idx.rawValue = 2
                XCTAssertEqual("C", ichan.rawValue)
                idx.rawValue = .none
                XCTAssertEqual(nil, ichan.rawValue)
                idx.rawValue = 0
                XCTAssertEqual("A", ichan.rawValue)
                idx.rawValue = 8
                XCTAssertEqual(nil, ichan.rawValue)
                idx.rawValue = 1
                XCTAssertEqual("B", ichan.rawValue)
                arr.rawValue = ["X", "Y", "Z"]
                XCTAssertEqual("Y", ichan.rawValue)
                arr.rawValue = ["Q"]
                XCTAssertEqual(nil, ichan.rawValue)
            }
            
//            do { // now check index channels to maps
//                let map = transceive([0: "A", 1: "B", 2: "C"])
//                let idx = transceive(Optional<Int>.some(1))
//
//                let ichan = map.at(idx)
//                XCTAssertEqual("B", ichan.value)
//                idx.value = 2
//                XCTAssertEqual("C", ichan.value)
//                idx.value = .none
//                XCTAssertEqual(nil, ichan.value)
//                idx.value = 0
//                XCTAssertEqual("A", ichan.value)
//                idx.value = 8
//                XCTAssertEqual(nil, ichan.value)
//                idx.value = 1
//                XCTAssertEqual("B", ichan.value)
//                map.value = [0: "X", 1: "Y", 2: "Z"]
//                XCTAssertEqual("Y", ichan.value)
//                map.value = [9: "Q"]
//                XCTAssertEqual(nil, ichan.value)
//            }

        }
    }
    
    #if os(macOS) || os(iOS)

    /// Tests optical views into immutable models using channels
    @available(macOS 10.11, iOS 9.0, *) // UndoManager only available
    func testOpticals() {
        
        
        class OpticalDirectory<T: ChannelType>: Optical where T.Source : TransceiverType, T.Pulse : MutationType, T.Pulse.RawValue == T.Source.RawValue, T.Pulse.RawValue == Directory {
            let optic: T

            lazy var authorZ = optic.focus(\.author)
            lazy var companiesZ = optic.focus(\.companies)

            // sub-opticals
            
            lazy var author = OpticalPerson(authorZ)
            
            // derived channels
            
            lazy var selectedCompanyIndices = transceive([Int]())
            lazy var selectedCompanies = companiesZ.indices(selectedCompanyIndices)

            required init(_ optic: T) {
                self.optic = optic
            }

        }
        
        class OpticalCompany<T: ChannelType>: Optical where T.Source : TransceiverType, T.Pulse : MutationType, T.Pulse.RawValue == T.Source.RawValue, T.Pulse.RawValue == Company {
            let optic: T
            
            lazy var employeesZ = optic.focus(\.employees)
            lazy var ceoIDZ = optic.focus(\.ceoID)
            lazy var ctoIDZ = optic.focus(\.ctoID)
            lazy var addressZ = optic.focus(\.address)

            // derived channels

//            lazy var ceoPerson = employeesZ.atKey(ceoIDZ)

            required init(_ optic: T) {
                self.optic = optic
            }
        }
        
        class OpticalPerson<T: ChannelType>: Optical where T.Source : TransceiverType, T.Pulse : MutationType, T.Pulse.RawValue == T.Source.RawValue, T.Pulse.RawValue == Person {
            let optic: T
            
            lazy var firstNameZ = optic.focus(\.firstName)
            lazy var lastNameZ = optic.focus(\.lastName)
            lazy var genderZ = optic.focus(\.gender)
            lazy var homeAddressZ = optic.focus(\.homeAddress)
            lazy var workAddressZ = optic.focus(\.workAddress)
            lazy var previousAddressesZ = optic.focus(\.previousAddresses)
            lazy var thingZ = optic.focus(\.thing)
            
            /// A channel that produces the current full name
            lazy var fullNameZ = firstNameZ.combine(lastNameZ).map({ Mutation<String>(old: ($0.0.old ?? "") + " " + ($0.1.old ?? ""), new: $0.0.new + " " + $0.1.new) })
            
            required init(_ optic: T) {
                self.optic = optic
            }
            
            /// Shorten the first and last names to just the first initials
            func abbreviateName() {
                firstNameZ.rawValue = firstNameZ.rawValue.first.flatMap(String.init) ?? ""
                lastNameZ.rawValue = lastNameZ.rawValue.first.flatMap(String.init) ?? ""
            }
        }
        
        class OpticalAddress<T: ChannelType>: Optical where T.Source : TransceiverType, T.Pulse : MutationType, T.Pulse.RawValue == T.Source.RawValue, T.Pulse.RawValue == Address {
            let optic: T
            
            lazy var line1Z = optic.focus(\.line1)
            lazy var line2Z = optic.focus(\.line2)
            lazy var postalCodeZ = optic.focus(\.postalCode)

            required init(_ optic: T) {
                self.optic = optic
            }
        }
        
        let dir = transceive(createModel())
        let odir = OpticalDirectory(dir)

        let um = UndoManager()
        um.groupsByEvent = false
        um.levelsOfUndo = Int.max
        
        let fullNames = odir.author.fullNameZ.new().trap()
        
        let schan1 = transceive("")
        let schan2 = transceive("")
        schan1.link(schan2)
        odir.author.firstNameZ.link(schan2)

        XCTAssertEqual(fullNames.value, "Beatrice Walter")
        XCTAssertEqual(odir.author.firstNameZ.rawValue, "Beatrice")
        XCTAssertEqual(odir.author.firstNameZ.rawValue, odir.authorZ.rawValue.firstName)
        
        // the author optical can perform state changes that will be seen by the owning opticals
        XCTAssertEqual(0, undoCounter)
        odir.author.undoable(um) { $0.abbreviateName() }
        XCTAssertEqual(1, undoCounter)
        XCTAssertEqual(odir.author.firstNameZ.rawValue, "B")
        XCTAssertEqual(odir.author.firstNameZ.rawValue, odir.optic.rawValue.author.firstName)
        XCTAssertEqual(fullNames.value, "B W")

        for i in 1...10 {
            um.undo()
            XCTAssertEqual((i*2), undoCounter)
            XCTAssertEqual(odir.author.firstNameZ.rawValue, "Beatrice")
            XCTAssertEqual(schan1.rawValue, "Beatrice")
            XCTAssertEqual(odir.author.firstNameZ.rawValue, odir.optic.rawValue.author.firstName)
            XCTAssertEqual(fullNames.value, "Beatrice Walter")

            um.redo()
            XCTAssertEqual(odir.author.firstNameZ.rawValue, "B")
            XCTAssertEqual(schan1.rawValue, "B")
            XCTAssertEqual(odir.author.firstNameZ.rawValue, odir.optic.rawValue.author.firstName)
            XCTAssertEqual(fullNames.value, "B W")
        }

        odir.undoable(um) { $0.author.firstNameZ.rawValue = "X" }
        XCTAssertEqual(odir.author.firstNameZ.rawValue, "X")
        odir.undoable(um) { $0.author.firstNameZ.rawValue = "Y" }
        XCTAssertEqual(odir.author.firstNameZ.rawValue, "Y")
        odir.undoable(um) { $0.author.firstNameZ.rawValue = "Z" }
        XCTAssertEqual(odir.author.firstNameZ.rawValue, "Z")

        um.undo()
        XCTAssertEqual(odir.author.firstNameZ.rawValue, "Y")
        um.undo()
        XCTAssertEqual(odir.author.firstNameZ.rawValue, "X")
        um.undo()
        XCTAssertEqual(odir.author.firstNameZ.rawValue, "B")

        
        for i in 1...10 {
            odir.author.undoable(um) { $0.firstNameZ.rawValue = "\(i)" }
        }
        XCTAssertEqual(odir.author.firstNameZ.rawValue, "10")

        for i in (1...9).reversed() {
            um.undo()
            XCTAssertEqual(odir.author.firstNameZ.rawValue, "\(i)")
        }

        for i in 2...10 {
            um.redo()
            XCTAssertEqual(odir.author.firstNameZ.rawValue, "\(i)")
        }
    }
    
    #endif // #if os(macOS) || os(iOS)

}

#if os(macOS) || os(iOS)

var undoCounter = 0

public extension Optical {
    /// Performs the given state-mutating operation in an undoable context
    @available(macOS 10.11, iOS 9.0, *)
    func undoable(_ um: UndoManager, actionName: String? = nil, _ f: @escaping (Self) -> ()) {
        um.beginUndoGrouping()
        defer { um.endUndoGrouping() }
        
        um.registerUndo(withTarget: self, handler: { [prev = self.optic.rawValue] (this) -> Void in
            let cur = this.optic.rawValue // remember the current value for re-doing
            this.undoable(um, actionName: actionName) { this2 in this2.optic.rawValue = cur } // recursively register how to undo the undo
            this.optic.rawValue = prev // when we undo, all we need to do is restore the optic's previos value
        })
        if let actionName = actionName { um.setActionName(actionName) }
        undoCounter += 1
        f(self) // perform the action
    }
}

#endif // #if os(macOS) || os(iOS)


