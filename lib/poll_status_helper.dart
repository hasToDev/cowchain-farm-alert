import 'dart:io';

import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

import 'other.dart';

class PollStatusHelper {
  PollStatusHelper._();

  /// Poll Soroban Transaction Response until receive success or error
  static Future<(GetTransactionResponse?, FormatException?)> get(
    SorobanServer sorobanServer,
    String transactionId,
  ) async {
    FormatException? error;
    GetTransactionResponse? transactionResponse;
    String status = GetTransactionResponse.STATUS_NOT_FOUND;

    // loop get transaction
    while (status == GetTransactionResponse.STATUS_NOT_FOUND) {
      // get transaction
      transactionResponse = await sorobanServer.getTransaction(transactionId);
      if (transactionResponse.error != null) {
        if (sorobanServer.enableLogging) {
          stdout.writeln('PollStatus get Error: ${transactionResponse.error?.message}');
        }
        error = FormatException(AppMessages.tryAgain);
        break;
      }

      // set status
      if (transactionResponse.status != null) {
        status = transactionResponse.status!;
      }

      // check for null XDR
      bool isFailedAndXdrNull =
          status == GetTransactionResponse.STATUS_FAILED && transactionResponse.resultXdr == null;
      bool isSuccessAndXdrNull =
          status == GetTransactionResponse.STATUS_SUCCESS && transactionResponse.resultXdr == null;
      if (isFailedAndXdrNull || isSuccessAndXdrNull) {
        if (sorobanServer.enableLogging) {
          stdout.writeln('PollStatus get Error: resultXdr is null');
        }
        error = FormatException(AppMessages.tryAgain);
        break;
      }

      // delay
      await Future.delayed(const Duration(seconds: 1));
    }

    if (error != null) return (null, error);
    return (transactionResponse, null);
  }
}
