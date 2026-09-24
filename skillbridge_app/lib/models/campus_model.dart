import 'package:cloud_firestore/cloud_firestore.dart';

/// A campus location. Firestore collection: `campuses`.
class CampusModel {
  final String campusId;
  final String name;
  final String city;

  /// One of [Provinces.all].
  final String province;
  final String address;

  const CampusModel({
    required this.campusId,
    required this.name,
    required this.city,
    required this.province,
    this.address = '',
  });

  factory CampusModel.fromMap(Map<String, dynamic> map, String id) {
    final name = (map['name'] ?? 'Campus').toString();
    return CampusModel(
      campusId: id,
      name: name,
      city: (map['city'] ?? name.replaceAll(' Campus', '')).toString(),
      // Seed data writes region: 'Pakistan'; treat that as unset.
      province: _normaliseProvince(map['province'] ?? map['region']),
      address: (map['address'] ?? '').toString(),
    );
  }

  factory CampusModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      CampusModel.fromMap(doc.data() ?? {}, doc.id);

  static String _normaliseProvince(Object? raw) {
    final value = (raw ?? '').toString().trim();
    if (value.isEmpty || value.toLowerCase() == 'pakistan') return 'Punjab';
    return value;
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'city': city,
        'province': province,
        'address': address,
      };
}
