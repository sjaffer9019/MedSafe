class UserModel {
  final int? id;
  final String name;
  final String email;
  final String phone;
  final String? avatarPath;

  UserModel({
    this.id,
    required this.name,
    required this.email,
    required this.phone,
    this.avatarPath,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'email': email,
    'phone': phone,
    'avatarPath': avatarPath,
  };

  factory UserModel.fromMap(Map<String, dynamic> map) => UserModel(
    id: map['id'],
    name: map['name'],
    email: map['email'],
    phone: map['phone'],
    avatarPath: map['avatarPath'],
  );

  UserModel copyWith({String? name, String? email, String? phone, String? avatarPath}) => UserModel(
    id: id,
    name: name ?? this.name,
    email: email ?? this.email,
    phone: phone ?? this.phone,
    avatarPath: avatarPath ?? this.avatarPath,
  );
}
