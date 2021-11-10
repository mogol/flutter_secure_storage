#include "include/flutter_secure_storage_windows/flutter_secure_storage_windows_plugin.h"

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

namespace
{

  class FlutterSecureStorageWindowsPlugin : public flutter::Plugin
  {
  public:
    static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

    FlutterSecureStorageWindowsPlugin();

    virtual ~FlutterSecureStorageWindowsPlugin();

  private:
    // Called when a method is called on this plugin's channel from Dart.
    void HandleMethodCall(
        const flutter::MethodCall<flutter::EncodableValue> &method_call,
        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

    // Retrieves the value passed to the given param.
    std::optional<std::string> GetStringArg(
        const std::string &param,
        const flutter::EncodableMap *args);

    // Derive the key for a value given a method argument map.
    std::optional<std::string> FlutterSecureStorageWindowsPlugin::GetValueKey(const flutter::EncodableMap *args);

    // Removes prefix of the given storage key.
    // 
    // The prefix (defined by ELEMENT_PREFERENCES_KEY_PREFIX) is added automatically when writing to storage,
    // to distinguish values that are written by this plugin from values that are not.
    std::string RemoveKeyPrefix(const std::string &key);

    // Gets the string name for the given int error code
    std::string GetErrorString(const DWORD &error_code);

    // Stores the given value under the given key.
    void Write(const std::string &key, const std::string &val);

    std::optional<std::string> Read(const std::string &key);

    flutter::EncodableMap ReadAll();

    void Delete(const std::string &key);

    void DeleteAll();

    bool ContainsKey(const std::string &key);
  };

  const std::string ELEMENT_PREFERENCES_KEY_PREFIX = SECURE_STORAGE_KEY_PREFIX;
  const int ELEMENT_PREFERENCES_KEY_PREFIX_LENGTH = (sizeof SECURE_STORAGE_KEY_PREFIX) - 1;

  // this string is used to filter the credential storage so that only the values written
  // by this plugin shows up.
  const CA2W CREDENTIAL_FILTER((ELEMENT_PREFERENCES_KEY_PREFIX + '*').c_str());

  // static
  void FlutterSecureStorageWindowsPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarWindows *registrar)
  {
    auto channel =
        std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
            registrar->messenger(), "plugins.it_nomads.com/flutter_secure_storage",
            &flutter::StandardMethodCodec::GetInstance());

    auto plugin = std::make_unique<FlutterSecureStorageWindowsPlugin>();

    channel->SetMethodCallHandler(
        [plugin_pointer = plugin.get()](const auto &call, auto result)
        {
          plugin_pointer->HandleMethodCall(call, std::move(result));
        });

