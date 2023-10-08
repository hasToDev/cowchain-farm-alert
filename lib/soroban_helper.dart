import 'dart:io';

import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

import 'other.dart';
import 'poll_status_helper.dart';

class SorobanHelper {
  SorobanHelper({
    required this.sdk,
    required this.server,
    required this.contractADDRESS,
    required this.contractID,
    required this.adminKeypair,
  });

  final StellarSDK sdk;
  final SorobanServer server;
  final String contractADDRESS;
  final String contractID;
  final KeyPair adminKeypair;

  /// Contract ID
  String getContractID() => StrKey.decodeContractIdHex(contractADDRESS);

  /// [invokeFinalizeAuction]
  /// call finalize_auction function on Cowchain Farm Soroban contract
  Future<bool> invokeFinalizeAuction({
    required String auctionID,
  }) async {
    String function = 'finalize_auction';

    // Retrieve Account Information
    AccountResponse account = await sdk.accounts.account(adminKeypair.accountId);

    // ! The arguments ORDER must be EXACTLY the SAME as the order of Soroban Function Arguments
    List<XdrSCVal> arguments = [
      XdrSCVal.forString(auctionID),
    ];

    // Build Operation
    InvokeContractHostFunction hostFunction = InvokeContractHostFunction(
      getContractID(),
      function,
      arguments: arguments,
    );
    InvokeHostFunctionOperation functionOperation = InvokeHostFuncOpBuilder(hostFunction).build();

    // Submit Transaction
    var (GetTransactionResponse? txResponse, FormatException? error) = await submitTx(
      server: server,
      operation: functionOperation,
      account: account,
      useAuth: true,
      keypair: adminKeypair,
    );
    if (error != null) {
      stdout.writeln('SubmitTX error: ${error.message}');
      return false;
    }

    // Process Response
    txResponse = txResponse as GetTransactionResponse;
    if (server.enableLogging) {
      stdout.writeln('Transaction Response status: ${txResponse.status}');
    }

    if (txResponse.status == GetTransactionResponse.STATUS_SUCCESS) {
      return true;
    }

    return false;
  }

  Future<(GetTransactionResponse?, FormatException?)> submitTx({
    required SorobanServer server,
    required InvokeHostFunctionOperation operation,
    required AccountResponse account,
    required bool useAuth,
    required KeyPair keypair,
  }) async {
    // Build Transaction
    Transaction transaction = TransactionBuilder(account).addOperation(operation).build();

    // Simulate Transaction
    SimulateTransactionResponse simulateResponse = await server.simulateTransaction(transaction);
    if (simulateResponse.resultError?.contains('Error') ?? false) {
      if (server.enableLogging) {
        stdout
            .writeln('simulateResponse Error: ${simulateResponse.jsonResponse['result']['error']}');
      }
      return (null, FormatException(AppMessages.tryAgain));
    }

    // Continue to Sign
    transaction.addResourceFee((simulateResponse.minResourceFee ?? 440000000) * 2);
    transaction.sorobanTransactionData = simulateResponse.transactionData;
    if (useAuth) transaction.setSorobanAuth(simulateResponse.sorobanAuth);

    // Sign Transaction using Keypair
    transaction.sign(keypair, Network.TESTNET);

    // Send Transaction
    SendTransactionResponse sendTransactionResponse = await server.sendTransaction(transaction);

    // Check for errors in Send Transaction response
    var (GetTransactionResponse? _, FormatException? checkError) =
        _sendTransactionResponseCheck(sendTransactionResponse, server.enableLogging);
    if (checkError != null) return (null, checkError);

    // Poll Transaction Response
    return await PollStatusHelper.get(server, sendTransactionResponse.hash!);
  }

  static (GetTransactionResponse?, FormatException?) _sendTransactionResponseCheck(
    SendTransactionResponse sendTransactionResponse,
    bool enableLogging,
  ) {
    // check for error
    if (sendTransactionResponse.error != null) {
      if (enableLogging) {
        stdout.writeln('sendTransactionResponse Error: ${sendTransactionResponse.error?.message}');
      }
      return (null, FormatException(AppMessages.tryAgain));
    }
    // check for hash
    if (sendTransactionResponse.hash == null) {
      if (enableLogging) {
        stdout.writeln('sendTransactionResponse Error: hash is null');
      }
      return (null, FormatException(AppMessages.tryAgain));
    }
    // check for status
    if (sendTransactionResponse.status == SendTransactionResponse.STATUS_ERROR ||
        sendTransactionResponse.status == SendTransactionResponse.STATUS_DUPLICATE ||
        sendTransactionResponse.status == SendTransactionResponse.STATUS_TRY_AGAIN_LATER) {
      if (enableLogging) {
        stdout.writeln(
            'sendTransactionResponse Error:\nStatus: ${sendTransactionResponse.status}\nXDR: ${sendTransactionResponse.errorResultXdr}');
      }
      return (null, FormatException(AppMessages.tryAgain));
    }
    return (null, null);
  }
}
