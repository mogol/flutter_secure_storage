// Copyright 2020 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

/// This library attempts to expose the definitions necessary to use the
/// browsers `window.crypto.subtle` APIs.
@JS()
library common;

import 'dart:convert' show jsonDecode;
import 'dart:html';
import 'dart:typed_data';

import 'package:js/js.dart';
import 'dart:js_util' as js_util;

import 'jsonwebkey.dart' show JsonWebKey;

export 'jsonwebkey.dart' show JsonWebKey;

/// Minimal interface for promises as returned from the browsers WebCrypto API.

/// Convert a promise to a future.
@JS()
class Promise<T> {
  external Promise(void executor(void resolve(T result), Function reject));
  external Promise then(void onFulfilled(T result), [Function onRejected]);
}

/// Convert [BigInt] to [Uint8List] formatted as [BigInteger][1] following
/// the Web Cryptography specification.
///
/// [1]: https://www.w3.org/TR/WebCryptoAPI/#big-integer
Uint8List bigIntToUint8ListBigInteger(BigInt integer) {
  if (integer == BigInt.from(65537)) {
    return Uint8List.fromList([0x01, 0x00, 0x01]); // 65537
  }
  if (integer == BigInt.from(3)) {
    return Uint8List.fromList([0x03]); // 3
  }
  // TODO: Implement bigIntToUint8ListBigInteger for all positive integers
  // There is no rush as this is only used for public exponent, and chrome only
  // supports 3 and 65537, so supporting other numbers is a low priority.
  // https://chromium.googlesource.com/chromium/src/+/43d62c50b705f88c67b14539e91fd8fd017f70c4/components/webcrypto/algorithms/rsa.cc#286
  throw UnimplementedError('Only supports 65537 and 3 for now');
}

/// Interface for the [CryptoKeyPair][1].
///
/// [1]: https://www.w3.org/TR/WebCryptoAPI/#keypair
@JS()
@anonymous
class CryptoKeyPair {
  external CryptoKey get privateKey;
  external CryptoKey get publicKey;
}

/// Anonymous object to be used for constructing the `algorithm` parameter in
/// `subtle.crypto` methods.
///
/// Note this only works because [WebIDL specification][1] for converting
/// dictionaries say to ignore properties whose values are `null` or
/// `undefined`. Otherwise, this object would define a lot of properties that
/// are not permitted. If two parameters for any algorithms in the Web
/// Cryptography specification has conflicting types in the future, we might
/// have to split this into multiple types. But so long as they don't have
/// conflicting parameters there is no reason to make a type per algorithm.
///
/// [1]: https://www.w3.org/TR/WebIDL-1/#es-dictionary
@JS()
@anonymous
class Algorithm {
  external String get name;
  external int get modulusLength;
  external Uint8List get publicExponent;
  external String get hash;
  external int get saltLength;
  external TypedData get label;
  external String get namedCurve;
  external CryptoKey get public;
  external TypedData get counter;
  external int get length;
  external TypedData get iv;
  external TypedData get additionalData;
  external int get tagLength;
  external TypedData get salt;
  external TypedData get info;
  external int get iterations;

  external factory Algorithm({
    String name,
    int modulusLength,
    Uint8List publicExponent,
    String hash,
    int saltLength,
    TypedData label,
    String namedCurve,
    CryptoKey public,
    TypedData counter,
    int length,
    TypedData iv,
    TypedData additionalData,
    int tagLength,
    TypedData salt,
    TypedData info,
    int iterations,
  });
}

JsonWebKey jsonWebKeyFromJs(dynamic obj) {
  final json = jsonDecode(_stringify(obj));
  try {
    return JsonWebKey.fromJson(json);
  } on FormatException catch (e) {
    throw UnsupportedError(
      'exported JsonWebKey is not valid, this could be internal error or '
      'lacking browser support -- problem: ${e.message}',
    );
  }
}

dynamic jsonWebKeytoJs(JsonWebKey k) => js_util.jsify(k.toJson());

@JS('crypto.getRandomValues')
external Promise<ByteBuffer> getRandomValues(TypedData array);

@JS('crypto.subtle.decrypt')
external Promise<ByteBuffer> decrypt(
  Algorithm algorithm,
  CryptoKey key,
  TypedData data,
);

@JS('crypto.subtle.encrypt')
external Promise<ByteBuffer> encrypt(
  Algorithm algorithm,
  CryptoKey key,
  TypedData data,
);

@JS('crypto.subtle.exportKey')
external Promise<ByteBuffer> exportKey(
  String format,
  CryptoKey key,
);

@JS('crypto.subtle.exportKey')
external Promise<dynamic> exportJsonWebKey(
  String format,
  CryptoKey key,
);

@JS('crypto.subtle.generateKey')
external Promise<CryptoKey> generateKey(
  Algorithm algorithm,
  bool extractable,
  List<String> usages,
);

@JS('crypto.subtle.generateKey')
external Promise<CryptoKeyPair> generateKeyPair(
  Algorithm algorithm,
  bool extractable,
  List<String> usages,
);

@JS('crypto.subtle.digest')
external Promise<ByteBuffer> digest(String algorithm, TypedData data);

@JS('crypto.subtle.importKey')
external Promise<CryptoKey> importKey(
  String format,
  TypedData keyData,
  Algorithm algorithm,
  bool extractable,
  List<String> usages,
);

@JS('crypto.subtle.importKey')
external Promise<CryptoKey> importJsonWebKey(
  String format,
  dynamic jwk,
  Algorithm algorithm,
  bool extractable,
  List<String> usages,
);

@JS('crypto.subtle.sign')
external Promise<ByteBuffer> sign(
  Algorithm algorithm,
  CryptoKey key,
  TypedData data,
);

@JS('crypto.subtle.verify')
external Promise<bool> verify(
  Algorithm algorithm,
  CryptoKey key,
  TypedData signature,
  TypedData data,
);

@JS('crypto.subtle.deriveBits')
external Promise<ByteBuffer> deriveBits(
  Algorithm algorithm,
  CryptoKey key,
  int length,
);

@JS('JSON.stringify')
external String _stringify(dynamic object);
