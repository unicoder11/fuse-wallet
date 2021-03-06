import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:fusecash/models/community.dart';
import 'package:fusecash/models/jobs/base.dart';
import 'package:fusecash/models/transfer.dart';
import 'package:fusecash/redux/actions/cash_wallet_actions.dart';
import 'package:fusecash/redux/actions/error_actions.dart';
import 'package:fusecash/utils/contacts.dart';
import 'package:fusecash/utils/format.dart';
import 'package:interactive_webview/interactive_webview.dart';
import 'package:redux/redux.dart';
import 'package:redux_thunk/redux_thunk.dart';
import 'package:wallet_core/wallet_core.dart';
import 'package:fusecash/services.dart';
import 'package:fusecash/redux/state/store.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:fusecash/utils/phone.dart';

class RestoreWalletSuccess {
  final List<String> mnemonic;
  final String privateKey;
  RestoreWalletSuccess(this.mnemonic, this.privateKey);
}

class CreateLocalAccountSuccess {
  final List<String> mnemonic;
  final String privateKey;
  final String accountAddress;
  CreateLocalAccountSuccess(
      this.mnemonic, this.privateKey, this.accountAddress);
}

class ReLogin {
  ReLogin();
}

class LoginRequestSuccess {
  final String countryCode;
  final String phoneNumber;
  final String displayName;
  final String email;
  LoginRequestSuccess(
      this.countryCode, this.phoneNumber, this.displayName, this.email);
}

class LogoutRequestSuccess {
  LogoutRequestSuccess();
}

class LoginVerifySuccess {
  final String jwtToken;
  LoginVerifySuccess(this.jwtToken);
}

class SyncContactsProgress {
  List<String> contacts;
  List<Map<String, dynamic>> newContacts;
  SyncContactsProgress(this.contacts, this.newContacts);
}

class SyncContactsRejected {
  SyncContactsRejected();
}

class SaveContacts {
  List<Contact> contacts;
  SaveContacts(this.contacts);
}

class SetPincodeSuccess {
  String pincode;
  SetPincodeSuccess(this.pincode);
}

class SetDisplayName {
  String displayName;
  SetDisplayName(this.displayName);
}

class BackupRequest {
  BackupRequest();
}

class BackupSuccess {
  BackupSuccess();
}

ThunkAction backupWalletCall() {
  return (Store store) async {
    if (store.state.userState.backup) return;
    final logger = await AppFactory().getLogger('action');
    String communityAddres = store.state.cashWalletState.communityAddress;
    store.dispatch(BackupRequest());
    dynamic response = await api.backupWallet(communityAddres);
    Community community = store.state.cashWalletState.communities[communityAddres];
    if (community.plugins.backupBonus != null && community.plugins.backupBonus.isActive) {
      BigInt value = toBigInt(community.plugins.joinBonus.amount, community.token.decimals);
      String walletAddress = store.state.cashWalletState.walletAddress;
      dynamic jobId = response['job']['_id'];
      logger.info('Job $jobId - sending backup bonus');
      Transfer backupBonus = new Transfer(
          from: DotEnv().env['FUNDER_ADDRESS'],
          to: walletAddress,
          text: 'You got a backup bonus!',
          type: 'RECEIVE',
          value: value,
          status: 'PENDING',
          jobId: jobId);
      store.dispatch(AddTransaction(backupBonus));

      response['job']['arguments'] = {
        'backupBonus': backupBonus,
      };
      response['job']['jobType'] = 'backup';

      Job job = JobFactory.create(response['job']);
      store.dispatch(AddJob(job));
    }
  };
}

ThunkAction backupSuccessCall(String txHash, transfer) {
  return (Store store) async {
    Transfer confirmedTx = transfer.copyWith(status: 'CONFIRMED', txHash: txHash);
    store.dispatch(new ReplaceTransaction(transfer, confirmedTx));
    store.dispatch(BackupSuccess());
    store.dispatch(segmentTrackCall('Wallet: backup success'));
  };
}

