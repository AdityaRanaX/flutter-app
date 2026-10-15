class SchoolModel {
  final String schoolId;
  final String schoolName;
  final String location;
  final String? address;
  final String? contactNumber;
  final String? email;

  const SchoolModel({
    required this.schoolId,
    required this.schoolName,
    required this.location,
    this.address,
    this.contactNumber,
    this.email,
  });

  Map<String, dynamic> toMap() {
    return {
      'schoolId': schoolId,
      'schoolName': schoolName,
      'location': location,
      'address': address,
      'contactNumber': contactNumber,
      'email': email,
    };
  }

  factory SchoolModel.fromMap(Map<String, dynamic> map) {
    return SchoolModel(
      schoolId: map['schoolId'] as String? ?? '',
      schoolName: map['schoolName'] as String? ?? '',
      location: map['location'] as String? ?? '',
      address: map['address'] as String?,
      contactNumber: map['contactNumber'] as String?,
      email: map['email'] as String?,
    );
  }

  SchoolModel copyWith({
    String? schoolId,
    String? schoolName,
    String? location,
    String? address,
    String? contactNumber,
    String? email,
  }) {
    return SchoolModel(
      schoolId: schoolId ?? this.schoolId,
      schoolName: schoolName ?? this.schoolName,
      location: location ?? this.location,
      address: address ?? this.address,
      contactNumber: contactNumber ?? this.contactNumber,
      email: email ?? this.email,
    );
  }
}
