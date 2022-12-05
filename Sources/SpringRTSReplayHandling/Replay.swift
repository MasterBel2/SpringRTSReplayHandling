//
//  Replay.swift
//  SpringRTSReplayHandling
//
//  Created by MasterBel2 on 16/5/20.
//  Copyright © 2020 MasterBel2. All rights reserved.
//

import Foundation
import SpringRTSStartScriptHandling

enum ReplayError: Error {
    case incorrectHeaderSize
    case unrecognisedVersion
    case missingMagicNumber
}

public struct Replay {

    public let header: Header
    public let fileURL: URL
    public let gameSpecification: GameSpecification

    public init(data: Data, fileURL: URL) throws {
        let dataParser = DataParser(data: data)
        // First check magic number
        let magicNumber = "spring demofile".cString(using: .utf8)!
        guard try dataParser.checkValue(expect: magicNumber) else {
            print("[Replay] Initialisation failed: could not find magic number.")
            throw ReplayError.missingMagicNumber
        }

        // Different versions must be parsed differently.
        let version = try dataParser.parseData(ofType: Int32.self)
        let rawHeader: RawReplayHeaderProtocol
        switch version {
        case 5:
            rawHeader = try RawReplayHeader.Version5(dataParser: dataParser, magicNumber: magicNumber)
        case 4:
            rawHeader = try RawReplayHeader.Version4(dataParser: dataParser, magicNumber: magicNumber)
        default:
            print("[Replay] Unrecognised replay version \"\(version)\".")
            throw ReplayError.unrecognisedVersion
        }
        // Confirm header parsing was successful

        let script = try dataParser.parseData(ofType: CChar.self, count: Int(rawHeader.scriptSize))
        gameSpecification = try GameSpecificationDecoder().decode(String(cString: script + [0]))

        self.fileURL = fileURL
        // Store the useful header data.
        self.header = Header(
            version: Int(version),
            springVersion: String(cString: rawHeader.springVersion),
            gameID: rawHeader.gameID.reduce("", { $0 + String($1) }),
            gameStartDate: Date(timeIntervalSince1970: TimeInterval(rawHeader.unixTime)),
            duration: Int(rawHeader.gameTime)
        )

        //        let testScript = specification1.launchScript(shouldRecordDemo: false)
        //        print(testScript)
        //        let specification2 = try GameSpecificationDecoder().decode(testScript)
        //        print(specification1 == specification2)

        //        let demoStream = try dataParser.parseData(ofType: CChar.self, count: Int(rawHeader.demoStreamSize))
        //        let demoStream = try dataParser.parseData(ofType: CChar.self, count: Int(rawHeader.demoStreamSize))
    }

    public struct Header {
        /// The format of the file the replay was loaded from.
        public let version: Int
        /// The Spring version which generated the replay.
        public let springVersion: String
        /// A string which uniquely identifies the game.
        public let gameID: String
        /// The time at which the game started.
        public let gameStartDate: Date
        /// An elapsed time figure (in seconds) measured independently of simulation speed (i.e. 1 game frame corresponds to 1/30 second
        /// regardless of the initial game frames/second the game was played at).
        public let duration: Int
    }
}

protocol RawReplayHeaderProtocol {
    var magicNumber: [CChar] { get }
    var version: Int32 { get }
    var headerSize: Int32 { get }
    var springVersion: [CChar] { get }
    var gameID: [UInt8] { get }
    var unixTime: Int64 { get }
    var scriptSize: Int32 { get }
    var demoStreamSize: Int32 { get }
    var gameTime: Int32 { get }
    var wallclockTime: Int32 { get }
    var numPlayers: Int32 { get }
    var playerStatSize: Int32 { get }
    var playerStatElementSize: Int32 { get }
    var teamStatisticsCount: Int32 { get }
    var teamStatSize: Int32 { get }
    var teamStatElementSize: Int32 { get }
    var teamStatPeriod: Int32 { get }
    var winningAllyTeamSize: Int32 { get }
}

enum RawReplayHeader {
    /// Describes a replay file format with a spring version of 256 characters.
    struct Version5: RawReplayHeaderProtocol {
        let magicNumber: [CChar]
        /// The file format version of the replay.
        let version: Int32 = 5
        /// The size of the replay header, in bytes.
        ///
        /// Accorrding to SpringLobby, this begins at byte 20.
        let headerSize: Int32
        /// An array of characters describing the spring version of the replay, with up to 256 8-bit characters (16 if version 5 or lower).
        let springVersion: [CChar]
        /// A unique identifier for the game.
        let gameID: [UInt8]
        /// The unix time when the game started.
        let unixTime: Int64

        /// The size (in bytes) of the startScript.
        let scriptSize: Int32
        /// The size (in bytes) of the demo stream.
        let demoStreamSize: Int32
        /// Total number of seconds game time.
        let gameTime: Int32
        /// Total number of seconds wallclock time.
        let wallclockTime: Int32

        /// The number of players (including spectators, and spectators joined after game start).
        let numPlayers: Int32
        /// The size of the entire player statistics chunk
        let playerStatSize: Int32
        /// The size of the C++ struct containing the statistics about a single player.
        let playerStatElementSize: Int32
        /// The number of teams (not allyteams!) for which stats are saved.
        let teamStatisticsCount: Int32
        /// The size of the entire team statistics chunk.
        let teamStatSize: Int32
        /// The size of the C++ struct containing the statistics about a single team.
        let teamStatElementSize: Int32
        /// The interval (in seconds) between team stats. (???)
        let teamStatPeriod: Int32
        /// The size of the vector of the winning allyteams
        let winningAllyTeamSize: Int32

