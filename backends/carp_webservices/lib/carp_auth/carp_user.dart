/*
 * Copyright 2018-2020 Copenhagen Center for Health Technology (CACHET) at the
 * Technical University of Denmark (DTU).
 * Use of this source code is governed by a MIT-style license that can be
 * found in the LICENSE file.
 */

part of carp_auth;

/// Represents a CARP Web Service (CAWS) account and user.
@JsonSerializable(fieldRename: FieldRename.snake, includeIfNull: false)
class CarpUser {
  /// Unique CARP username
  String username;

  /// Unique CARP ID
  int? id;

  /// The CARP account id.
  String? accountId;

  /// Is this user activated in any studies?
  bool? isActivated;

  /// The user's email
  String? email;

  /// User's first name
  String? firstName;

  /// User's last name
  String? lastName;

  /// Mobile phone number
  String? phone;

  /// Department of the the user (e.g. CACHET)
  String? department;

  /// Organization of the the user (e.g. DTU)
  String? organization;

  /// Timestamp for agreeing to the informed consent
  DateTime? termsAgreed;

  /// Timestamp for the creation of this user.
  DateTime? created;

  /// The list of roles that this user has in CARP.
  List<String> role = [];

  /// The OAuth 2.0 [OAuthToken] for this user, once authenticated to CARP.
  /// Is `null` if user is not authenticated.
  OAuthToken? token;

  CarpUser({
    this.username = '',
    this.id,
    this.accountId,
    this.firstName,
    this.lastName,
    this.isActivated = true,
    this.phone,
    this.email,
    this.department,
    this.organization,
  });

  /// Set or update the authenticated [OAuthToken] token for this user.
  void authenticated(OAuthToken token) => this.token = token;

  /// Returns true if the user is logged in; that is, has a valid token.
  bool get isAuthenticated => (token != null);

  /// Returns true if the user's email is verified.
  bool get isEmailVerified => (token != null);


  /// Sign out the current user.
  Future<void> signOut() async {
    token = null;
  }

  factory CarpUser.fromJson(Map<String, dynamic> json) =>
      _$CarpUserFromJson(json);
  Map<String, dynamic> toJson() => _$CarpUserToJson(this);

  @override
  String toString() =>
      'CARP User: $username [$id] - $firstName $lastName [account id: $accountId]';
}
