import '../../services/points_ledger.dart';
import 'points_writer.dart';
import '../../core/utils/access_code_generator.dart';
import '../../domain/repositories/rewards_repository.dart';
import '../../models/models.dart';
import '../datasources/local_storage_datasource.dart';
import '../datasources/offline_sync_queue_manager.dart';
import '../datasources/supabase_remote_datasource.dart';

/// Concrete implementation of [RewardsRepository] managing reward catalog,
/// voucher creation (`VCH-XXXX`), cashier dispensation, and points deduction.
class RewardsRepositoryImpl implements RewardsRepository {
  final LocalStorageDataSource _localDataSource;
  final OfflineSyncQueueManager _syncQueueManager;
  final SupabaseRemoteDataSource? _remoteDataSource;

  PointsWriter get _points => PointsWriter(_localDataSource, _syncQueueManager, _remoteDataSource);

  RewardsRepositoryImpl(
    this._localDataSource,
    this._syncQueueManager, {
    SupabaseRemoteDataSource? remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  @override
  List<Reward> getRewards({String? mosqueId}) {
    var list = _localDataSource.rewards;
    if (mosqueId != null && mosqueId.isNotEmpty && mosqueId != 'all') {
      list = list
          .where((r) => r.mosqueId.isEmpty || r.mosqueId == mosqueId)
          .toList();
    }
    return List.unmodifiable(list);
  }

  @override
  Reward addReward({
    required String mosqueId,
    required String title,
    String? description,
    required int pointsCost,
    bool isActive = true,
  }) {
    final reward = Reward(
      id: AccessCodeGenerator.entityId('rew'),
      mosqueId: mosqueId,
      title: title.trim(),
      description: description?.trim(),
      pointsCost: pointsCost,
      isActive: isActive,
      createdAt: DateTime.now(),
    );

    _localDataSource.rewards.insert(0, reward);
    _localDataSource.saveToStorage();
    _syncQueueManager.queueSync(
      table: 'rewards',
      action: 'upsert',
      data: reward.toJson(),
      remoteDataSource: _remoteDataSource,
    );

    return reward;
  }

  @override
  void updateReward(Reward reward) {
    final idx =
        _localDataSource.rewards.indexWhere((r) => r.id == reward.id);
    if (idx != -1) {
      _localDataSource.rewards[idx] = reward;
      _localDataSource.saveToStorage();
      _syncQueueManager.queueSync(
        table: 'rewards',
        action: 'upsert',
        data: reward.toJson(),
        remoteDataSource: _remoteDataSource,
      );
    }
  }

  @override
  void deleteReward(String rewardId) {
    _localDataSource.rewards.removeWhere((r) => r.id == rewardId);
    _localDataSource.saveToStorage();
    _syncQueueManager.queueSync(
      table: 'rewards',
      action: 'delete',
      data: {},
      id: rewardId,
      remoteDataSource: _remoteDataSource,
    );
  }

  @override
  List<RewardRedemption> getRedemptions(
      {String? mosqueId, String? studentId, String? status}) {
    var list = _localDataSource.redemptions;
    if (mosqueId != null && mosqueId.isNotEmpty) {
      list = list.where((r) => r.mosqueId == mosqueId).toList();
    }
    if (studentId != null && studentId.isNotEmpty) {
      list = list.where((r) => r.studentId == studentId).toList();
    }
    if (status != null && status.isNotEmpty) {
      list = list.where((r) => r.status == status).toList();
    }
    return List.unmodifiable(list);
  }

  /// كود قسيمة `VCH-XXXX` غير مستعمل في قسيمة أخرى على هذا الجهاز.
  String _freshVoucherCode() {
    final taken = _localDataSource.redemptions.map((r) => r.redemptionCode).toSet();
    final seed = DateTime.now().millisecondsSinceEpoch % 9000;
    for (var i = 0; i < 9000; i++) {
      final code = 'VCH-${(seed + i) % 9000 + 1000}';
      if (!taken.contains(code)) return code;
    }
    return 'VCH-${DateTime.now().microsecondsSinceEpoch}';
  }

  @override
  RewardRedemption? claimReward({
    required String studentId,
    required String rewardId,
  }) {
    final student = _localDataSource.students.firstWhere(
      (s) => s.id == studentId,
      orElse: () => Student(
          id: '',
          mosqueId: '',
          halaqaId: '',
          fullName: '',
          gender: 'male',
          phone: '',
          code: ''),
    );
    final reward = _localDataSource.rewards.firstWhere(
      (r) => r.id == rewardId,
      orElse: () => Reward(
          id: '',
          mosqueId: '',
          title: '',
          pointsCost: 0,
          createdAt: DateTime.now()),
    );

    if (student.id.isEmpty || reward.id.isEmpty) return null;
    if (student.totalPoints < reward.pointsCost) return null;

    final mosque = _localDataSource.mosques.firstWhere(
      (m) => m.id == student.mosqueId,
      orElse: () => Mosque(
          id: '',
          name: 'مسجدنا',
          city: '',
          gender: 'male',
          accessCode: ''),
    );

    // طلب كمية من الجائزة ينشئ قسائمها في اللحظة نفسها: لكل قسيمة معرّف وكود لا يتكرران،
    // وإلا طابقت إحداها الأخرى في السحابة وضاعت.
    final redemption = RewardRedemption(
      id: AccessCodeGenerator.entityId('rdm'),
      studentId: student.id,
      studentName: student.fullName,
      mosqueId: mosque.id,
      mosqueName: mosque.name,
      rewardId: reward.id,
      rewardTitle: reward.title,
      pointsSpent: reward.pointsCost,
      redemptionCode: _freshVoucherCode(),
      status: 'pending',
      redeemedAt: DateTime.now(),
    );

    _localDataSource.redemptions.insert(0, redemption);
    _localDataSource.saveToStorage();
    _syncQueueManager.queueSync(
      table: 'reward_redemptions',
      action: 'upsert',
      data: redemption.toJson(),
      remoteDataSource: _remoteDataSource,
    );

    return redemption;
  }

  @override
  Map<String, dynamic> sellReward({
    required String studentId,
    required String rewardId,
    required String cashierName,
  }) {
    final studentIdx =
        _localDataSource.students.indexWhere((s) => s.id == studentId);
    if (studentIdx == -1) {
      return {'success': false, 'message': 'بيانات الطالب غير موجودة'};
    }
    final student = _localDataSource.students[studentIdx];

    final rewardIdx =
        _localDataSource.rewards.indexWhere((r) => r.id == rewardId);
    if (rewardIdx == -1) {
      return {'success': false, 'message': 'بيانات الجائزة غير موجودة'};
    }
    final reward = _localDataSource.rewards[rewardIdx];

    if (student.totalPoints < reward.pointsCost) {
      return {
        'success': false,
        'message':
            'رصيد نقاط الطالب غير كافٍ (المطلوب: ${reward.pointsCost}، المتوفر: ${student.totalPoints})'
      };
    }

    // 1. Create Redemption Record (Directly as dispensed)
    final redemption = RewardRedemption(
      id: AccessCodeGenerator.entityId('rdm'),
      studentId: student.id,
      studentName: student.fullName,
      mosqueId: student.mosqueId,
      mosqueName: _localDataSource.mosques
          .firstWhere((m) => m.id == student.mosqueId,
              orElse: () => Mosque(
                  id: '',
                  name: 'المسجد',
                  city: '',
                  gender: 'male',
                  accessCode: ''))
          .name,
      rewardId: reward.id,
      rewardTitle: reward.title,
      pointsSpent: reward.pointsCost,
      redemptionCode: 'DIRECT-${DateTime.now().millisecondsSinceEpoch}',
      status: 'dispensed',
      redeemedAt: DateTime.now(),
      dispensedAt: DateTime.now(),
      cashierName: cashierName,
    );

    // 2. Deduct the points (ledger entry + balance) and save
    _localDataSource.redemptions.insert(0, redemption);
    _points.apply(
      studentId: student.id,
      points: -reward.pointsCost,
      reason: 'استلام جائزة (صرف مباشر): ${reward.title}',
      category: PointsLedger.rewardCategory,
    );
    _localDataSource.saveToStorage();

    _syncQueueManager.queueSync(
      table: 'reward_redemptions',
      action: 'upsert',
      data: redemption.toJson(),
      remoteDataSource: _remoteDataSource,
    );

    return {
      'success': true,
      'redemption': redemption,
      'student': student,
      'pointsDeducted': reward.pointsCost,
      'remainingPoints': student.totalPoints,
    };
  }

  @override
  Map<String, dynamic> dispenseReward({
    required String voucherCode,
    required String cashierName,
  }) {
    final cleanCode = voucherCode.trim().toUpperCase();
    final redIdx = _localDataSource.redemptions
        .indexWhere((r) => r.redemptionCode.toUpperCase() == cleanCode);
    if (redIdx == -1) {
      return {'success': false, 'message': 'رمز القسيمة غير صحيح أو غير موجود'};
    }

    final red = _localDataSource.redemptions[redIdx];
    if (red.status == 'dispensed') {
      return {
        'success': false,
        'message':
            'تم صرف هذه الجائزة مسبقاً في ${red.dispensedAt?.toString().substring(0, 16) ?? ""}'
      };
    }

    final studentIdx =
        _localDataSource.students.indexWhere((s) => s.id == red.studentId);
    if (studentIdx == -1) {
      return {'success': false, 'message': 'بيانات الطالب غير موجودة'};
    }

    final student = _localDataSource.students[studentIdx];
    if (student.totalPoints < red.pointsSpent) {
      return {
        'success': false,
        'message':
            'رصيد نقاط الطالب غير كافٍ للصرف (المطلوب: ${red.pointsSpent}، المتوفر: ${student.totalPoints})'
      };
    }

    // خصم النقاط: الحركة تحمل معرّف القسيمة، فصرف القسيمة نفسها من جهازين (صرّافان
    // لم يتزامنا بعد) حركة واحدة لا خصمان.
    _points.apply(
      studentId: student.id,
      points: -red.pointsSpent,
      reason: 'استلام جائزة: ${red.rewardTitle}',
      category: PointsLedger.rewardCategory,
      logId: 'pts-rdm-${red.id}',
    );

    // Update redemption status
    red.status = 'dispensed';
    red.dispensedAt = DateTime.now();
    red.cashierName = cashierName;

    _localDataSource.saveToStorage();
    _syncQueueManager.queueSync(
      table: 'reward_redemptions',
      action: 'upsert',
      data: red.toJson(),
      remoteDataSource: _remoteDataSource,
    );

    return {
      'success': true,
      'redemption': red,
      'student': student,
      'pointsDeducted': red.pointsSpent,
      'remainingPoints': student.totalPoints,
    };
  }
}
