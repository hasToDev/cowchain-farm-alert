import 'dart:io';

enum CowchainFunction {
  buyCow,
  sellCow,
  cowAppraisal,
  feedTheCow,
  getAllCow,
  registerAuction,
  bidding,
  finalizeAuction,
  getAllAuction,
}

enum Status {
  ok,
  fail,
  alreadyInitialized,
  notInitialized,
  tryAgain,
  notFound,
  found,
  saved,
  bumped,
  upgraded,
  duplicate,
  insufficientFund,
  underage,
  missingOwnership,
  fullStomach,
  onAuction,
  bidIsClosed,
  bidIsOpen,
  cannotBidLower,
  nameAlreadyExist,
}

class AppMessages {
  AppMessages._();

  static String allowFreighterShareData = 'Cowchain Farm needs to access Freighter.';
  static String allowFreighterSignTx = 'Allow Freighter to sign the transaction.';
  static String connectFreighter = 'Make sure the Freighter extension is installed and enabled.';
  static String contractNotInitialized = 'Cowchain Farm contract not initialized.';
  static String cowNotFound = 'Your cow has died.';
  static String cowStillFull = 'Your cow is still full.';
  static String cowOnAuction = 'Unable to sell. Your cow is being auctioned.';
  static String insufficientFund = 'You don\'t have enough fund to buy the cow.';
  static String insufficientMarketFund =
      'The market doesn\'t have enough liquidity. Try again later.';
  static String mustWebPlatform = 'Platform is not Web. Cannot continue.';
  static String notFound = 'Not found.';
  static String noResult = 'No result. Please try again.';
  static String publicKeyNotFound = 'Public Key not found.';
  static String pleaseWait = 'please wait';
  static String processFails = 'Process fails. Please try again.';
  static String provideSecretKey = 'Please provide Secret Key to sign the transaction.';
  static String timeoutFreighter = 'Freighter timeout. Please try again.';
  static String tryAgain = 'Something went wrong. Please try again.';
  static String tryAgainPreflight = 'Preflight is empty. Please try again.';
  static String underageCow = 'Your cow is still under 3 days of age.';
  static String publicKeyEmpty = 'Please provide Public Key to register.';
  static String publicKeyInvalid = 'Public Key invalid. Please try again.';
  static String oneSignalIdNotAvailable = 'Please try again in a moment or restart the app.';
  static String unableToBid = 'Bidding is already closed.';
  static String unableToFinalize = 'Unable to finalize. Bidding is still open.';
  static String mustBidHigher = 'You must bid higher price.';
  static String nameExist = 'Name already exists. Please choose another name.';
  static String biddingPrice = 'Please enter your bid price.';
  static String auctionStartPrice = 'Please enter your auction start price.';
  static String zeroPrice = 'The price cannot be zero.';
}

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}