ThunkAction restoreWalletCall(
    List<String> _mnemonic, VoidCallback successCallback) {
  return (Store store) async {
    final logger = await AppFactory().getLogger('action');
    try {
      logger.info('restore wallet');
      String mnemonic = _mnemonic.join(' ');
      logger.info('mnemonic: $mnemonic');
      logger.info('compute pk');
      String privateKey = await compute(Web3.privateKeyFromMnemonic, mnemonic);
      logger.info('privateKey: $privateKey');
      store.dispatch(new RestoreWalletSuccess(_mnemonic, privateKey));
      Credentials c = EthPrivateKey.fromHex(privateKey);
      dynamic accountAddress = await c.extractAddress();
      store.dispatch(new CreateLocalAccountSuccess(
          mnemonic.split(' '), privateKey, accountAddress.toString()));
      store.dispatch(initWeb3Call(privateKey));
      store.dispatch(segmentTrackCall("Wallet: restored mnemonic"));
      successCallback();
    } catch (e) {
      logger.severe('ERROR - restoreWalletCall $e');
      store.dispatch(new ErrorAction('Could not restore wallet'));
    }
  };
}

ThunkAction createLocalAccountCall(VoidCallback successCallback) {
  return (Store store) async {
    final logger = await AppFactory().getLogger('action');
    try {
      logger.info('create new wallet');
      String mnemonic = Web3.generateMnemonic();
      logger.info('mnemonic: $mnemonic');
      logger.info('compute pk');
      String privateKey = await compute(Web3.privateKeyFromMnemonic, mnemonic);
      logger.info('privateKey: $privateKey');
      Credentials c = EthPrivateKey.fromHex(privateKey);
      dynamic accountAddress = await c.extractAddress();
      // api.setJwtToken('');
      store.dispatch(new CreateLocalAccountSuccess(
          mnemonic.split(' '), privateKey, accountAddress.toString()));
      store.dispatch(initWeb3Call(privateKey));
      store.dispatch(segmentTrackCall("Wallet: Create new wallet"));
      successCallback();
    } catch (e) {
      logger.severe('ERROR - createLocalAccountCall $e');
      store.dispatch(new ErrorAction('Could not create new wallet'));
    }
  };
}

ThunkAction loginRequestCall(String countryCode, String phoneNumber,
    VoidCallback successCallback, VoidCallback failCallback) {
  return (Store store) async {
    final logger = await AppFactory().getLogger('action');
    String phone = formatPhoneNumber(phoneNumber, countryCode);
    try {
      bool result = await api.loginRequest(phone);
      if (result) {
        store.dispatch(new LoginRequestSuccess(countryCode, phoneNumber, "", ""));
        successCallback();
        store.dispatch(segmentTrackCall("Wallet: user insert his phone number"));
      } else {
        store.dispatch(new ErrorAction('Could not login'));
        failCallback();
      }
    } catch (e) {
      logger.severe('ERROR - loginRequestCall $e');
      store.dispatch(new ErrorAction('Could not login'));
      failCallback();
    }
  };
}

ThunkAction loginVerifyCall(
    String countryCode,
    String phoneNumber,
    String verificationCode,
    String accountAddress,
    VoidCallback successCallback,
    VoidCallback failCallback) {
  return (Store store) async {
    final logger = await AppFactory().getLogger('action');
    try {
      String phone = formatPhoneNumber(phoneNumber, countryCode);

      String jwtToken = await api.loginVerify(phone, verificationCode, accountAddress);
      store.dispatch(new LoginVerifySuccess(jwtToken));
      store.dispatch(segmentTrackCall("Wallet: verified phone number"));
      successCallback();
    } catch (e) {
      logger.severe('ERROR - loginVerifyCall e');
      store.dispatch(new ErrorAction('Could not verify login'));
      failCallback();
    }
  };
}

ThunkAction logoutCall() {
  return (Store store) async {
    store.dispatch(new LogoutRequestSuccess());
  };
}

ThunkAction reLoginCall() {
  return (Store store) async {
    store.dispatch(new ReLogin());
    store.dispatch(segmentTrackCall("Wallet: Login clicked"));
  };
}

