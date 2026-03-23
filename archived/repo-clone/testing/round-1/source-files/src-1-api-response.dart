import 'package:json_annotation/json_annotation.dart';

part 'api_response.g.dart';

@JsonSerializable()
class ApiResponse {
  final String status;
  final String? message;
  final Map<String, dynamic>? data;

  const ApiResponse({
    required this.status,
    this.message,
    this.data,
  });

  factory ApiResponse.fromJson(Map<String, dynamic> json) =>
      _$ApiResponseFromJson(json);

  Map<String, dynamic> toJson() => _$ApiResponseToJson(this);
}

@JsonSerializable()
class HealthCheckResponse {
  final String status;
  final Map<String, dynamic> services;

  const HealthCheckResponse({
    required this.status,
    required this.services,
  });

  factory HealthCheckResponse.fromJson(Map<String, dynamic> json) =>
      _$HealthCheckResponseFromJson(json);

  Map<String, dynamic> toJson() => _$HealthCheckResponseToJson(this);
}