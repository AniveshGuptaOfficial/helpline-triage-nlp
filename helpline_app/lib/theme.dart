import 'package:flutter/material.dart';

const Color kPrimary = Color(0xFF0F6B66); // deep teal
const Color kPrimaryLight = Color(0xFFE6F2F1);
const Color kBackground = Color(0xFFFAFAF8);
const Color kEmergency = Color(0xFFD64545);
const Color kMedicine = Color(0xFFC98A2C);
const Color kAppointment = Color(0xFF0F6B66);
const Color kNeutral = Color(0xFF8A8A8A);

Color categoryColor(String? category) {
  switch (category) {
    case 'Emergency':
      return kEmergency;
    case 'Medicine Query':
      return kMedicine;
    case 'Appointment':
      return kAppointment;
    default:
      return kNeutral;
  }
}

IconData categoryIcon(String? category) {
  switch (category) {
    case 'Emergency':
      return Icons.emergency_rounded;
    case 'Medicine Query':
      return Icons.medical_information_rounded;
    case 'Appointment':
      return Icons.event_available_rounded;
    default:
      return Icons.help_outline_rounded;
  }
}
