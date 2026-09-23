import '../../models/models.dart';

/// Contract for Sheikhs management.
abstract class SheikhsRepository {
  List<Sheikh> getSheikhs({String? mosqueId, String? gender});

  Sheikh addSheikh(
      String mosqueId,
      String fullName,
      String? phone, {
        String? profileImageUrl,
      });

  void updateSheikh({
    required String sheikhId,
    required String fullName,
    String? phone,
    String? profileImageUrl,
    int? defaultAttendancePoints,
  });

  void deleteSheikh(String sheikhId);
}