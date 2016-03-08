//
//  GameDetailsViewController.swift
//  Pickup
//
//  Created by Nathan Dudley on 2/1/16.
//  Copyright © 2016 Pickup. All rights reserved.
//

import UIKit
import Parse
import MapKit

class GameDetailsViewController: UIViewController, MKMapViewDelegate, GameDetailsViewDelegate {

    let SEGUE_SHOW_EDIT_GAME = "ShowEditGame"
    let SEGUE_SHOW_EMBEDDED_DETAILS = "showGameDetailsTableViewController"

    @IBOutlet weak var lblLocationName: UILabel!
    @IBOutlet weak var lblOpenings: UILabel!
    @IBOutlet weak var imgGameType: UIImageView!
    @IBOutlet weak var btnJoinGame: UIBarButtonItem!
    
    
    var myGamesTableViewDelegate: MyGamesTableViewDelegate?
    var embeddedView: GameDetailsTableViewController!
    
    let navBarButtonTitleOptions: [UserStatus: String] = [.USER_NOT_JOINED: "Join Game", .USER_JOINED: "Leave Game", .USER_OWNED: "Edit Game"]
    let bottomBarVisible: [UserStatus: Bool] = [.USER_NOT_JOINED: false, .USER_JOINED: false, .USER_OWNED: true]
    let alertAction: [UserStatus: String] = [.USER_NOT_JOINED: "join", .USER_JOINED: "leave", .USER_OWNED: "cancel"]
    let alertTitle: [UserStatus: String] = [.USER_NOT_JOINED: "Join", .USER_JOINED: "Leave", .USER_OWNED: "Yes"]
    let alertCancelTitle: [UserStatus: String] = [.USER_NOT_JOINED: "Cancel", .USER_JOINED: "Cancel", .USER_OWNED: "No"]
    
    var gameTypes: [GameType]!
    var game: Game!
    
    var userStatus: UserStatus = .USER_NOT_JOINED
    var address: String!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        btnJoinGame.tintColor = Theme.ACCENT_COLOR
        self.navigationController?.navigationBar.tintColor = Theme.PRIMARY_LIGHT_COLOR
        
        if let gameDetailsTableViewController = self.childViewControllers.first as? GameDetailsTableViewController {
        
            if userStatus != .USER_NOT_JOINED {
                gameDetailsTableViewController.btnAddToCalendar.hidden = false
            }
            
            if userStatus == .USER_OWNED {
                gameDetailsTableViewController.isOwner = true
            }
        }
        
        lblLocationName.text = game.locationName
        
        lblOpenings.text = ("\(game.availableSlots) openings")
        
        if userStatus == .USER_OWNED {
            lblOpenings.text = ("\(game.availableSlots) openings (\(game.totalSlots - game.availableSlots - 1) joined)")
        }
        
