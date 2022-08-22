//
//  SwiftFlutterSecureStoragePlugin.swift
//  flutter_secure_storage
//
//  Created by Julian Steenbakker on 22/08/2022.
//

import Flutter

public class SwiftFlutterSecureStoragePlugin: NSObject, FlutterPlugin {
    
    private let flutterSecureStorageManager: FlutterSecureStorageManager = FlutterSecureStorageManager()
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "plugins.it_nomads.com/flutter_secure_storage", binaryMessenger: registrar.messenger())
        let instance = SwiftFlutterSecureStoragePlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch (call.method) {
        case "read":
            read(call, result)
        case "write":
            write(call, result)
        case "delete":
            delete(call, result)
        case "deleteAll":
            deleteAll(call, result)
        case "readAll":
            readAll(call, result)
        case "containsKey":
            containsKey(call, result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func read(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        let arguments: [String: Any] = call.arguments as! [String : Any]
        let options: [String: Any] = arguments["options"] as! [String : Any]
        let accountName = options["accountName"] as! String
        let groupIdString = options["groupId"] as! String?
        
        let key = arguments["key"] as! String
        let synchronizableString = options["synchronizable"] as! String?
        
        let groupId:Int? = groupIdString != nil ? Int(groupIdString!) : nil
        let synchronizable: Bool = synchronizableString != nil ? Bool(synchronizableString!)! : false
        
        let value = flutterSecureStorageManager.read(key: key, groupId: groupId, accountName: accountName, synchronizable: synchronizable)
        result(value)
    }
    
    private func write(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        let arguments: [String: Any] = call.arguments as! [String : Any]
        let options: [String: Any] = arguments["options"] as! [String : Any]
        let accountName = options["accountName"] as! String
        let groupIdString = options["groupId"] as! String?
        let synchronizableString = options["synchronizable"] as! String?
        
        let groupId:Int? = groupIdString != nil ? Int(groupIdString!) : nil
        let synchronizable: Bool = synchronizableString != nil ? Bool(synchronizableString!)! : false
        
        let key = arguments["key"] as! String
        let accessibility = options["accessibility"] as! String
        
        if (!(arguments["value"] is String)){
            result("Invalid parameter's type");
            return;
        }
        let value = arguments["value"] as! String
        
        flutterSecureStorageManager.write(key: key, value: value, groupId: groupId, accountName: accountName, synchronizable: synchronizable, accessibility: accessibility)
        
        result(nil)
    }
    
    private func delete(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        let arguments: [String: Any] = call.arguments as! [String : Any]
        let options: [String: Any] = arguments["options"] as! [String : Any]
        let accountName = options["accountName"] as! String
        let groupIdString = options["groupId"] as! String?
        let synchronizableString = options["synchronizable"] as! String?
        
        let groupId:Int? = groupIdString != nil ? Int(groupIdString!) : nil
        let synchronizable: Bool = synchronizableString != nil ? Bool(synchronizableString!)! : false
        
        let key = arguments["key"] as! String
        
        flutterSecureStorageManager.delete(key: key, groupId: groupId, accountName: accountName, synchronizable: synchronizable)
        
        result(nil)
    }
    
    private func deleteAll(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        let arguments: [String: Any] = call.arguments as! [String : Any]
        let options: [String: Any] = arguments["options"] as! [String : Any]
        let accountName = options["accountName"] as! String
        let groupIdString = options["groupId"] as! String?
        let synchronizableString = options["synchronizable"] as! String?
        
        let groupId:Int? = groupIdString != nil ? Int(groupIdString!) : nil
        let synchronizable: Bool = synchronizableString != nil ? Bool(synchronizableString!)! : false
        
        flutterSecureStorageManager.deleteAll(groupId: groupId, accountName: accountName, synchronizable: synchronizable)
        
        result(nil)
    }
    
    private func readAll(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        let arguments: [String: Any] = call.arguments as! [String : Any]
        let options: [String: Any] = arguments["options"] as! [String : Any]
        let accountName = options["accountName"] as! String
        let groupIdString = options["groupId"] as! String?
        let synchronizableString = options["synchronizable"] as! String?
        
        let groupId:Int? = groupIdString != nil ? Int(groupIdString!) : nil
        let synchronizable: Bool = synchronizableString != nil ? Bool(synchronizableString!)! : false
        
        let value = flutterSecureStorageManager.readAll(groupId: groupId, accountName: accountName, synchronizable: synchronizable)
        
        result(value);
    }
    
    private func containsKey(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        let arguments: [String: Any] = call.arguments as! [String : Any]
        let options: [String: Any] = arguments["options"] as! [String : Any]
        let accountName = options["accountName"] as! String
        let groupIdString = options["groupId"] as! String?
        let synchronizableString = options["synchronizable"] as! String?
        
        let groupId:Int? = groupIdString != nil ? Int(groupIdString!) : nil
        let synchronizable: Bool = synchronizableString != nil ? Bool(synchronizableString!)! : false
        
        let key = arguments["key"] as! String
        
        let value = flutterSecureStorageManager.containsKey(key: key, groupId: groupId, accountName: accountName, synchronizable: synchronizable)
        
        result(value);
    }
    
}