        init(dataParser: DataParser, magicNumber: [CChar]) throws {
            self.magicNumber = magicNumber
            self.headerSize = try dataParser.parseData(ofType: Int32.self)
            self.springVersion = try dataParser.parseData(ofType: CChar.self, count: 256)
            self.gameID = try dataParser.parseData(ofType: UInt8.self, count: 16)
            self.unixTime = try dataParser.parseData(ofType: Int64.self)
            self.scriptSize = try dataParser.parseData(ofType: Int32.self)
            self.demoStreamSize = try dataParser.parseData(ofType: Int32.self)
            self.gameTime = try dataParser.parseData(ofType: Int32.self)
            self.wallclockTime = try dataParser.parseData(ofType: Int32.self)
            self.numPlayers = try dataParser.parseData(ofType: Int32.self)
            self.playerStatSize = try dataParser.parseData(ofType: Int32.self)
            self.playerStatElementSize = try dataParser.parseData(ofType: Int32.self)
            self.teamStatisticsCount = try dataParser.parseData(ofType: Int32.self)
            self.teamStatSize = try dataParser.parseData(ofType: Int32.self)
            self.teamStatElementSize = try dataParser.parseData(ofType: Int32.self)
            self.teamStatPeriod = try dataParser.parseData(ofType: Int32.self)
            self.winningAllyTeamSize = try dataParser.parseData(ofType: Int32.self)

            guard dataParser.currentIndex == Int(headerSize) else {
                print("[Replay (Header Version 6)] Initialisation failed: expected header size \(headerSize), read \(dataParser.currentIndex) bytes instead.")
                throw ReplayError.incorrectHeaderSize
            }
        }
    }

    /// Describes a replay file format with a spring version of only 16 characters.
    struct Version4: RawReplayHeaderProtocol {
        let magicNumber: [CChar]
        /// The file format version of the replay.
        let version: Int32 = 4
        /// The size of the replay header, in bytes.
        ///
        /// Accorrding to SpringLobby, this begins at byte 20.
        let headerSize: Int32
        /// An array of characters describing the spring version of the replay, with up to 16 characters.
        let springVersion: [CChar]
        /// A unique identifier for the game.
        let gameID: [UInt8]
        /// The unix time when the game started.
        let unixTime: Int64

        /// The size (in bytes) of the startScript.
        let scriptSize: Int32
        /// The size (in bytes) of the demo stream.
        let demoStreamSize: Int32
        /// Total number of seconds game time.
        let gameTime: Int32
        /// Total number of seconds wallclock time.
        let wallclockTime: Int32

        /// The number of players (including spectators, and spectators joined after game start).
        let numPlayers: Int32
        /// The size of the entire player statistics chunk
        let playerStatSize: Int32
        /// The size of the C++ struct containing the statistics about a single player.
        let playerStatElementSize: Int32
        /// The number of teams (not allyteams!) for which stats are saved.
        let teamStatisticsCount: Int32
        /// The size of the entire team statistics chunk.
        let teamStatSize: Int32
        /// The size of the C++ struct containing the statistics about a single team.
        let teamStatElementSize: Int32
        /// The interval (in seconds) between team stats. (???)
        let teamStatPeriod: Int32
        /// The size of the vector of the winning allyteams
        let winningAllyTeamSize: Int32

        init(dataParser: DataParser, magicNumber: [CChar]) throws {
            self.magicNumber = magicNumber
            self.headerSize = try dataParser.parseData(ofType: Int32.self)
            self.springVersion = try dataParser.parseData(ofType: CChar.self, count: 16)
            self.gameID = try dataParser.parseData(ofType: UInt8.self, count: 16)
            self.unixTime = try dataParser.parseData(ofType: Int64.self)
            self.scriptSize = try dataParser.parseData(ofType: Int32.self)
            self.demoStreamSize = try dataParser.parseData(ofType: Int32.self)
            self.gameTime = try dataParser.parseData(ofType: Int32.self)
            self.wallclockTime = try dataParser.parseData(ofType: Int32.self)
            self.numPlayers = try dataParser.parseData(ofType: Int32.self)
            self.playerStatSize = try dataParser.parseData(ofType: Int32.self)
            self.playerStatElementSize = try dataParser.parseData(ofType: Int32.self)
            self.teamStatisticsCount = try dataParser.parseData(ofType: Int32.self)
            self.teamStatSize = try dataParser.parseData(ofType: Int32.self)
            self.teamStatElementSize = try dataParser.parseData(ofType: Int32.self)
            self.teamStatPeriod = try dataParser.parseData(ofType: Int32.self)
            self.winningAllyTeamSize = try dataParser.parseData(ofType: Int32.self)

            guard dataParser.currentIndex == Int(headerSize) else {
                print("[Replay (Header Version 5)] Initialisation failed: expected header size \(headerSize), read \(dataParser.currentIndex) bits instead.")
                throw ReplayError.incorrectHeaderSize
            }
        }
    }
}
