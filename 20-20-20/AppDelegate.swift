//
//  AppDelegate.swift
//  20-20-20
//
//  Created by Tony Hu on 6/16/20.
//  Copyright © 2020 Tony Hu. All rights reserved.
//
//  Forked by Chris Przytocki on 1/27/22
//

import Cocoa
import SwiftUI
import UserNotifications
import EventKit

@available(macOS 10.15.0, *)
@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSUserNotificationCenterDelegate {

    var window: NSWindow!
    var statusBarItem: NSStatusItem!
    var timer: Timer!
    var notifyStatus: Int!
    var soundStatus: Int!
    var overlayStatus: Int!
    var meetingBypassStatus: Int!
    let twentySecs = 20.0
    let twentyMins = 1200.0
    let appVersion: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
    var skipped = false
    let store = EKEventStore()
    
    func delayWithSeconds(_ seconds: Double, completion: @escaping () -> ()) {
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
            completion()
        }
    }
    
    func setSkipped(bool: Bool) {
        skipped = bool
    }
 
    func showWindow() {
        let screenSize: NSRect = NSScreen.main!.frame
        var windowRef:NSWindow
        windowRef = NSWindow(
            contentRect: screenSize,
            styleMask: [.fullSizeContentView],
            backing: .buffered, defer: false)
            windowRef.contentView = NSHostingView(rootView: ContentView(myWindow: windowRef, setSkipped: setSkipped))
        windowRef.alphaValue = 0.7
        windowRef.makeKeyAndOrderFront(nil)
        windowRef.orderFrontRegardless()
        
        delayWithSeconds(twentySecs) {
            windowRef.close()
        }
    }
    @available(macOS 10.15.0, *)
    func checkInMeeting() -> Bool {
        var inMeeting = false
        let calendars = store.calendars(for: .event)
        
        // Create the predicate from the event store's instance method.
        let predicate: NSPredicate = store.predicateForEvents(withStart: Date(), end: Date(), calendars: calendars)

        // Fetch all events that match the predicate.
        let events: [EKEvent] = store.events(matching: predicate)
        
        inMeeting = events.count > 0
        return inMeeting
    }
    
    func requestCalendarAccess () {
        store.requestAccess(to: .event) { (granted, error) in
            if let error = error {
               print(error)
               return
            }
            if granted {
               print("calendar access granted")
            }
        }
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        
        // Handle notifications depending on sleep status
        let notificationCenter = NSWorkspace.shared.notificationCenter
        notificationCenter.addObserver(self, selector: #selector(stopTimer), name: NSWorkspace.willSleepNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(checkNotifyStatus), name: NSWorkspace.didWakeNotification, object: nil)
        
        NSApp.setActivationPolicy(.accessory)
        
        notifyStatus = UserDefaults.standard.integer(forKey: "notifyStatus")  // uninitialized = 0, ON = 1, OFF = -1
        soundStatus = UserDefaults.standard.integer(forKey: "soundStatus")  // uninitialized = 0, ON = 1, OFF = -1
        overlayStatus = UserDefaults.standard.integer(forKey: "overlayStatus")  // uninitialized = 0, ON = 1, OFF = -1
        meetingBypassStatus = UserDefaults.standard.integer(forKey: "meetingBypassStatus")  // uninitialized = 0, ON = 1, OFF = -1

        
        // Ask first time user for notification permissions
        if (notifyStatus == 0) {
            sendNotification()
            notifyStatus = 1
            UserDefaults.standard.set(notifyStatus, forKey: "notifyStatus")
        }
        
        if (soundStatus == 0) {
            soundStatus = 1
            UserDefaults.standard.set(soundStatus, forKey: "soundStatus")
        }
        
        if (overlayStatus == 0) {
            overlayStatus = 1
            UserDefaults.standard.set(overlayStatus, forKey: "overlayStatus")
        }
        
        if (meetingBypassStatus == 0) {
            meetingBypassStatus = 1
            UserDefaults.standard.set(meetingBypassStatus, forKey: "meetingBypassStatus")
        }
        
        
        if (meetingBypassStatus == 1) {
            requestCalendarAccess()
        }
        
        initializeStatusBar()
        checkNotifyStatus()
    }
    
    @objc func checkNotifyStatus() {
        if (notifyStatus == 1) {
            startTimer()
        }
    }
    
    func initializeStatusBar() {
        let statusBar = NSStatusBar.system
        statusBarItem = statusBar.statusItem(withLength: NSStatusItem.squareLength)
        statusBarItem.button?.title = "👁"
        let statusBarMenu = NSMenu(title: "20-20-20 Menu")
        statusBarItem.menu = statusBarMenu
        
        statusBarMenu.addItem(
            withTitle: ((notifyStatus == 1) ? "Notifications ON" : "Notifications OFF"),
            action: nil,
            keyEquivalent: "")
        
        statusBarMenu.addItem(
            withTitle: ((notifyStatus == 1) ? "Turn OFF Notifications" : "Turn ON Notifications"),
            action: #selector(AppDelegate.updateNotifications),
            keyEquivalent: "")
        
        statusBarMenu.addItem(NSMenuItem.separator())
        
        statusBarMenu.addItem(
            withTitle: "Toggles",
            action: nil,
            keyEquivalent: "")
        
        statusBarMenu.addItem(
            withTitle: ((soundStatus == 1) ? "Disable Sounds" : "Enable Sounds"),
            action: #selector(AppDelegate.updateSounds),
            keyEquivalent: "")
        
        statusBarMenu.addItem(
            withTitle: ((overlayStatus == 1) ? "Disable Screen" : "Enable Screen"),
            action: #selector(AppDelegate.updateOverlay),
            keyEquivalent: "")
        
        statusBarMenu.addItem(
            withTitle: ((meetingBypassStatus == 1) ? "Disable Meeting Bypass" : "Enable Meeting Bypass"),
            action: #selector(AppDelegate.updateMeetingBypass),
            keyEquivalent: "")
        
        statusBarMenu.addItem(NSMenuItem.separator())
        
        statusBarMenu.addItem(
            withTitle: "Debug",
            action: nil,
            keyEquivalent: "")
        
        statusBarMenu.addItem(
            withTitle: "Test Notification",
            action: #selector(AppDelegate._sendNotification),
            keyEquivalent: "")
        
        statusBarMenu.addItem(NSMenuItem.separator())
        
        statusBarMenu.addItem(
            withTitle: "Version: " + appVersion,
            action: nil,
            keyEquivalent: "")
        
        statusBarMenu.addItem(
            withTitle: "Check for Updates",
            action: #selector(AppDelegate.openReleases),
            keyEquivalent: "")
        
//        statusBarMenu.addItem(
//            withTitle: "Give Feedback",
//            action: #selector(AppDelegate.openFeedback),
//            keyEquivalent: "")
        
        statusBarMenu.addItem(NSMenuItem.separator())
        
        statusBarMenu.addItem(
            withTitle: "Quit",
            action: #selector(AppDelegate.exitApp),
            keyEquivalent: "")
    }
    
    @objc func updateNotifications() {
        if (notifyStatus == 1) {
            stopTimer()
            notifyStatus = -1
            updateStatusBar()
            UserDefaults.standard.set(notifyStatus, forKey: "notifyStatus")
        }
        else {
            startTimer()
            notifyStatus = 1
            updateStatusBar()
            UserDefaults.standard.set(notifyStatus, forKey: "notifyStatus")
        }
    }
    
    func updateStatusBar() {
        let statusItem = statusBarItem.menu?.item(at: 0)
        statusItem?.title = ((notifyStatus == 1) ? "Notifications ON" : "Notifications OFF")
        let notifyOptionItem = statusBarItem.menu?.item(at: 1)
        notifyOptionItem?.title = ((notifyStatus == 1) ? "Turn OFF Notifications" : "Turn ON Notifications")
        let soundOptionItem = statusBarItem.menu?.item(at: 2)
        soundOptionItem?.title = ((soundStatus == 1) ? "Disable Sounds" : "Enable Sounds")
        let screenOptionItem = statusBarItem.menu?.item(at: 3)
        screenOptionItem?.title = ((overlayStatus == 1) ? "Disable Screen" : "Enable Screen")
        let meetingBypassOptionItem = statusBarItem.menu?.item(at: 4)
        meetingBypassOptionItem?.title = ((meetingBypassStatus == 1) ? "Disable Meeting Bypass" : "Enable Meeting Bypass")
    }
    
    @objc func updateSounds() {
        soundStatus = (soundStatus == 1) ? -1 : 1
        updateStatusBar()
        UserDefaults.standard.set(soundStatus, forKey: "soundStatus")
    }
    
    @objc func updateOverlay() {
        overlayStatus = (overlayStatus == 1) ? -1 : 1
        updateStatusBar()
        UserDefaults.standard.set(overlayStatus, forKey: "overlayStatus")
    }
    
    @objc func updateMeetingBypass() {
        meetingBypassStatus = (meetingBypassStatus == 1) ? -1 : 1
        updateStatusBar()
        UserDefaults.standard.set(meetingBypassStatus, forKey: "meetingBypassStatus")
    }
    
    
    @objc func openReleases() {
        let url = URL(string: "https://github.com/cprzytocki/20-20-20/releases")!
        if (NSWorkspace.shared.open(url)) {
            print("Successfully opened github releases!")
        }
    }
    
    @objc func openFeedback() {
        let url = URL(string: "https://docs.google.com/forms/d/e/1FAIpQLSfXnoCmppLdI-kttHYPE6bO4JoXW7nF6ZG2xTw6wPwddlHFCA/viewform")!
        if (NSWorkspace.shared.open(url)) {
            print("Successfully opened feedback form!")
        }
    }
    
    @objc func exitApp() {
        stopTimer()
        NSApplication.shared.terminate(self)
    }
    
    @objc func startTimer() {
        // Wait for twenty minute intervals
        timer = Timer.scheduledTimer(withTimeInterval: twentyMins, repeats: true) { t in
            if (self.notifyStatus == 1) {
                self.sendNotification()
            }
        }
    }
    
    @objc func stopTimer() {
        if (timer != nil) {
            timer.invalidate()
        }
    }
    
    @objc func _sendNotification() {
        sendNotification()
    }
    
    func sendNotification() {
        if (meetingBypassStatus == 1 && checkInMeeting()) {
            return
        }
        
        let notification = NSUserNotification()
        notification.identifier = "notify20"
        notification.title = "20-20-20 (Expires in 20 secs)"
        notification.subtitle = "Look at something 20 feet away"
        notification.informativeText = "for 20 seconds."
        notification.soundName = (soundStatus == 1) ? NSUserNotificationDefaultSoundName : nil
        notification.hasActionButton = false
        
        let notificationCenter = NSUserNotificationCenter.default
        notificationCenter.deliver(notification)
        
        // Display notification for twenty seconds
        notificationCenter.perform(#selector(NSUserNotificationCenter.removeDeliveredNotification(_:)),
                                   with: notification,
                                   afterDelay: (twentySecs))
                                        
//        if (soundStatus == 1) {
//            perform(#selector(playSound), with: nil, afterDelay: twentySecs)
//        }
        
        if (overlayStatus == 1) {
            showWindow()
        }
        
        delayWithSeconds(twentySecs) {
            if (self.skipped) {
                self.skipped = false
                return
            }
                
            if (self.soundStatus == 1) {
                self.playSound()
            }
        }
    }
    
    @objc func playSound() {
        NSSound(named: "pieceOfCake")?.play()
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
        exitApp()
    }

}