    registrar->AddPlugin(std::move(plugin));
  }

  FlutterSecureStorageWindowsPlugin::FlutterSecureStorageWindowsPlugin() {}

  FlutterSecureStorageWindowsPlugin::~FlutterSecureStorageWindowsPlugin() {}

  std::optional<std::string> FlutterSecureStorageWindowsPlugin::GetValueKey(const flutter::EncodableMap *args)
  {
    auto key = this->GetStringArg("key", args);
    if (key.has_value())
      return ELEMENT_PREFERENCES_KEY_PREFIX + key.value();
    return std::nullopt;
  }

  std::string FlutterSecureStorageWindowsPlugin::RemoveKeyPrefix(const std::string& key)
  {
    return key.substr(ELEMENT_PREFERENCES_KEY_PREFIX_LENGTH);
  }

  std::optional<std::string> FlutterSecureStorageWindowsPlugin::GetStringArg(
      const std::string &param,
      const flutter::EncodableMap *args)
  {
    auto p = args->find(param);
    if (p == args->end())
      return std::nullopt;
    return std::get<std::string>(p->second);
  }

  std::string FlutterSecureStorageWindowsPlugin::GetErrorString(const DWORD &error_code)
  {
    switch (error_code)
    {
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
      return "UNKNOWN_ERROR";
    }
  }

  void FlutterSecureStorageWindowsPlugin::HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
  {
    auto method = method_call.method_name();
    const auto *args = std::get_if<flutter::EncodableMap>(method_call.arguments());

    try
    {
      if (method == "write")
      {
        auto key = this->GetValueKey(args);
        auto val = this->GetStringArg("value", args);
        if (key.has_value())
        {
          if (val.has_value())
            this->Write(key.value(), val.value());
          else
            this->Delete(key.value());
          result->Success();
        }
        else
        {
          result->Error("Exception occurred", "write");
        }
      }
      else if (method == "read")
      {
        auto key = this->GetValueKey(args);
        if (key.has_value())
        {
          auto val = this->Read(key.value());
          if (val.has_value())
            result->Success(flutter::EncodableValue(val.value()));
          else
            result->Success();
        }
        else
        {
          result->Error("Exception occurred", "read");
        }
      }
      else if (method == "readAll")
      {
        auto creds = this->ReadAll();
        result->Success(flutter::EncodableValue(creds));
      }
      else if (method == "delete")
      {
        auto key = this->GetValueKey(args);
        if (key.has_value())
        {
          this->Delete(key.value());
          result->Success();
        }
        else
        {
          result->Error("Exception occurred", "delete");
        }
      }
      else if (method == "deleteAll")
      {
        this->DeleteAll();
        result->Success();
      }
      else if (method == "containsKey")
      {
        auto key = this->GetValueKey(args);
        if (key.has_value())
        {
          auto contains_key = this->ContainsKey(key.value());
          result->Success(flutter::EncodableValue(contains_key));
        }
        else
        {
          result->Error("Exception occurred", "containsKey");
        }
      }
      else
      {
        result->NotImplemented();
      }
    }
    catch (DWORD e)
    {
      auto str_code = this->GetErrorString(e);
      result->Error("Exception encountered: " + str_code, method);
    }
  }

  void FlutterSecureStorageWindowsPlugin::Write(const std::string &key, const std::string &val)
  {
    size_t len = 1 + strlen(val.c_str());
    CA2W keyw(key.c_str());

    CREDENTIALW cred = {0};
    cred.Type = CRED_TYPE_GENERIC;
    cred.TargetName = keyw.m_psz;
    cred.CredentialBlobSize = (DWORD)len;
    cred.CredentialBlob = (LPBYTE)val.c_str();
    cred.Persist = CRED_PERSIST_LOCAL_MACHINE;

    bool ok = CredWriteW(&cred, 0);
    if (!ok)
    {
      throw GetLastError();
    }
  }

  std::optional<std::string> FlutterSecureStorageWindowsPlugin::Read(const std::string &key)
  {
    PCREDENTIALW pcred;
    CA2W target_name(key.c_str());
    bool ok = CredReadW(target_name.m_psz, CRED_TYPE_GENERIC, 0, &pcred);

    if (ok)
    {
      auto val = std::string((char *)pcred->CredentialBlob);
      CredFree(pcred);
      return val;
    }

    auto error = GetLastError();
    if (error == ERROR_NOT_FOUND)
      return std::nullopt;
    throw error;
  }

  flutter::EncodableMap FlutterSecureStorageWindowsPlugin::ReadAll()
  {
    PCREDENTIALW* pcreds;
    DWORD cred_count = 0;

    bool ok = CredEnumerateW(CREDENTIAL_FILTER.m_psz, 0, &cred_count, &pcreds);
    if (!ok)
    {
      auto error = GetLastError();
      if (error == ERROR_NOT_FOUND)
        return flutter::EncodableMap();
      throw error;
    }

    flutter::EncodableMap creds;

    for (DWORD i = 0; i < cred_count; i++)
    {
      auto pcred = pcreds[i];
      std::string target_name = CW2A(pcred->TargetName);
      auto val = std::string((char*)pcred->CredentialBlob);
      auto key = this->RemoveKeyPrefix(target_name);

      creds[key] = val;
    }

    CredFree(pcreds);

    return creds;
  }

  void FlutterSecureStorageWindowsPlugin::Delete(const std::string &key)
  {
    auto wstr = std::wstring(key.begin(), key.end());
    bool ok = CredDeleteW(wstr.c_str(), CRED_TYPE_GENERIC, 0);
    if (!ok)
    {
      auto error = GetLastError();

      // Silently ignore if we try to delete a key that doesn't exist
      if (error == ERROR_NOT_FOUND)
        return;

      throw error;
    }
  }

  void FlutterSecureStorageWindowsPlugin::DeleteAll()
  {
    PCREDENTIALW* pcreds;
    DWORD cred_count = 0;
    
    bool read_ok = CredEnumerateW(CREDENTIAL_FILTER.m_psz, 0, &cred_count, &pcreds);
    if (!read_ok)
    {
      auto error = GetLastError();
      if (error == ERROR_NOT_FOUND)
        // No credentials to delete
        return;
      throw error;
    }

    for (DWORD i = 0; i < cred_count; i++)
    {
      auto pcred = pcreds[i];
      auto target_name = pcred->TargetName;
      
      bool delete_ok = CredDeleteW(target_name, CRED_TYPE_GENERIC, 0);
      if (!delete_ok)
      {
        throw GetLastError();
      }
    }

    CredFree(pcreds);
  }

  bool FlutterSecureStorageWindowsPlugin::ContainsKey(const std::string &key)
  {
    PCREDENTIALW pcred;
    CA2W target_name(key.c_str());

    bool ok = CredReadW(target_name.m_psz, CRED_TYPE_GENERIC, 0, &pcred);
    if (ok) return true;

    auto error = GetLastError();
    if (error == ERROR_NOT_FOUND)
      return false;
    throw error;
  }
} // namespace

void FlutterSecureStorageWindowsPluginRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar)
{
  FlutterSecureStorageWindowsPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
