import 'package:joya_express/data/models/driver_model.dart';

class DriverResponse {
  final bool success;
  final String message;
  final DriverModel conductor;
  final String? estado;
  final String? accessToken;

  DriverResponse({
    required this.success,
    required this.message,
    required this.conductor,
    this.estado,
    this.accessToken,
  });

  factory DriverResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    return DriverResponse(
      success: json['success'] as bool,
      message: data['message'] as String,
      conductor: DriverModel.fromJson(data['conductor']),
      estado: data['estado'],
      accessToken: data['accessToken'],
    );
  }
}

class DriverLoginResponse {
  final bool success;
  final String message;
  final DriverModel conductor;
  final String? accessToken; // Changed to nullable

  DriverLoginResponse({
    required this.success,
    required this.message,
    required this.conductor,
    this.accessToken, // Made optional
  });

  factory DriverLoginResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    return DriverLoginResponse(
      success: json['success'] as bool,
      message: data['message'] as String,
      conductor: DriverModel.fromJson(data['conductor']),
      accessToken:
          data['accessToken'] as String?, // Explicitly cast as nullable String
    );
  }
}