        btnJoinGame.title = navBarButtonTitleOptions[userStatus]
        imgGameType.image = UIImage(named: game.gameType.imageName)
        
    }
    
    
    @IBAction func btnJoinGame(sender: AnyObject) {
        
        if userStatus == .USER_OWNED {
            performSegueWithIdentifier(SEGUE_SHOW_EDIT_GAME, sender: self)
        } else {
            showAlert()
        }
        
    }
    
    private func showAlert() {
        let message = "Are you sure you want to \(self.alertAction[userStatus]!) this game?"
        let alertTitle = "\(self.alertTitle[userStatus]!)"
        let alertCancelTitle = "\(self.alertCancelTitle[userStatus]!)"
        
        let alertController = UIAlertController(title: title, message:
            message, preferredStyle: UIAlertControllerStyle.Alert)
        
        alertController.addAction(UIAlertAction(title: alertCancelTitle, style: UIAlertActionStyle.Default,handler: nil))
        alertController.addAction(UIAlertAction(title: alertTitle, style: UIAlertActionStyle.Default, handler: { action in
            
            switch(self.userStatus) {
                
            case .USER_NOT_JOINED:
                self.joinGame()
                break
            case .USER_JOINED:
                self.leaveGame()
                break
            case .USER_OWNED:
                self.cancelGameOnParse()
                break
            }
            
        }))
        
        self.presentViewController(alertController, animated: true, completion: nil)
    }
    
    
    private func joinGame() {
        self.joinPFUserToPFGame()
        self.addGameToUserDefaults()
        self.game.availableSlots += -1
        self.game.userJoined = !self.game.userJoined
        self.userStatus = .USER_JOINED
        self.scheduleGameNotification()
    }
    
    private func leaveGame() {
        self.removePFUserFromPFGame()
        self.removeGameFromUserDefaults()
        self.game.userJoined = !self.game.userJoined
        self.game.availableSlots += 1
        self.userStatus = .USER_NOT_JOINED
        self.cancelGameNotification()
        
        if myGamesTableViewDelegate != nil {
            myGamesTableViewDelegate?.removeGame(self.game)
            navigationController?.popViewControllerAnimated(true)
        }
    }
    
    
    //MARK: - Notifications
    //https://www.hackingwithswift.com/example-code/system/how-to-set-local-alerts-using-uilocalnotification
    func scheduleGameNotification() {
        let settings = UIApplication.sharedApplication().currentUserNotificationSettings()
        
        if settings!.types != .None && Settings.sharedSettings.gameReminder != 0 {
            let notification = UILocalNotification()
//            notification.fireDate = self.game.eventDate.dateByAddingTimeInterval(-1 * Double(Settings.sharedSettings.gameReminder) * 60)
            notification.fireDate = NSDate(timeIntervalSinceNow: 10)
            
            let timeUntilGame = getTimeUntilGameFromSettings()
            
            let alertBody = "Your \(self.game.gameType.name) game at \(self.game.locationName) starts in \(timeUntilGame)."
            notification.alertBody = alertBody
            
            notification.soundName = UILocalNotificationDefaultSoundName
            
            notification.userInfo = ["selectedGameId": self.game.id, "alertBody": alertBody]
            UIApplication.sharedApplication().scheduleLocalNotification(notification)
        }
    }
    
    func getTimeUntilGameFromSettings() -> String {
        
        var timeUntilGame: String
        
        switch (Settings.sharedSettings.gameReminder) {
        case 30:
            timeUntilGame = "30 minutes"
            break
        case 60:
            timeUntilGame = "1 hour"
            break
        case 120:
            timeUntilGame = "2 hours"
            break
        case 1440:
            timeUntilGame = "24 hours"
            break
        default:
            timeUntilGame = "just a few minutes"
            break
        }
        
        return timeUntilGame
    }
    
    func cancelGameNotification() {
        for notification in UIApplication.sharedApplication().scheduledLocalNotifications! {// as! [UILocalNotification] {
            if notification.userInfo!["selectedGameId"] as! String == self.game.id {
                UIApplication.sharedApplication().cancelLocalNotification(notification)
            }
        }
    }
    
    
    //MARK: - Parse
    private func joinPFUserToPFGame() {
        let gameQuery = PFQuery(className: "Game")
        gameQuery.whereKey("objectId", equalTo: self.game.id)
        
        gameQuery.getFirstObjectInBackgroundWithBlock {
            (object: PFObject?, error: NSError?) -> Void in
            if error != nil || object == nil {
                print("The getFirstObject on Game request failed.")
            } else {
                let currentUser = PFUser.currentUser()
                let gameRelations = object?.relationForKey("players")
                gameRelations?.addObject(currentUser!)
                
                //Decrement slots available
                var slotsAvailable = object?["slotsAvailable"] as! Int
                slotsAvailable += -1
                object?["slotsAvailable"] = slotsAvailable
                
                object?.saveInBackground()
                self.navigationController?.popViewControllerAnimated(true)
            }
        }
    }
    
    
    private func removePFUserFromPFGame() {
        let gameQuery = PFQuery(className: "Game")
        gameQuery.whereKey("objectId", equalTo: self.game.id)
        
        gameQuery.getFirstObjectInBackgroundWithBlock {
            (object: PFObject?, error: NSError?) -> Void in
            if error != nil || object == nil {
                print("The getFirstObject on Game request failed.")
            } else {
                let currentUser = PFUser.currentUser()
                let gameRelations = object?.relationForKey("players")
                gameRelations?.removeObject(currentUser!)
                object?.saveInBackground()
                
                //Increment slots available
                var slotsAvailable = object?["slotsAvailable"] as! Int
                slotsAvailable += 1
                object?["slotsAvailable"] = slotsAvailable
                self.navigationController?.popViewControllerAnimated(true)
            }
        }
        
    }
    
    private func cancelGameOnParse() {
        let gameQuery = PFQuery(className: "Game")
        gameQuery.whereKey("objectId", equalTo: self.game.id)
        
        gameQuery.getFirstObjectInBackgroundWithBlock {
            (object: PFObject?, error: NSError?) -> Void in
            if error != nil || object == nil {
                print("The getFirstObject on Game request failed.")
            } else {
                object?["isCancelled"] = true
                object?.saveInBackground()
                
                self.cancelGameNotification()
                self.removeGameFromUserDefaults()
                self.navigationController?.popViewControllerAnimated(true)
            }
        }
    }

    
    //MARK: - User Defaults
    
    private func addGameToUserDefaults() {
        
        if let joinedGames = NSUserDefaults.standardUserDefaults().objectForKey("userJoinedGamesById") as? NSArray {
            let gameIdArray = joinedGames.mutableCopy()
            gameIdArray.addObject(game.id)
            NSUserDefaults.standardUserDefaults().setObject(gameIdArray, forKey: "userJoinedGamesById")
        } else {
            var gameIdArray: [String] = []
            gameIdArray.append(game.id)
            NSUserDefaults.standardUserDefaults().setObject(gameIdArray, forKey: "userJoinedGamesById")
        }
        
    }
    
    private func removeGameFromUserDefaults() {
        
        if let joinedGames = NSUserDefaults.standardUserDefaults().objectForKey("userJoinedGamesById") as? NSArray {
            let gameIdArray = joinedGames.mutableCopy()
            gameIdArray.removeObject(game.id)
            NSUserDefaults.standardUserDefaults().setObject(gameIdArray, forKey: "userJoinedGamesById")
        }
        
    }
    
    //MARK: - Game Details View Delegate
    
    func setGameAddress(address: String) {
        self.address = address
        self.embeddedView.lblAddress.text = self.address
    }
    
    func setGame(game: Game) {
        self.game = game
        lblLocationName.text = game.locationName
        //TODO: Fix this to only be able to only decrease
        lblOpenings.text = ("\(game.totalSlots) openings")
        self.embeddedView.lblDay.text = DateUtilities.dateString(self.game.eventDate, dateFormatString: DateFormatter.MONTH_DAY_YEAR.rawValue)
        self.embeddedView.lblTime.text = DateUtilities.dateString(self.game.eventDate, dateFormatString: DateFormatter.TWELVE_HOUR_TIME.rawValue)
        self.embeddedView.lblGameNotes.text = game.gameNotes
        self.embeddedView.game = self.game
        self.embeddedView.tableView.reloadData()
    }
    
    func cancelGame(game: Game) {
        showAlert()
    }
    

    
    //MARK: - Navigation
    
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        
        if segue.identifier == SEGUE_SHOW_EMBEDDED_DETAILS {
            let embeddedViewController = segue.destinationViewController as? GameDetailsTableViewController
            self.embeddedView = embeddedViewController
            embeddedViewController?.game = self.game
            embeddedViewController?.parentDelegate = self
        } else if segue.identifier == SEGUE_SHOW_EDIT_GAME {
            let navigationController = segue.destinationViewController as! UINavigationController
            let newGameTableViewController = navigationController.viewControllers.first as! NewGameTableViewController
            
            newGameTableViewController.gameStatus = .EDIT
            newGameTableViewController.gameDetailsDelegate = self
            newGameTableViewController.gameTypes = self.gameTypes
            newGameTableViewController.game = self.game
            newGameTableViewController.address = self.address
        }
    }
    

    
}
