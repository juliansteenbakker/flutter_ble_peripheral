import 'characteristic_description.dart';

class ServiceDescription {
  final String uuid;
  final List<CharacteristicDescription> characteristics;

  ServiceDescription({
    required this.uuid,
    List<CharacteristicDescription>? characteristics,
  }) : characteristics = characteristics ?? [];

  Map<String,dynamic> toMap() {
    return {
      "uuid": uuid,
      "characteristics": characteristics.map((c) => c.toMap()).toList()
    };
  }
}
