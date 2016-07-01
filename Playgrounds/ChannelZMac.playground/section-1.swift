import Foundation
import ChannelZ

struct Song {
    var title: String
}

struct Company {
    var name: String
}

struct Artist {
    var name: String
    var label: Company?
    var songs: [Song]
}

struct Album {
    var title: String
    var year: Int
    var producer: Company?
    var tracks: [Song]
}

struct Library {
    var artists: [Artist] = []
    var albums: [Album] = []
}

extension Library {
    var songs: [Song] { return artists.flatMap({ $0.songs }) + albums.flatMap({ $0.tracks }) }
}

var library: Library = Library()

library.albums.append(Album(title: "Magenta Snow", year: 1983, producer: nil, tracks: [
    Song(title: "Let's Get Silly"),
    Song(title: "Take Me with You"),
    Song(title: "I Would Die For You")
    ]))

// Make it funky now
library.albums[0].title = "Purple Rain"
//library.albums[0].tracks[0].title = "Let's Go Crazy"
//library.albums[0].tracks[1].title = "Take Me with U"
//library.albums[0].tracks[2].title = "I Would Die 4 U"

library.albums[0].year = 1984
library.albums[0].producer = Company(name: "Warner Brothers") // not so funky

library.artists.append(Artist(name: "Prince", label: nil, songs: [Song(title: "Red Hat")]))

library.artists[0].songs[0].title = "Raspberry Beret"

func funkify(title: String) -> String {
    return title
        .stringByReplacingOccurrencesOfString("Get Silly", withString: "Go Crazy")
        .stringByReplacingOccurrencesOfString("For", withString: "4")
        .stringByReplacingOccurrencesOfString("You", withString: "U")
}

for i in 0..<library.albums[0].tracks.count {
    library.albums[0].tracks[i].title = funkify(library.albums[0].tracks[i].title)
}

//dump(library)

let titles = Set(library.songs.map({ $0.title }))

// Verify funkiness
let funky = titles == ["Let's Go Crazy", "Take Me with U", "I Would Die 4 U", "Raspberry Beret"]



// Make it funcy now ¯\_(ツ)_/¯

protocol Focusable {

}

extension Focusable {
    static func lens<B>(lens: Lens<Self, B>) -> Lens<Self, B> {
        return lens
    }

    static func lensZ<X, Source : StateEmitterType where Source.Element == Self>(lens: Lens<Self, X>) -> Channel<Source, Mutation<Source.Element>> -> Channel<LensSource<Channel<Source, Mutation<Source.Element>>, X>, Mutation<X>> {
        return { channel in focus(channel)(lens) }
    }

    static func focus<X, Source : StateEmitterType where Source.Element == Self>(channel: Channel<Source, Mutation<Source.Element>>) -> (Lens<Source.Element, X>) -> Channel<LensSource<Channel<Source, Mutation<Source.Element>>, X>, Mutation<X>> {
        return channel.focus
    }
}

extension Artist : Focusable {
    static let nameλ = Artist.lens(Lens({ $0.name }, { $0.name = $1 }))
    static let labelλ = Artist.lens(Lens({ $0.label }, { $0.label = $1 }))
    static let songsλ = Artist.lens(Lens({ $0.songs }, { $0.songs = $1 }))
}

extension Company : Focusable {
    static let nameλ = Company.lens(Lens({ $0.name }, { $0.name = $1 }))
}

//public extension ChannelType where Element : MutationType {

public extension ChannelType where Source : StateEmitterType, Element == Mutation<Source.Element> {
}

//extension ChannelType where Element : MutationType, Element.T : Focusable {
//    func focus<B>(lens: Lens<Element.T, B>) {
//        focus
//    }
//}

let artist = transceive(library.artists[0])
artist.focus(Artist.nameλ).value = "Foo"
//artist.focus(Artist.labelλ).focus(<#T##lens: Lens<Company?, X>##Lens<Company?, X>#>)

//struct ArtistLens<B> {
//    let lens: Lens<Artist, B>
//    // error: static stored properties not yet supported in generic types
//    static let name = ArtistLens(lens: Lens({ $0.name }, { $0.name = $1 }))
//}

1





//struct ArtistLenses<T> {
//    static let name = Lens<Artist, String>({ $0.name }, { $0.name = $1 })
//}

