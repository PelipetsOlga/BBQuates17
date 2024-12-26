//
//  Episod.swift
//  BBQuates17
//
//  Created by Olha Pelypets on 26/12/2024.
//

import Foundation

struct Episode: Decodable {
    let episode: Int  // 101
    let title: String
    let image: URL
    let synopsis: String
    let writtenBy: String
    let directedBy: String
    let airDate: String

    var seasonEpisod: String { // "Season 1 Episode 1"
        var episodeString = String(episode)  // "101"
        let season = episodeString.removeFirst()  //episodeString:"01", season:"1"

        if episodeString.first! == "0" {
            episodeString = String(episodeString.removeLast())
        }

        return "Season \(season) Episode \(episodeString)"
    }
}
