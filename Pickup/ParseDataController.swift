//
//  ParseDataController.swift
//  Pickup
//
//  Created by Nathan Dudley on 2/9/16.
//  Copyright © 2016 Pickup. All rights reserved.
//

import Foundation
import Parse

class ParseDataController {
    
    var gameTypes:[GameType] = []
    var games:[Game] = []
    
    var gameTypesLoaded:Bool = false
    
    var gamesLoaded:Bool = false {
        didSet {
            
        }
    }
    
    var gameDetailsLoaded:Bool = false {
        didSet {
            
        }
    }
    
    
    init() {}
    
    func getGameTypes() -> [GameType] {
        return gameTypes
    }
    
    
    //TODO: Build out data class
    
    //Perhaps this class can control retrieval of all data from Parse
    
    private func loadGameTypesFromParse() {
        var gameTypes:[GameType] = []
        let gameTypeQuery = PFQuery(className: "GameType")
        
        gameTypeQuery.findObjectsInBackgroundWithBlock { (objects, error) -> Void in
            
            if let gameTypeObjects = objects {
                
                gameTypes.removeAll(keepCapacity: true)
                
                for gameTypeObject in gameTypeObjects {
                    let gameType = GameTypeConverter.convertParseObject(gameTypeObject)
                    gameTypes.append(gameType)
                }
            }
            
            self.gameTypesLoaded = true
        }
    }
    
    

    
    
    
}