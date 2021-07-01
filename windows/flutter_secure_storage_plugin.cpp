#include "include/flutter_secure_storage/flutter_secure_storage_plugin.h"

// This must be included before many other Windows headers.
#include <windows.h>
#include <wincred.h>
#include <atlstr.h>

// For getPlatformVersion; remove unless needed for your plugin implementation.
#include <VersionHelpers.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <map>
#include <memory>
#include <sstream>

namespace {

class FlutterSecureStoragePlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  FlutterSecureStoragePlugin();

  virtual ~FlutterSecureStoragePlugin();

 private:
  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  // Retrieves the value passed to the given param.
  std::optional<std::string> GetStringArg(
      const std::string& param,
      const flutter::EncodableMap* args);

  // Derive the key for a value given a method argument map.
  std::optional<std::string> FlutterSecureStoragePlugin::GetValueKey(const flutter::EncodableMap* args);

  // Gets the string name for the given int error code
  std::string GetErrorString(int& error_code);

  // Stores the given value under the given key.
  void Write(const std::string& key, const std::string& val);

  std::optional<std::string> Read(const std::string& key);

  void Delete(const std::string& key);
};

const std::string ELEMENT_PREFERENCES_KEY_PREFIX = "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIHNlY3VyZSBzdG9yYWdlCg";

// static
void FlutterSecureStoragePlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "plugins.it_nomads.com/flutter_secure_storage",
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<FlutterSecureStoragePlugin>();

  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto &call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

FlutterSecureStoragePlugin::FlutterSecureStoragePlugin() {}

FlutterSecureStoragePlugin::~FlutterSecureStoragePlugin() {}

std::optional<std::string> FlutterSecureStoragePlugin::GetValueKey(const flutter::EncodableMap* args) {
  auto key = this->GetStringArg("key", args);
  if (key.has_value())
    return ELEMENT_PREFERENCES_KEY_PREFIX + "_" + key.value();
  return std::nullopt;
}

std::optional<std::string> FlutterSecureStoragePlugin::GetStringArg(
    const std::string& param,
    const flutter::EncodableMap* args) {
  auto p = args->find(param);
  if (p == args->end())
    return std::nullopt;
  return std::get<std::string>(p->second);
}

std::string FlutterSecureStoragePlugin::GetErrorString(int& error_code) {
  switch (error_code) {
  case ERROR_NO_SUCH_LOGON_SESSION:
    return "ERROR_NO_SUCH_LOGIN_SESSION";
  case ERROR_INVALID_FLAGS:
    return "ERROR_INVALID_FLAGS";
  case ERROR_BAD_USERNAME:
    return "ERROR_BAD_USERNAME";
  case SCARD_E_NO_READERS_AVAILABLE:
    return "SCARD_E_NO_READERS_AVAILABLE";
  case SCARD_E_NO_SMARTCARD:
    return "SCARD_E_NO_SMARTCARD";
  case SCARD_W_REMOVED_CARD:
    return "SCARD_W_REMOVED_CARD";
  case SCARD_W_WRONG_CHV:
    return "SCARD_W_WRONG_CHV";
  case ERROR_INVALID_PARAMETER:
    return "ERROR_INVALID_PARAMETER";
  default:
    return "";
  }
}

void FlutterSecureStoragePlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  auto method = method_call.method_name();
  const auto* args = std::get_if<flutter::EncodableMap>(method_call.arguments());

  try {
    if (method == "write") {
      auto key = this->GetValueKey(args);
      auto val = this->GetStringArg("value", args);
      if (key.has_value() && val.has_value()) {
        this->Write(key.value(), val.value());
        result->Success();
      }
      else {
        result->Error("Exception occurred", "write");
      }
    }
    else if (method == "read") {
      auto key = this->GetValueKey(args);
      if (key.has_value()) {
        auto val = this->Read(key.value());
        result->Success(flutter::EncodableValue(val.value()));
      }
      else {
        result->Error("Exception occurred", "read");
      }
    }
    else if (method == "delete") {
      auto key = this->GetValueKey(args);
      if (key.has_value()) {
        this->Delete(key.value());
        result->Success();
      }
      else {
        result->Error("Exception occurred", "delete");
      }
    }
    else {
      result->NotImplemented();
    }
  }
  catch (int e) {
    auto str_code = this->GetErrorString(e);
    result->Error("Exception encountered: " + str_code, method);
  }
}

void FlutterSecureStoragePlugin::Write(const std::string& key, const std::string& val) {
  size_t len = 1 + strlen(val.c_str());

  CREDENTIALW cred = { 0 };
  cred.Type = CRED_TYPE_GENERIC;
  cred.TargetName = CA2CT(key.c_str());
  cred.CredentialBlobSize = (DWORD)len;
  cred.CredentialBlob = (LPBYTE)val.c_str();
  cred.Persist = CRED_PERSIST_LOCAL_MACHINE;

  bool ok = CredWriteW(&cred, 0);
  if (!ok) {
    throw GetLastError();
  }
}


std::optional<std::string> FlutterSecureStoragePlugin::Read(const std::string& key) {
  PCREDENTIALW pcred;
  LPCWSTR target_name = CA2CT(key.c_str());
  bool ok = CredReadW(target_name, CRED_TYPE_GENERIC, 0, &pcred);

  if (ok) {
    auto val = std::string((char*)pcred->CredentialBlob);
    CredFree(pcred);
    return val;
  }

  auto error = GetLastError();

  if (error == ERROR_NOT_FOUND) {
    return std::nullopt;
  }
  
  throw error;
}

void FlutterSecureStoragePlugin::Delete(const std::string& key) {
  auto wstr = std::wstring(key.begin(), key.end());
  bool ok = CredDeleteW(wstr.c_str(), CRED_TYPE_GENERIC, 0);
  if (!ok) {
    throw GetLastError();
  }
}

}  // namespace

void FlutterSecureStoragePluginRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  FlutterSecureStoragePlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
