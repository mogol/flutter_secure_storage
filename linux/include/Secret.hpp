#include "FHashTable.hpp"
#include <json/json.h>
#include <libsecret/secret.h>
#include <memory>
#include <sstream>

class SecretStorage {
  FHashTable m_attributes;
  std::string label;

public:
  const char *getLabel() { return label.c_str(); }
  void setLabel(const char *label) { this->label = label; }

  SecretStorage(const char *_label = "default") : label(_label) {}

  void addAttribute(const char *key, const char *value) {
    m_attributes.insert(key, value);
  }

  bool addItem(const char *key, const char *value) {
    Json::Value root = readFromKeyring();
    root[key] = value;
    return this->storeToKeyring(root);
  }

  std::string getItem(const char *key) {
    std::string result;
    Json::Value root = readFromKeyring();
    Json::Value resultJson = root[key];
    if (resultJson.isString()) {
      result = resultJson.asString();
      return result;
    }
    return "";
  }

  void deleteItem(const char *key) {
    Json::Value root = readFromKeyring();
    root.removeMember(key);
    this->storeToKeyring(root);
  }

  bool deleteKeyring() { return this->storeToKeyring(Json::Value()); }

  bool storeToKeyring(Json::Value value) {
    Json::StreamWriterBuilder builder;
    builder["indentation"] = ""; // If you want whitespace-less output
    const std::string output = Json::writeString(builder, value);
    std::unique_ptr<GError> err = nullptr;

    auto ptrToErr = err.get();
    bool result = secret_password_storev_sync(
        nullptr, m_attributes.getGHashTable(), nullptr, label.c_str(),
        output.c_str(), nullptr, &ptrToErr);
    if (err != nullptr) {
      throw err;
    }
    return result;
  }

  Json::Value readFromKeyring() {
    std::stringstream sstream;
    Json::Value root;
    std::unique_ptr<GError> err = nullptr;
    auto ptrToErr = err.get();
    const gchar *result = secret_password_lookupv_sync(
        nullptr, m_attributes.getGHashTable(), nullptr, &ptrToErr);
    if (err != nullptr) {
      throw err;
    }
    if (result == nullptr || strcmp(result, "") == 0) {
      return root;
    }
    sstream << result;
    sstream >> root;
    return root;
  }
};