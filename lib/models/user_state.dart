import 'package:flutter/material.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:json_annotation/json_annotation.dart';

part 'user_state.g.dart';

@immutable
@JsonSerializable(explicitToJson: true)
class UserState {
  final List<String> mnemonic;
  final String privateKey;
  final String pincode;
  final String accountAddress;
  final String countryCode;
  final String phoneNumber;
  final List<String> syncedContacts;
  final Map<String, String> reverseContacts;
  final String jwtToken;
  final String displayName;
  final String email;
  final bool loginRequestSuccess;
  final bool loginVerifySuccess;
  final bool isLoggedOut;
  final bool isContactsSynced;
  final bool backup;

  @JsonKey(ignore: true)
  final List<Contact> contacts;

  UserState(
      {this.mnemonic,
      this.privateKey,
      this.pincode,
      this.accountAddress,
      this.countryCode,
      this.phoneNumber,
      this.contacts,
      this.reverseContacts,
      this.syncedContacts,
      this.jwtToken,
      this.displayName,
      this.email,
      this.loginRequestSuccess,
      this.loginVerifySuccess,
      this.isLoggedOut,
      this.isContactsSynced,
      this.backup});

  factory UserState.initial() {
    return new UserState(
        mnemonic: [],
        privateKey: "",
        pincode: null,
        accountAddress: "",
        countryCode: "",
        phoneNumber: "",
        contacts: null,
        syncedContacts: [],
        reverseContacts: new Map<String, String>(),
        jwtToken: "",
        displayName: "Anom",
        email: "",
        loginRequestSuccess: false,
        loginVerifySuccess: false,
        isLoggedOut: false,
        isContactsSynced: null,
        backup: false);
  }

  UserState copyWith(
      {List<String> mnemonic,
      String privateKey,
      String pincode,
      String accountAddress,
      String countryCode,
      String phoneNumber,
      List<Contact> contacts,
      List<String> syncedContacts,
      Map<String, String> reverseContacts,
      String jwtToken,
      String displayName,
      String email,
      bool loginRequestSuccess,
      bool loginVerifySuccess,
      bool isLoggedOut,
      bool isContactsSynced,
      bool backup}) {
    return UserState(
        mnemonic: mnemonic ?? this.mnemonic,
        privateKey: privateKey ?? this.privateKey,
        pincode: pincode ?? this.pincode,
        accountAddress: accountAddress ?? this.accountAddress,
        countryCode: countryCode ?? this.countryCode,
        phoneNumber: phoneNumber ?? this.phoneNumber,
        contacts: contacts ?? this.contacts,
        syncedContacts: syncedContacts ?? this.syncedContacts,
        reverseContacts: reverseContacts ?? this.reverseContacts,
        jwtToken: jwtToken ?? this.jwtToken,
        displayName: displayName ?? this.displayName,
        email: email ?? this.email,
        loginRequestSuccess: loginRequestSuccess ?? this.loginRequestSuccess,
        loginVerifySuccess: loginVerifySuccess ?? this.loginVerifySuccess,
        isLoggedOut: isLoggedOut ?? this.isLoggedOut,
        isContactsSynced: isContactsSynced ?? this.isContactsSynced,
        backup: backup ?? this.backup);
  }

  dynamic toJson() => _$UserStateToJson(this);

  static UserState fromJson(dynamic json) {
    return _$UserStateFromJson(json);
  }
}
