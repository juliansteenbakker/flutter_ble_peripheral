
/// Model of the data to be advertised.
class PeriodicAdvertiseSettings {

  final int? interval;

  final bool? includeTxPowerLevel;

  PeriodicAdvertiseSettings({
    this.interval = 100,
    this.includeTxPowerLevel = false
  });
}
