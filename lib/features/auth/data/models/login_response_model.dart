import 'package:json_annotation/json_annotation.dart';
import 'package:shoplite/features/auth/domain/entities/login_entity.dart';

part 'login_response_model.g.dart';

@JsonSerializable()
class LoginResponseModel {
  final int id;
  final String username;
  final String? email;
  final String? firstName;
  final String? lastName;
  final String? gender;
  final String? image;
  final String accessToken;
  final String refreshToken;

  const LoginResponseModel({
    required this.id,
    required this.username,
    this.email,
    this.firstName,
    this.lastName,
    this.gender,
    this.image,
    required this.accessToken,
    required this.refreshToken,
  });

  LoginEntity toEntity() => LoginEntity(
    id: id,
    username: username,
    email: email ?? '',
    firstName: firstName ?? '',
    lastName: lastName ?? '',
    gender: gender ?? '',
    image: image ?? '',
  );

  factory LoginResponseModel.fromJson(Map<String, dynamic> json) =>
      _$LoginResponseModelFromJson(json);
}