ThunkAction syncContactsCall(List<Contact> contacts) {
  return (Store store) async {
    final logger = await AppFactory().getLogger('action');
    try {
      store.dispatch(new SaveContacts(contacts));
      List<String> syncedContacts = store.state.userState.syncedContacts;
      List<String> newPhones = new List<String>();
      for (Contact contact in contacts) {
        List<String> uniquePhone = contact.phones
            .map((Item phone) => formatPhoneNumber(
                phone.value, store.state.userState.countryCode))
            .toSet()
            .toList();
        for (String phone in uniquePhone) {
          if (!syncedContacts.contains(phone)) {
            newPhones.add(phone);
          }
        }
      }
      if (newPhones.length == 0) {
        dynamic response = await api.syncContacts(newPhones);
        store.dispatch(new SyncContactsProgress(newPhones,
            List<Map<String, dynamic>>.from(response['newContacts'])));
        await api.ackSync(response['nonce']);
      } else {
        int limit = 100;
        List<String> partial = newPhones.take(limit).toList();
        while (partial.length > 0) {
          dynamic response = await api.syncContacts(partial);
          store.dispatch(new SyncContactsProgress(partial,
              List<Map<String, dynamic>>.from(response['newContacts'])));

          await api.ackSync(response['nonce']);
          newPhones = newPhones.sublist(partial.length);
          partial = newPhones.take(limit).toList();
        }
      }
      bool isPermitted = await Contacts.checkPermissions();
      if (isPermitted) {
        store.dispatch(segmentTrackCall("Wallet: Contacts Permission Granted"));
      } else {
        store.dispatch(segmentTrackCall("Wallet: Contacts Permission Rejected"));
      }
    } catch (e) {
      logger.severe('ERROR - syncContactsCall $e');
    }
  };
}

ThunkAction identifyCall() {
  return (Store store) async {
    String fullPhoneNumber = formatPhoneNumber(store.state.userState.phoneNumber, store.state.userState.countryCode);
    store.dispatch(enablePushNotifications());
    store.dispatch(segmentAliasCall(fullPhoneNumber));
    store.dispatch(segmentIdentifyCall(
        fullPhoneNumber,
        new Map<String, dynamic>.from({
          "Phone Number": fullPhoneNumber,
          "Wallet Address": store.state.cashWalletState.walletAddress,
          "Account Address": store.state.userState.accountAddress,
          "Display Name": store.state.userState.displayName
        })));
  };
}

ThunkAction setPincodeCall(String pincode) {
  return (Store store) async {
    final logger = await AppFactory().getLogger('action');
    try {
      store.dispatch(SetPincodeSuccess(pincode));
    } catch (e) {
      logger.severe('ERROR - setPincodeCall $e');
      store.dispatch(new ErrorAction('Could not send token to contact'));
    }
  };
}

ThunkAction setDisplayNameCall(String displayName) {
  return (Store store) async {
    try {
      store.dispatch(new SetDisplayName(displayName));
      store.dispatch(segmentTrackCall("Wallet: display name added"));
    } catch (e) {}
  };
}

ThunkAction create3boxAccountCall(accountAddress) {
  return (Store store) async {
    final logger = await AppFactory().getLogger('action');
    final _webView = new InteractiveWebView();
    String phoneNumber = formatPhoneNumber(store.state.userState.phoneNumber, store.state.userState.countryCode);
    final html = '''<html>
        <head></head>
        <script>
          window.pk = '0x${store.state.userState.privateKey}';
          window.user = { name: '${store.state.userState.displayName}', account: '$accountAddress', phoneNumber: '$phoneNumber'};
        </script>
        <script src='https://3box.fuse.io/main.js'></script>
        <body></body>
      </html>''';
    _webView.loadHTML(html, baseUrl: "https://beta.3box.io");
    store.dispatch(segmentTrackCall("Wallet: Profile created in 3box"));
    try {
      Map publicData = {
        'account': accountAddress,
        'name': store.state.userState.displayName
      };
      await api.createProfile(accountAddress, publicData);
      Map user = {
        "accountAddress": accountAddress,
        "email": 'wallet-user@fuse.io',
        "provider": 'HDWallet',
        "subscribe": false,
        "source": 'wallet-v2'
      };
      await api.saveUserToDb(user);
      logger.info('save user $accountAddress');
    } catch (e) {
      logger.severe('user $accountAddress already saved');
    }
  };
}
