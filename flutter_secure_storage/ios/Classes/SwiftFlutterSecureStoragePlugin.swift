//
//  SwiftFlutterSecureStoragePlugin.swift
//  flutter_secure_storage
//
//  Created by Julian Steenbakker on 22/08/2022.
//

import Flutter

public class SwiftFlutterSecureStoragePlugin: NSObject, FlutterPlugin {
    
    private let flutterSecureStorageManager: FlutterSecureStorage = FlutterSecureStorage()
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "plugins.it_nomads.com/flutter_secure_storage", binaryMessenger: registrar.messenger())
        let instance = SwiftFlutterSecureStoragePlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        
        func handleResult(_ value: Any?) {
            DispatchQueue.main.async {
                result(value)
            }
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            switch (call.method) {
            case "read":
                self.read(call, handleResult)
            case "write":
                self.write(call, handleResult)
            case "delete":
                self.delete(call, handleResult)
            case "deleteAll":
                self.deleteAll(call, handleResult)
            case "readAll":
                self.readAll(call, handleResult)
            case "containsKey":
                self.containsKey(call, handleResult)
            default:
                handleResult(FlutterMethodNotImplemented)
            }
        }
    }
    
    private func read(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        let values = parseCall(call)
        if (values.key == nil) {
            result(FlutterError.init(code: "Missing Parameter", message: "write requires key parameter", details: nil))
            return
        }
        
        let response = flutterSecureStorageManager.read(key: values.key!, groupId: values.groupId, accountName: values.accountName, synchronizable: values.synchronizable)
        result(response.value)
    }
    
    private func write(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        if (!((call.arguments as! [String : Any?])["value"] is String)){
            result(FlutterError.init(code: "Invalid Parameter", message: "key parameter must be String", details: nil))
            return;
        }
        
        let values = parseCall(call)
        if (values.key == nil) {
            result(FlutterError.init(code: "Missing Parameter", message: "write requires key parameter", details: nil))
            return
        }
        
        if (values.value == nil) {
            result(FlutterError.init(code: "Missing Parameter", message: "write requires value parameter", details: nil))
            return
        }
        
        let response = flutterSecureStorageManager.write(key: values.key!, value: values.value!, groupId: values.groupId, accountName: values.accountName, synchronizable: values.synchronizable, accessibility: values.accessibility)
        
        result(response)
    }
    
    private func delete(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        let values = parseCall(call)
        if (values.key == nil) {
            result(FlutterError.init(code: "Missing Parameter", message: "delete requires key parameter", details: nil))
            return
        }
        
        let response = flutterSecureStorageManager.delete(key: values.key!, groupId: values.groupId, accountName: values.accountName, synchronizable: values.synchronizable)
        
        result(response)
    }
    
    private func deleteAll(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        let values = parseCall(call)
        
        let response = flutterSecureStorageManager.deleteAll(groupId: values.groupId, accountName: values.accountName, synchronizable: values.synchronizable)
        
        result(response)
    }
    
    private func readAll(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        let values = parseCall(call)
        
        let response = flutterSecureStorageManager.readAll(groupId: values.groupId, accountName: values.accountName, synchronizable: values.synchronizable)
        
        result(response.value);
    }
    
    private func containsKey(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        let values = parseCall(call)
        if (values.key == nil) {
            result(FlutterError.init(code: "Missing Parameter", message: "containsKey requires key parameter", details: nil))
        }
        
        let response = flutterSecureStorageManager.containsKey(key: values.key!, groupId: values.groupId, accountName: values.accountName, synchronizable: values.synchronizable)
        
        result(response);
    }
    
    private func parseCall(_ call: FlutterMethodCall) -> FlutterSecureStorageRequest {
        let arguments = call.arguments as! [String : Any?]
        let options = arguments["options"] as! [String : Any?]
        
        let accountName = options["accountName"] as? String
        let groupId = options["groupId"] as? String
        let synchronizableString = options["synchronizable"] as? String
        
        
        let synchronizable: Bool = synchronizableString != nil ? Bool(synchronizableString!)! : false
        
        let key = arguments["key"] as? String
        let accessibility = options["accessibility"] as? String
        let value = arguments["value"] as? String
        
        return FlutterSecureStorageRequest(
            accountName: accountName,
            groupId: groupId,
            synchronizable: synchronizable,
            accessibility: accessibility, key: key, value: value
        )
    }
    
    struct FlutterSecureStorageRequest {
        var accountName: String?
        var groupId: String?
        var synchronizable: Bool?
        var accessibility: String?
        var key: String?
        var value: String?
    }
    
}
