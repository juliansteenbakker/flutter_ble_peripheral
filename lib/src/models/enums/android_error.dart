enum AndroidError {
  advertiseFailedDataTooLarge,
  advertiseFailedTooManyAdvertisers,
  advertiseFailedAlreadyStarted,
  advertiseFailedInternalError,
  advertiseFailedFeatureUnsupported
}

extension AndroidErrorExtension on AndroidError {
  int get code {
    switch (this) {
      case AndroidError.advertiseFailedDataTooLarge:
        return 1;
      case AndroidError.advertiseFailedTooManyAdvertisers:
        return 2;
      case AndroidError.advertiseFailedAlreadyStarted:
        return 3;
      case AndroidError.advertiseFailedInternalError:
        return 4;
      case AndroidError.advertiseFailedFeatureUnsupported:
        return 5;
    }
  }
}
