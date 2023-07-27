import 'characteristic_description.dart';

class ServiceDescription {
  final String uuid;
  final List<CharacteristicDescription> characteristics;

  ServiceDescription({
    required String uuid,
    List<CharacteristicDescription>? characteristics,
  }) :
    uuid = uuid.toLowerCase(),
    characteristics = characteristics ?? []
  ;

  Map<String,dynamic> toMap() {
    return {
      "uuid": uuid,
      "characteristics": characteristics.map((c) => c.toMap()).toList()
    };
  }
}
