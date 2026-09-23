part of 'mosque_repository_impl.dart';

/// Mosques, Sheikhs, and Halaqat administration delegation mixin.
mixin MosqueRepoCoreAdministrationMixin
    implements MosquesRepository, SheikhsRepository, HalaqatRepository {
  MosquesRepositoryImpl get mosquesRepository;
  SheikhsRepositoryImpl get sheikhsRepository;
  HalaqatRepositoryImpl get halaqatRepository;

  // Mosques Management
  @override
  List<Mosque> getMosques({String? gender}) =>
      mosquesRepository.getMosques(gender: gender);

  @override
  Mosque? getMosqueById(String id) => mosquesRepository.getMosqueById(id);

  @override
  List<Mosque> getMosquesForViewer(String viewerBranch) =>
      mosquesRepository.getMosquesForViewer(viewerBranch);

  @override
  Mosque addMosque({
    required String name,
    required String address,
    required String city,
    required String gender,
    String? phone,
    double? latitude,
    double? longitude,
    String? parentMosqueId,
  }) =>
      mosquesRepository.addMosque(
        name: name,
        address: address,
        city: city,
        gender: gender,
        phone: phone,
        latitude: latitude,
        longitude: longitude,
        parentMosqueId: parentMosqueId,
      );

  @override
  String? issueWomenProvisionToken(String mosqueId) =>
      mosquesRepository.issueWomenProvisionToken(mosqueId);

  @override
  Mosque? findMosqueByProvisionToken(String token) =>
      mosquesRepository.findMosqueByProvisionToken(token);

  @override
  Mosque? createWomenBranch({
    required String parentMosqueId,
    required String token,
    required String name,
    required String city,
    required String address,
    String? phone,
    double? latitude,
    double? longitude,
  }) =>
      mosquesRepository.createWomenBranch(
        parentMosqueId: parentMosqueId,
        token: token,
        name: name,
        city: city,
        address: address,
        phone: phone,
        latitude: latitude,
        longitude: longitude,
      );

  @override
  Mosque? consumeProvisionTokenForExistingBranch({
    required String parentMosqueId,
    required String token,
  }) =>
      mosquesRepository.consumeProvisionTokenForExistingBranch(
        parentMosqueId: parentMosqueId,
        token: token,
      );

  @override
  void updateMosque({
    required String id,
    required String name,
    required String address,
    required String city,
    String? phone,
    double? latitude,
    double? longitude,
  }) =>
      mosquesRepository.updateMosque(
        id: id,
        name: name,
        address: address,
        city: city,
        phone: phone,
        latitude: latitude,
        longitude: longitude,
      );

  @override
  void deleteMosque(String mosqueId) =>
      mosquesRepository.deleteMosque(mosqueId);

  // Sheikhs Management
  @override
  List<Sheikh> getSheikhs({String? mosqueId, String? gender}) =>
      sheikhsRepository.getSheikhs(mosqueId: mosqueId, gender: gender);

  @override
  Sheikh addSheikh(
      String mosqueId,
      String fullName,
      String? phone, {
        String? profileImageUrl,
      }) =>
      sheikhsRepository.addSheikh(
        mosqueId,
        fullName,
        phone,
        profileImageUrl: profileImageUrl,
      );

  @override
  void updateSheikh({
    required String sheikhId,
    required String fullName,
    String? phone,
    String? profileImageUrl,
    int? defaultAttendancePoints,
  }) =>
      sheikhsRepository.updateSheikh(
        sheikhId: sheikhId,
        fullName: fullName,
        phone: phone,
        profileImageUrl: profileImageUrl,
        defaultAttendancePoints: defaultAttendancePoints,
      );

  @override
  void deleteSheikh(String sheikhId) =>
      sheikhsRepository.deleteSheikh(sheikhId);

  // Halaqat Management
  @override
  List<Halaqa> getHalaqat({String? mosqueId, String? sheikhId}) =>
      halaqatRepository.getHalaqat(mosqueId: mosqueId, sheikhId: sheikhId);

  @override
  Halaqa? getHalaqaById(String id) => halaqatRepository.getHalaqaById(id);

  @override
  Halaqa addHalaqa({
    required String mosqueId,
    String? sheikhId,
    List<String> coSheikhIds = const [],
    required String name,
    String? description,
    int ageGroupMin = 6,
    int ageGroupMax = 18,
    String schedule = 'السبت - الإثنين - الأربعاء (عصراً)',
    List<int> daysOfWeek = const [6, 1, 3],
    String timingType = 'prayer_linked',
    String? prayerName = 'asr',
    String prayerRelation = 'after',
    String? customTime,
  }) =>
      halaqatRepository.addHalaqa(
        mosqueId: mosqueId,
        sheikhId: sheikhId,
        coSheikhIds: coSheikhIds,
        name: name,
        description: description,
        ageGroupMin: ageGroupMin,
        ageGroupMax: ageGroupMax,
        schedule: schedule,
        daysOfWeek: daysOfWeek,
        timingType: timingType,
        prayerName: prayerName,
        prayerRelation: prayerRelation,
        customTime: customTime,
      );

  @override
  void updateHalaqa({
    required String id,
    required String name,
    String? description,
    String? sheikhId,
    List<String>? coSheikhIds,
    int? ageGroupMin,
    int? ageGroupMax,
    String? schedule,
    List<int>? daysOfWeek,
    String? timingType,
    String? prayerName,
    String? prayerRelation,
    String? customTime,
  }) =>
      halaqatRepository.updateHalaqa(
        id: id,
        name: name,
        description: description,
        sheikhId: sheikhId,
        coSheikhIds: coSheikhIds,
        ageGroupMin: ageGroupMin,
        ageGroupMax: ageGroupMax,
        schedule: schedule,
        daysOfWeek: daysOfWeek,
        timingType: timingType,
        prayerName: prayerName,
        prayerRelation: prayerRelation,
        customTime: customTime,
      );

  @override
  void deleteHalaqa(String halaqaId) =>
      halaqatRepository.deleteHalaqa(halaqaId);
}