//protocol Focusable {
//    associatedtype Prism : PrismType
//}
//
//protocol PrismType {
//    associatedtype Focus
//}
//
//extension Focusable {
//    static func lensZ<X, Source : StateEmitterType where Source.Element == Self>(lens: Lens<Self, X>) -> Channel<Source, Mutation<Source.Element>> -> Channel<LensSource<Channel<Source, Mutation<Source.Element>>, X>, Mutation<X>> {
//        return { channel in focus(channel)(lens) }
//    }
//
//    static func focus<X, Source : StateEmitterType where Source.Element == Self>(channel: Channel<Source, Mutation<Source.Element>>) -> (Lens<Source.Element, X>) -> Channel<LensSource<Channel<Source, Mutation<Source.Element>>, X>, Mutation<X>> {
//        return channel.focus
//    }
//}
//
////public extension ChannelType where Source : StateEmitterType, Element == Mutation<Source.Element> {
//
//extension PrismType {
//    static func lensZ<X, Source : StateEmitterType where Source.Element == Focus>(lens: Lens<Focus, X>) -> Channel<Source, Mutation<Source.Element>> -> Channel<LensSource<Channel<Source, Mutation<Source.Element>>, X>, Mutation<X>> {
//        return { channel in channel.focus(lens) }
//    }
//}
//
//extension Song : Focusable {
//    var prop: () -> Channel<ValueTransceiver<Song>, Mutation<Song>> { return { transceive(self) } }
//
//    struct Prism : PrismType {
//        typealias Focus = Song
////        static let title = Prism.lensZ(Lens({ $0.title }, { $0.title = $1 }))
//    }
//}
//
//protocol Prasm {
//    associatedtype Focus
////    var channel: Channel<T, Mutation<T>> { get }
//}
//
//class BasePrasm<T, B> : Prasm {
//    typealias Focus = T
//    let lens: Lens<T, B>
//
//    init(lens: Lens<T, B>) {
//        self.lens = lens
//    }
//}
//
//extension Artist : Focusable {
//    static let nameZ = Lens<Artist, String>({ $0.name }, { $0.name = $1 })
//    static let songsZ = Lens<Artist, [Song]>({ $0.songs }, { $0.songs = $1 })
//
//    static func focal(prism: Prosm) {
//
//    }
//
////    static let nameZ = Artist.lensZ(Lens({ $0.name }, { $0.name = $1 }))(transceive(Artist(name: "", songs: [])))
//
//    struct Prism : PrismType {
//        typealias Focus = Artist
//
//        static let name = Prism(lens: Lens({ $0.name }, { $0.name = $1 }))
////        static let songs = Prism(lens: Lens({ $0.songs }, { $0.songs = $1 }))
//
//        let lens: Lens<Artist, String>
//        init(lens: Lens<Artist, String>) {
//            self.lens = lens
//        }
//    }
//
//    class Prosm<B> : BasePrasm<Artist, B> {
////        let nameZ = Prosm.lensZ(Lens({ $0.name }, { $0.name = $1 }))
//        static let name = Prosm(lens: Lens({ $0.name }, { $0.name = $1 }))
//
//        override init(lens: Lens<Artist, String>) {
//            super.init(lens: lens)
//        }
//
//    }
//}
//
//
//extension Album : Focusable {
//    struct Prism : PrismType {
//        typealias Focus = Album
////        static let title = Prism.lensZ(Lens({ $0.title }, { $0.title = $1 }))
////        static let year = Prism.lensZ(Lens({ $0.year }, { $0.year = $1 }))
////        static let label = Prism.lensZ(Lens({ $0.label }, { $0.label = $1 }))
////        static let tracks = Prism.lensZ(Lens({ $0.tracks }, { $0.tracks = $1 }))
//    }
//}
//
//// Prism=Λ, Lens=λ
//var prince = library.artists[0]
//
//let artistZ = transceive(prince)
//artistZ.value.name
//
//
//Artist.focal(.name)
//
//1
//
//
//let name = Artist.focus(artistZ)(Artist.Prism.name)
//let name = Artist.Prism.name(artistZ)
//
//let name = Artist.Prism.lensZ(Lens({ $0.title }, { $0.title = $1 }))(artistZ)
//name.value = "The Artist Formerly Known As Prince"
//artistZ.value.name


//let princeΛ = prince.focus()
//
//princeΛ.nameλ.get(prince)

//princeΛ.nameλ.value = "The Artist Formerly Known as Prince"
//princeΛ.nameλ.value

//princeName.value
//princeName ∞= "The Artist Formerly Known as Prince"
//princeName.value

//prism.title.get(song)
//
//song = prism.title.set(song, "Blueberry Tophat")
//
//prism.title.get(song)
//song.title


//let prop = transceive((int: 1, dbl: 2.2, str: "Foo", sub: (a: true, b: 22, c: "")))


