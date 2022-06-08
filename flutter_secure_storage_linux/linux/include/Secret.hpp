#include "FHashTable.hpp"
#include <json/json.h>
#include <libsecret/secret.h>
#include <memory>

class SecretStorage {
  FHashTable m_attributes;
  std::string label;
  SecretSchema the_schema;

public:
  const char *getLabel() { return label.c_str(); }
  void setLabel(const char *label) { this->label = label; }

  SecretStorage(const char *_label = "default") : label(_label) {
    the_schema = {label.c_str(),
                  SECRET_SCHEMA_NONE,
                  {
                      {"account", SECRET_SCHEMA_ATTRIBUTE_STRING},
                  }};
  }

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
    const std::string output = Json::writeString(builder, value);
    std::unique_ptr<GError> err = nullptr;
    GError *errPtr = err.get();

    builder["indentation"] = "";

    bool result = secret_password_storev_sync(
        &the_schema, m_attributes.getGHashTable(), nullptr, label.c_str(),
        output.c_str(), nullptr, &errPtr);

    if (errPtr) {
      throw errPtr->message;
    }

    return result;
  }

  Json::Value readFromKeyring() {
    Json::Value root;
    Json::CharReaderBuilder charBuilder;
    std::unique_ptr<Json::CharReader> reader(charBuilder.newCharReader());
    std::unique_ptr<GError> err = nullptr;
    GError *errPtr = err.get();

    const gchar *result = secret_password_lookupv_sync(
        &the_schema, m_attributes.getGHashTable(), nullptr, &errPtr);

    if (errPtr) {
      throw errPtr->message;
    }

    if (result != nullptr && strcmp(result, "") != 0 &&
        reader->parse(result, result + strlen(result), &root, NULL)) {
      return root;
    }

    this->storeToKeyring(root);
    return root;
  }
};
