enum UserRole {
  admin,
  user,
}

extension UserRoleExtension on UserRole {
  String get name {
    switch (this) {
      case UserRole.admin:
        return 'Admin';
      case UserRole.user:
        return 'User';
    }
  }

  String get description {
    switch (this) {
      case UserRole.admin:
        return 'Full access to queue management';
      case UserRole.user:
        return 'Can join the waiting queue';
    }
  }
}