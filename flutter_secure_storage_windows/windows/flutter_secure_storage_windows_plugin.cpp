#include "include/flutter_secure_storage_windows/flutter_secure_storage_windows_plugin.h"

// This must be included before many other Windows headers.
#include <windows.h>
#include <wincred.h>
#include <atlstr.h>
#include <ShlObj_core.h>
#include <sys/stat.h>
#include <errno.h>
#include <direct.h>
#include <bcrypt.h>

// For getPlatformVersion; remove unless needed for your plugin implementation.
#include <VersionHelpers.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <map>
#include <memory>
#include <sstream>
#include <iostream>
#include <fstream>
#include <string>
#include <regex>

#define NT_SUCCESS(Status) (((NTSTATUS)(Status)) >= 0)
#define STATUS_UNSUCCESSFUL ((NTSTATUS)0xC0000001L)

#pragma comment(lib, "version.lib")
#pragma comment(lib, "bcrypt.lib")

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

    DWORD GetApplicationSupportPath(std::wstring& path);

    std::wstring SanitizeDirString(std::wstring string);

    bool PathExists(const std::wstring& path);

    bool MakePath(const std::wstring& path);

    PBYTE GetEncryptionKey();

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

  static inline void rtrim(std::wstring& s) {
      s.erase(std::find_if(s.rbegin(), s.rend(), [](wchar_t ch) {
          return !std::isspace(ch);
          }).base(), s.end());
  }

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

  DWORD FlutterSecureStorageWindowsPlugin::GetApplicationSupportPath(std::wstring &path)
  {
      std::wstring companyName;
      std::wstring productName;
      TCHAR nameBuffer[MAX_PATH + 1]{};
      char* infoBuffer;
      DWORD versionInfoSize;
      DWORD resVal;
      UINT queryLen;
      LPVOID queryVal;
      LPWSTR appdataPath;
      std::wostringstream stream;

      SHGetKnownFolderPath(FOLDERID_RoamingAppData,KF_FLAG_DEFAULT,NULL,&appdataPath);
      
      if (nameBuffer == NULL) {
          return ERROR_OUTOFMEMORY;
      }

      resVal = GetModuleFileName(NULL,nameBuffer,MAX_PATH);
      if (resVal == 0) {
          return GetLastError();
      }

      versionInfoSize = GetFileVersionInfoSize(nameBuffer, NULL);
      if (versionInfoSize != 0) {
          infoBuffer = (char*) calloc(versionInfoSize,sizeof(char));
          if (infoBuffer == NULL) {
              return ERROR_OUTOFMEMORY;
          }
          if (GetFileVersionInfo(nameBuffer, 0, versionInfoSize, infoBuffer) == 0) {
              free(infoBuffer);
              infoBuffer = NULL;
          }
          else {

              if (VerQueryValue(infoBuffer, TEXT("\\StringFileInfo\\040904e4\\CompanyName"), &queryVal, &queryLen) != 0) {
                  companyName = SanitizeDirString(std::wstring((const TCHAR*)queryVal));
              }
              if (VerQueryValue(infoBuffer, TEXT("\\StringFileInfo\\040904e4\\ProductName"), &queryVal, &queryLen) != 0) {
                  productName = SanitizeDirString(std::wstring((const TCHAR*)queryVal));
              }
          }
          stream << appdataPath << "\\" << companyName << "\\" << productName;
          path = stream.str();
      }
      else {
          return GetLastError();
      }
      return ERROR_SUCCESS;

  }

  std::wstring FlutterSecureStorageWindowsPlugin::SanitizeDirString(std::wstring string)
  {
      std::wstring sanitizedString = std::regex_replace(string,std::wregex(L"[<>:\"/\\\\|?*]"),L"_");
      rtrim(sanitizedString);
      sanitizedString = std::regex_replace(sanitizedString, std::wregex(L"[.]+$"), L"");
      return sanitizedString;
  }

  bool FlutterSecureStorageWindowsPlugin::PathExists(const std::wstring& path)
  {
      struct _stat info;
      if (_wstat(path.c_str(), &info) != 0) {
          return false;
      }
      return (info.st_mode & _S_IFDIR) != 0;
  }

  bool FlutterSecureStorageWindowsPlugin::MakePath(const std::wstring& path)
  {
      int ret = _wmkdir(path.c_str());
      if (ret == 0) {
          return true;
      }
      switch (errno) {
      case ENOENT:
        {
          size_t pos = path.find_last_of('/');
          if (pos == std::wstring::npos)
              pos = path.find_last_of('\\');
          if (pos == std::wstring::npos)
              return false;
          if (!MakePath(path.substr(0, pos)))
              return false; 
        }
        return 0 == _wmkdir(path.c_str());
      case EEXIST:
          return PathExists(path);
      default:
          return false;
      }
  }

  PBYTE FlutterSecureStorageWindowsPlugin::GetEncryptionKey()
  {
      const size_t keySize = 16;
      DWORD credError = 0;
      PBYTE AesKey;
      PCREDENTIALW pcred;
      CA2W target_name(("key_"+ELEMENT_PREFERENCES_KEY_PREFIX).c_str());

      AesKey = (PBYTE)HeapAlloc(GetProcessHeap(), 0, keySize);
      if (NULL == AesKey) {
          return NULL;
      }

      bool ok = CredReadW(target_name.m_psz, CRED_TYPE_GENERIC, 0, &pcred);
      if (ok) {
          memcpy(AesKey, pcred->CredentialBlob, pcred->CredentialBlobSize);
          CredFree(pcred);
          return AesKey;
      }
      credError = GetLastError();
      if (credError != ERROR_NOT_FOUND) {
          return NULL;
      }
      
      if (BCryptGenRandom(NULL, AesKey, keySize, BCRYPT_USE_SYSTEM_PREFERRED_RNG) != ERROR_SUCCESS) {
          return NULL;
      }
      CREDENTIALW cred = { 0 };
      cred.Type = CRED_TYPE_GENERIC;
      cred.TargetName = target_name.m_psz;
      cred.CredentialBlobSize = keySize;
      cred.CredentialBlob = AesKey;
      cred.Persist = CRED_PERSIST_LOCAL_MACHINE;
      ok = CredWriteW(&cred, 0);
      if (!ok) {
          std::cerr << "Failed to write encryption key" << std::endl;
          return NULL;
      }
      return AesKey;
  }

  void FlutterSecureStorageWindowsPlugin::HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
  {
    auto method = method_call.method_name();
    const auto *args = std::get_if<flutter::EncodableMap>(method_call.arguments());
    std::wstring path;
    if (GetApplicationSupportPath(path) != ERROR_SUCCESS) {
        result->Error("Exception occurred", "GetApplicationSupportPath");
        return;
    }
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
      BCRYPT_ALG_HANDLE algoHandle = NULL;
      BCRYPT_KEY_HANDLE keyHandle = NULL;
      NTSTATUS status = STATUS_UNSUCCESSFUL;
      DWORD sizeData = 0,
          encryptionKeySize = 0,
          IVSize = 0,
          ciphertextSize = 0,
          rawKeySize = 16,
          plaintextSize = (DWORD)val.size();
      PBYTE encryptionKey = NULL,
          plaintext = NULL,
          IV = NULL,
          IVr = NULL,
          ciphertext = NULL,
          rawKey = GetEncryptionKey();

      std::wstring appSupportPath;
      std::basic_ofstream<BYTE> fs;

      if (!NT_SUCCESS(status = BCryptOpenAlgorithmProvider(&algoHandle, BCRYPT_AES_ALGORITHM, NULL, 0))) {
          wprintf(L"**** Error 0x%x returned by BCryptOpenAlgorithmProvider\n", status);
          goto Cleanup;
      }
      if (!NT_SUCCESS(status = BCryptGetProperty(algoHandle, BCRYPT_OBJECT_LENGTH, (PBYTE)&encryptionKeySize, sizeof(DWORD), &sizeData, 0))) {
          wprintf(L"**** Error 0x%x returned by BCryptGetProperty\n", status);
          goto Cleanup;
      }
      encryptionKey = (PBYTE)HeapAlloc(GetProcessHeap(), 0, encryptionKeySize);
      if (NULL == encryptionKey) {
          wprintf(L"**** memory allocation failed\n");
          goto Cleanup;
      }
      if (!NT_SUCCESS(status = BCryptGetProperty(algoHandle, BCRYPT_BLOCK_LENGTH, (PBYTE)&IVSize, sizeof(DWORD), &sizeData, 0))) {
          wprintf(L"**** Error 0x%x returned by BCryptGetProperty\n", status);
          goto Cleanup;
      }
      IV = (PBYTE)HeapAlloc(GetProcessHeap(), 0, IVSize);
      if (NULL == IV) {
          wprintf(L"**** memory allocation failed\n");
          goto Cleanup;
      }
      IVr = (PBYTE)HeapAlloc(GetProcessHeap(), 0, IVSize);
      if (NULL == IVr) {
          wprintf(L"**** memory allocation failed\n");
          goto Cleanup;
      }
      if (!NT_SUCCESS(status = BCryptGenRandom(NULL, IVr, IVSize, BCRYPT_USE_SYSTEM_PREFERRED_RNG))) {
          wprintf(L"**** Error 0x%x returned by BCryptGenRandom\n", status);
          goto Cleanup;
      }
      memcpy(IV, IVr, IVSize);
      if (!NT_SUCCESS(status = BCryptSetProperty(algoHandle, BCRYPT_CHAINING_MODE, (PBYTE)BCRYPT_CHAIN_MODE_CBC, sizeof(BCRYPT_CHAIN_MODE_CBC), 0))) {
          wprintf(L"**** Error 0x%x returned by BCryptSetProperty\n", status);
          goto Cleanup;
      }
      if (!NT_SUCCESS(status = BCryptGenerateSymmetricKey(algoHandle, &keyHandle, encryptionKey, encryptionKeySize, rawKey, rawKeySize, 0))) {
          wprintf(L"**** Error 0x%x returned by BCryptGenerateSymmetricKey\n", status);
          goto Cleanup;
      }
      plaintext = (PBYTE)HeapAlloc(GetProcessHeap(), 0, plaintextSize);
      if (NULL == plaintext) {
          wprintf(L"**** memory allocation failed\n");
          goto Cleanup;
      }
      memcpy(plaintext, val.c_str(), plaintextSize);
      if (!NT_SUCCESS(status = BCryptEncrypt(keyHandle, plaintext, plaintextSize, NULL, IV, IVSize, NULL, 0, &ciphertextSize, BCRYPT_BLOCK_PADDING))) {
          wprintf(L"**** Error 0x%x returned by BCryptEncrypt\n", status);
          goto Cleanup;
      }
      ciphertext = (PBYTE)HeapAlloc(GetProcessHeap(), 0, ciphertextSize);
      if (NULL == ciphertext) {
          wprintf(L"**** memory allocation failed\n");
          goto Cleanup;
      }
      if (!NT_SUCCESS(status = BCryptEncrypt(keyHandle, plaintext, plaintextSize, NULL, IV, IVSize, ciphertext, ciphertextSize, &sizeData, BCRYPT_BLOCK_PADDING))) {
          wprintf(L"**** Error 0x%x returned by BCryptEncrypt\n", status);
          goto Cleanup;
      }
      GetApplicationSupportPath(appSupportPath);
      if (!PathExists(appSupportPath)) {
          MakePath(appSupportPath);
      }
      fs = std::basic_ofstream<BYTE>(appSupportPath + L"\\" + std::wstring(key.begin(), key.end()) + L".secure", std::ios::binary|std::ios::trunc);
      fs.write(IVr, IVSize);
      fs.write(ciphertext, ciphertextSize);
      fs.close();
  Cleanup:
      if (algoHandle) {
          BCryptCloseAlgorithmProvider(algoHandle, 0);
      }
      if (keyHandle) {
          BCryptDestroyKey(keyHandle);
      }
      if (encryptionKey) {
          HeapFree(GetProcessHeap(), 0, encryptionKey);
      }
      if (ciphertext) {
          HeapFree(GetProcessHeap(), 0, ciphertext);
      }
      if (plaintext) {
          HeapFree(GetProcessHeap(), 0, plaintext);
      }
      if (IV) {
          HeapFree(GetProcessHeap(), 0, IV);
      }
      if (IVr) {
          HeapFree(GetProcessHeap(), 0, IVr);
      }
      if (rawKey) {
          HeapFree(GetProcessHeap(), 0, rawKey);
      }
    /*size_t len = 1 + strlen(val.c_str());
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
    }*/
  }

  std::optional<std::string> FlutterSecureStorageWindowsPlugin::Read(const std::string &key)
  {
      BCRYPT_ALG_HANDLE algoHandle = NULL;
      BCRYPT_KEY_HANDLE keyHandle = NULL;
      NTSTATUS status = STATUS_UNSUCCESSFUL;
      DWORD ciphertextSize = 0,
          plaintextSize = 0,
          encryptionKeySize = 0,
          IVSize = 0,
          sizeData = 0,
          rawKeySize = 16;
      PBYTE ciphertext = NULL,
          plaintext = NULL,
          encryptionKey = NULL,
          IV = NULL,
          rawKey = NULL;

      std::wstring appSupportPath;
      std::basic_ifstream<BYTE> fs;
      PBYTE fileBuffer;
      std::streampos fileSize;
      std::optional<std::string> returnVal = std::nullopt;

      GetApplicationSupportPath(appSupportPath);
      if (!PathExists(appSupportPath)) {
          MakePath(appSupportPath);
      }
      //Read full file into a buffer
      fs = std::basic_ifstream<BYTE>(appSupportPath + L"\\" + std::wstring(key.begin(), key.end()) + L".secure", std::ios::binary);
      if (!fs.good()) {
          //TODO add backwards comp.
          goto Cleanup;
      }
      fs.unsetf(std::ios::skipws);
      fs.seekg(0, std::ios::end);
      fileSize = fs.tellg();
      fs.seekg(0, std::ios::beg);
      fileBuffer = (PBYTE)HeapAlloc(GetProcessHeap(), 0, fileSize);
      if (NULL == fileBuffer) {
          wprintf(L"**** memory allocation failed\n");
          goto Cleanup;
      }
      fs.read(fileBuffer, fileSize);
      fs.close();

      rawKey = GetEncryptionKey();
      if (!NT_SUCCESS(status = BCryptOpenAlgorithmProvider(&algoHandle, BCRYPT_AES_ALGORITHM, NULL, 0))) {
          wprintf(L"**** Error 0x%x returned by BCryptOpenAlgorithmProvider\n", status);
          goto Cleanup;
      }
      if (!NT_SUCCESS(status = BCryptGetProperty(algoHandle, BCRYPT_OBJECT_LENGTH, (PBYTE)&encryptionKeySize, sizeof(DWORD), &sizeData, 0))) {
          wprintf(L"**** Error 0x%x returned by BCryptGetProperty\n", status);
          goto Cleanup;
      }
      encryptionKey = (PBYTE)HeapAlloc(GetProcessHeap(), 0, encryptionKeySize);
      if (NULL == encryptionKey) {
          wprintf(L"**** memory allocation failed\n");
          goto Cleanup;
      }
      if (!NT_SUCCESS(status = BCryptGetProperty(algoHandle, BCRYPT_BLOCK_LENGTH, (PBYTE)&IVSize, sizeof(DWORD), &sizeData, 0))) {
          wprintf(L"**** Error 0x%x returned by BCryptGetProperty\n", status);
          goto Cleanup;
      }
      IV = (PBYTE)HeapAlloc(GetProcessHeap(), 0, IVSize);
      if (NULL == IV) {
          wprintf(L"**** memory allocation failed\n");
          goto Cleanup;
      }
      if (IVSize > fileSize) {
          wprintf(L"**** invalid fileSize\n");
          goto Cleanup;
      }
      memcpy(IV, fileBuffer, IVSize);
      if (!NT_SUCCESS(status = BCryptSetProperty(algoHandle, BCRYPT_CHAINING_MODE, (PBYTE)BCRYPT_CHAIN_MODE_CBC, sizeof(BCRYPT_CHAIN_MODE_CBC), 0))) {
          wprintf(L"**** Error 0x%x returned by BCryptSetProperty\n", status);
          goto Cleanup;
      }
      if (!NT_SUCCESS(status = BCryptGenerateSymmetricKey(algoHandle, &keyHandle, encryptionKey, encryptionKeySize, rawKey, rawKeySize, 0))) {
          wprintf(L"**** Error 0x%x returned by BCryptGenerateSymmetricKey\n", status);
          goto Cleanup;
      }
      ciphertextSize = (DWORD)fileSize - IVSize;
      ciphertext = (PBYTE)HeapAlloc(GetProcessHeap(), 0, ciphertextSize);
      if (NULL == ciphertext) {
          wprintf(L"**** memory allocation failed\n");
          goto Cleanup;
      }
      memcpy(ciphertext, &fileBuffer[IVSize], ciphertextSize);
      if (!NT_SUCCESS(status = BCryptDecrypt(keyHandle, ciphertext, ciphertextSize, NULL, IV, IVSize, NULL, 0, &plaintextSize, BCRYPT_BLOCK_PADDING))) {
          wprintf(L"**** Error 0x%x returned by BCryptDecrypt1\n", status);
          goto Cleanup;
      }
      plaintext = (PBYTE)HeapAlloc(GetProcessHeap(), 0, plaintextSize);
      if (NULL == plaintext) {
          wprintf(L"**** memory allocation failed\n");
          goto Cleanup;
      }
      memset(plaintext, 0, plaintextSize);
      if (!NT_SUCCESS(status = BCryptDecrypt(keyHandle, ciphertext, ciphertextSize, NULL, IV, IVSize, plaintext, plaintextSize, &sizeData, BCRYPT_BLOCK_PADDING))) {
          wprintf(L"**** Error 0x%x returned by BCryptDecrypt2\n", status);
          goto Cleanup;
      }
      returnVal = (char*)plaintext;
  Cleanup:
      if (algoHandle)
      {
          BCryptCloseAlgorithmProvider(algoHandle, 0);
      }

      if (keyHandle)
      {
          BCryptDestroyKey(keyHandle);
      }

      if (ciphertext)
      {
          HeapFree(GetProcessHeap(), 0, ciphertext);
      }

      if (plaintext)
      {
          HeapFree(GetProcessHeap(), 0, plaintext);
      }

      if (encryptionKey)
      {
          HeapFree(GetProcessHeap(), 0, encryptionKey);
      }

      if (IV)
      {
          HeapFree(GetProcessHeap(), 0, IV);
      }

      if (rawKey) {
          HeapFree(GetProcessHeap(), 0, rawKey);
      }
      return returnVal;
    /*
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
    throw error;*/
  }

  flutter::EncodableMap FlutterSecureStorageWindowsPlugin::ReadAll()
  {
      WIN32_FIND_DATA searchRes;
      HANDLE hFile;
      std::wstring appSupportPath;

      GetApplicationSupportPath(appSupportPath);
      if (!PathExists(appSupportPath)) {
          MakePath(appSupportPath);
      }
      hFile = FindFirstFile((appSupportPath + L"\\*.secure").c_str(), &searchRes);
      if (hFile == INVALID_HANDLE_VALUE) {
          return flutter::EncodableMap();
      }

      flutter::EncodableMap creds;

      do {
          std::wstring fileName(searchRes.cFileName);
          size_t pos = fileName.find(L".secure");
          fileName.erase(pos, 7);
          char* out = new char[fileName.length() + 1];
          size_t charsConverted = 0;
          wcstombs_s(&charsConverted, out, fileName.length() + 1, fileName.c_str(), fileName.length() + 1);
          std::optional<std::string> val = this->Read(out);
          auto key = this->RemoveKeyPrefix(out);
          if (val.has_value()) {
              creds[key] = val.value();
              continue;
          }
          //Delete file if we can't read it? 
      } while (FindNextFile(hFile, &searchRes) != 0);

      return creds;
    /*PCREDENTIALW* pcreds;
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

    return creds;*/
  }

  void FlutterSecureStorageWindowsPlugin::Delete(const std::string &key)
  {
      std::wstring appSupportPath;
      GetApplicationSupportPath(appSupportPath);
      auto wstr = std::wstring(key.begin(), key.end());
      BOOL ok = DeleteFile((appSupportPath + L"\\" + wstr + L".secure").c_str());
      if (!ok) {
          DWORD error = GetLastError();
          if (error != ERROR_NOT_FOUND) {
              throw error;
          }
      }
    /*bool ok = CredDeleteW(wstr.c_str(), CRED_TYPE_GENERIC, 0);
    if (!ok)
    {
      auto error = GetLastError();

      // Silently ignore if we try to delete a key that doesn't exist
      if (error == ERROR_NOT_FOUND)
        return;

      throw error;
    }*/
  }

  void FlutterSecureStorageWindowsPlugin::DeleteAll()
  {

      WIN32_FIND_DATA searchRes;
      HANDLE hFile;
      std::wstring appSupportPath;

      GetApplicationSupportPath(appSupportPath);
      if (!PathExists(appSupportPath)) {
          MakePath(appSupportPath);
      }
      hFile = FindFirstFile((appSupportPath + L"\\*.secure").c_str(), &searchRes);
      if (hFile == INVALID_HANDLE_VALUE) {
          return;
      }
      do {
          std::wstring fileName(searchRes.cFileName);
          BOOL ok = DeleteFile((appSupportPath + L"\\" + fileName).c_str());
          if (!ok) {
              throw GetLastError();
          }
      } while (FindNextFile(hFile, &searchRes) != 0);
    /*PCREDENTIALW* pcreds;
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

    CredFree(pcreds);*/
  }

  bool FlutterSecureStorageWindowsPlugin::ContainsKey(const std::string &key)
  {
      std::wstring appSupportPath;
      GetApplicationSupportPath(appSupportPath);
      std::wstring wstr = std::wstring(key.begin(), key.end());
      if (INVALID_FILE_ATTRIBUTES == GetFileAttributes((appSupportPath + L"\\" + wstr + L".secure").c_str())) {
          return false;
      }
      return true;
    /*PCREDENTIALW pcred;
    CA2W target_name(key.c_str());

    bool ok = CredReadW(target_name.m_psz, CRED_TYPE_GENERIC, 0, &pcred);
    if (ok) return true;

    auto error = GetLastError();
    if (error == ERROR_NOT_FOUND)
      return false;
    throw error;*/
  }
} // namespace

void FlutterSecureStorageWindowsPluginRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar)
{
  FlutterSecureStorageWindowsPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
