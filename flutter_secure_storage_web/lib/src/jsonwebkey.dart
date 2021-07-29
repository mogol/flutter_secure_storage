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

/// Interface for the [JsonWebKey dictionary][1].
///
/// See also list of [registered parameters][2].
///
/// [1]: https://www.w3.org/TR/WebCryptoAPI/#JsonWebKey-dictionary
/// [2]: https://www.iana.org/assignments/jose/jose.xhtml#web-key-parameters
class JsonWebKey {
  String? kty;
  String? use;
  List<String>? key_ops;
  String? alg;
  bool? ext;
  String? crv;
  String? x;
  String? y;
  String? d;
  String? n;
  String? e;
  String? p;
  String? q;
  String? dp;
  String? dq;
  String? qi;
  List<RsaOtherPrimesInfo>? oth;
  String? k;

  JsonWebKey({
    this.kty,
    this.use,
    this.key_ops,
    this.alg,
    this.ext,
    this.crv,
    this.x,
    this.y,
    this.d,
    this.n,
    this.e,
    this.p,
    this.q,
    this.dp,
    this.dq,
    this.qi,
    this.oth,
    this.k,
  });

  static JsonWebKey fromJson(Map<String, dynamic> json) {
    const stringKeys = [
      'kty',
      'use',
      'alg',
      'crv',
      'x',
      'y',
      'd',
      'n',
      'e',
      'p',
      'q',
      'dp',
      'dq',
      'qi',
      'k',
    ];
    for (final k in stringKeys) {
      if (json.containsKey(k) && json[k] is! String) {
        throw FormatException('JWK entry "$k" must be a string', json);
      }
    }
    List<String>? key_ops;
    if (json.containsKey('key_ops')) {
      if (json['key_ops'] is! List ||
          (json['key_ops'] as List).any((e) => e is! String)) {
        throw FormatException(
            'JWK entry "key_ops" must be a list of strings', json);
      }
      key_ops = (json['key_ops'] as List).map((e) => e as String).toList();
    }

    if (json.containsKey('ext') && json['ext'] is! bool) {
      throw FormatException('JWK entry "ext" must be boolean', json);
    }
    List<RsaOtherPrimesInfo>? oth;
    if (json.containsKey('oth')) {
      if (json['oth'] is! List || (json['oth'] as List).any((e) => e is! Map)) {
        throw FormatException('JWK entry "oth" must be list of maps', json);
      }
      oth = (json['oth'] as List<Map>).map((json) {
        return RsaOtherPrimesInfo.fromJson(json);
      }).toList();
    }
    return JsonWebKey(
      kty: json['kty'] as String?,
      use: json['use'] as String?,
      key_ops: key_ops,
      alg: json['alg'] as String?,
      ext: json['ext'] as bool?,
      crv: json['crv'] as String?,
      x: json['x'] as String?,
      y: json['y'] as String?,
      d: json['d'] as String?,
      n: json['n'] as String?,
      e: json['e'] as String?,
      p: json['p'] as String?,
      q: json['q'] as String?,
      dp: json['dp'] as String?,
      dq: json['dq'] as String?,
      qi: json['qi'] as String?,
      oth: oth,
      k: json['k'] as String?,
    );
  }

  Map<String, Object> toJson() {
    final json = <String, Object>{};

    // Set properties from all the string keys
    final kty_ = kty;
    if (kty_ != null) {
      json['kty'] = kty_;
    }
    final use_ = use;
    if (use_ != null) {
      json['use'] = use_;
    }
    final alg_ = alg;
    if (alg_ != null) {
      json['alg'] = alg_;
    }
    final crv_ = crv;
    if (crv_ != null) {
      json['crv'] = crv_;
    }
    final x_ = x;
    if (x_ != null) {
      json['x'] = x_;
    }
    final y_ = y;
    if (y_ != null) {
      json['y'] = y_;
    }
    final d_ = d;
    if (d_ != null) {
      json['d'] = d_;
    }
    final n_ = n;
    if (n_ != null) {
      json['n'] = n_;
    }
    final e_ = e;
    if (e_ != null) {
      json['e'] = e_;
    }
    final p_ = p;
    if (p_ != null) {
      json['p'] = p_;
    }
    final q_ = q;
    if (q_ != null) {
      json['q'] = q_;
    }
    final dp_ = dp;
    if (dp_ != null) {
      json['dp'] = dp_;
    }
    final dq_ = dq;
    if (dq_ != null) {
      json['dq'] = dq_;
    }
    final qi_ = qi;
    if (qi_ != null) {
      json['qi'] = qi_;
    }
    final k_ = k;
    if (k_ != null) {
      json['k'] = k_;
    }

    // Set non-string properties
    final key_ops_ = key_ops;
    if (key_ops_ != null) {
      json['key_ops'] = key_ops_;
    }
    final ext_ = ext;
    if (ext_ != null) {
      json['ext'] = ext_;
    }
    final oth_ = oth;
    if (oth_ != null) {
      json['oth'] = oth_.map((e) => e.toJson()).toList();
    }

    return json;
  }
}

/// Interface for `RsaOtherPrimesInfo` used in the [JsonWebKey dictionary][1].
///
/// See also "oth" in [RFC 7518 Section 6.3.2.7].
///
/// [1]: https://www.w3.org/TR/WebCryptoAPI/#JsonWebKey-dictionary
/// [2]: https://tools.ietf.org/html/rfc7518#section-6.3.2.7
class RsaOtherPrimesInfo {
  RsaOtherPrimesInfo({
    required this.r,
    required this.d,
    required this.t,
  });

  String r;
  String d;
  String t;

  static RsaOtherPrimesInfo fromJson(Map json) {
    for (final k in ['r', 'd', 't']) {
      if (json[k] is! String) {
        throw FormatException('"oth" entries in a JWK must contain "$k"', json);
      }
    }
    return RsaOtherPrimesInfo(
      r: json['r'] as String,
      d: json['d'] as String,
      t: json['t'] as String,
    );
  }

  Map<String, Object> toJson() {
    return <String, Object>{
      'r': r,
      'd': d,
      't': t,
    };
  }
}
