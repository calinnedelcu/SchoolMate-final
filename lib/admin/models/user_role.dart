enum UserRole {
  student,
  teacher,
  parent,
  admin,
  gate;

  static UserRole? fromWire(String? value) {
    if (value == null) return null;
    final v = value.trim().toLowerCase();
    for (final r in UserRole.values) {
      if (r.name == v) return r;
    }
    return null;
  }

  String get wire => name;

  bool get requiresClassId => this == UserRole.student || this == UserRole.teacher;
}
