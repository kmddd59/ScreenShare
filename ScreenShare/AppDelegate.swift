//
//  AppDelegate.swift
//  Screenshare
//

import Cocoa

import AVFoundation
import AVKit

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    
    @IBOutlet var window: NSWindow!
    
    @IBOutlet weak var progressIndicator: NSProgressIndicator!
    
    var session : AVCaptureSession = AVCaptureSession()

    let notifications = NotificationManager()
    var devices : [AVCaptureDevice] = []
    var deviceSessions : [AVCaptureDevice: Skin] = [:]
    
    var deviceSettings : [Device] = []
    var deviceSettingsLoaded = false
    
    var selectedDevice : Skin?

    func applicationDidFinishLaunching(aNotification: NSNotification) {

        self.selectedDevice = nil
        
        self.progressIndicator.startAnimation(self)
        
        // Opt-in for getting visibility on connected screen capture devices
        DeviceUtils.registerForScreenCaptureDevices()
        
        self.loadObservers()
        self.refreshDevices()
    }
    
    func loadDeviceSettings() {
        let loaded = NSKeyedUnarchiver.unarchiveObjectWithFile(Device.ArchivePath) as? [Device]
        if loaded != nil {
            self.deviceSettings = loaded!
        } else {
            self.devices = []
        }
        deviceSettingsLoaded = true
    }
    
    
    func saveDeviceSettings() {
        let isSuccessfulSave = NSKeyedArchiver.archiveRootObject(self.deviceSettings, toFile: Device.ArchivePath)
        if !isSuccessfulSave {
            NSLog("Failed to save device settings.")
        }
        deviceSettingsLoaded = true
    }
    func findDeviceSettings(device: AVCaptureDevice) -> Device {
        if (!deviceSettingsLoaded ) {
            loadDeviceSettings()
        }
        for d in deviceSettings {
            if d.uid == device.uniqueID {
                return d
            }
        }
        
        let newDevice = Device(fromDevice: device)!
        self.deviceSettings.append(newDevice)
        return newDevice
    }
    

    func applicationWillTerminate(aNotification: NSNotification) {
        
        self.notifications.deregisterAll()
    }

    func loadObservers() {
        
        notifications.registerObserver(AVCaptureSessionRuntimeErrorNotification, forObject: session, dispatchAsyncToMainQueue: true, block: {note in
            let err = note.userInfo![AVCaptureSessionErrorKey] as! NSError
            //self.window.presentError( err )
            NSLog(err.description)
        })
        
        
        notifications.registerObserver(AVCaptureSessionDidStartRunningNotification, forObject: session, block: {note in
            print("Did start running")
            self.refreshDevices()
        })
        notifications.registerObserver(AVCaptureSessionDidStopRunningNotification, forObject: session, block: {note in
            print("Did stop running")
        })

                
        notifications.registerObserver(AVCaptureDeviceWasConnectedNotification, forObject: nil, dispatchAsyncToMainQueue: true, block: {note in
            print("Device connected")
            self.refreshDevices()
        })
        notifications.registerObserver(AVCaptureDeviceWasDisconnectedNotification, forObject: nil, dispatchAsyncToMainQueue: true, block: {note in
            print("Device disconnected")
            self.refreshDevices()
        })
        
        
    }
    
    func startNewSession(device:AVCaptureDevice) -> Skin {
        
        let size = DeviceUtils(deviceType: .Phone).skinSize
        let frame = DeviceUtils.getCenteredRect(size, screenFrame: NSScreen.mainScreen()!.frame)
        
        let window = NSWindow(contentRect: frame,
            styleMask: NSBorderlessWindowMask,
            backing: NSBackingStoreType.Buffered, defer: false)
        
        window.movableByWindowBackground = true
        let frameView = NSMakeRect(0, 0,size.width, size.height)
        
        let skin = Skin(frame: frameView)
        skin.initWithDevice(device)
        skin.ownerWindow = window
        window.contentView!.addSubview(skin)
        
        skin.registerNotifications()
        skin.updateAspect()
        
        window.backgroundColor = NSColor.clearColor()
        window.opaque = false
        
        window.makeKeyAndOrderFront(NSApp)

        return skin
    }

    func refreshDevices() {
        
        self.devices = AVCaptureDevice.devicesWithMediaType(AVMediaTypeMuxed)
            +  AVCaptureDevice.devicesWithMediaType(AVMediaTypeVideo) as! [AVCaptureDevice]
        
        // A running device was disconnected?
        for(device, deviceView) in deviceSessions {
            if ( !self.devices.contains(device) ) {
                deviceView.endSession()
                deviceView.window?.close()
                self.deviceSessions[device] = nil
            }
        }
        
        
        // A new device connected?
        for device in self.devices {
            if device.modelID == "iOS Device" {
                if (!self.deviceSessions.keys.contains(device)) {
        
                    // support only one session for now, until multiple devices videos start working
                    if(self.deviceSessions.count > 0) {
                        print("Only one session supported.")
                        let alert = NSAlert()
                        alert.messageText = "Only one device supported"
                        alert.addButtonWithTitle("OK")
                        alert.informativeText = "You can only display one device at a time. Please disconnect your other device."
                        alert.runModal()

                        break;
                    } else {
                        self.deviceSessions[device] = startNewSession(device)
                    }
            }
        }
        }

        if self.deviceSessions.count > 0 {
           self.window!.close()
        } else {
           self.window!.makeKeyAndOrderFront(NSApp)
        }

        
    }
}

