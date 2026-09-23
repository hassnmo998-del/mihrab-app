import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_app/data/datasources/local_storage_datasource.dart';
import 'package:flutter_app/data/datasources/offline_sync_queue_manager.dart';
import 'package:flutter_app/data/repositories/mosques_repository_impl.dart';

/// حقول الفرع النسائي يجب أن تُكتب بتحديث جزئي (patch) لا بحفظ الصف كاملاً:
/// جهاز يحمل نسخة قديمة من صف المسجد كان يستطيع عند أي حفظ عادي أن يعيد رمز
/// تسليم مستهلكاً أو يمسح ربط الفرع، فيصبح إنشاء فرع نسائي ثانٍ ممكناً.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStorageDataSource local;
  late OfflineSyncQueueManager queue;
  late MosquesRepositoryImpl repo;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    local = LocalStorageDataSource();
    queue = OfflineSyncQueueManager();
    repo = MosquesRepositoryImpl(local, queue);
  });

  List<Map<String, dynamic>> opsFor(String id) => queue.pendingQueue
      .where((op) => op['id'] == id || (op['data'] as Map)['id'] == id)
      .toList();

  test('creating a mosque is the only whole-row write', () {
    final mosque = repo.addMosque(
        name: 'جامع النور', address: 'الميدان', city: 'دمشق', gender: 'male');

    final ops = opsFor(mosque.id);
    expect(ops, hasLength(1));
    expect(ops.single['action'], 'upsert');
    expect((ops.single['data'] as Map)['access_code'], mosque.accessCode);
  });

  test('issuing a handover token patches the token column only', () {
    final mosque = repo.addMosque(
        name: 'جامع النور', address: 'الميدان', city: 'دمشق', gender: 'male');
    final token = repo.issueWomenProvisionToken(mosque.id)!;

    final patch = opsFor(mosque.id).last;
    expect(patch['action'], 'patch');
    expect(patch['data'], {'women_access_code': token});
  });

  test('profile edits never carry token or branch columns', () {
    final mosque = repo.addMosque(
        name: 'جامع النور', address: 'الميدان', city: 'دمشق', gender: 'male');
    repo.issueWomenProvisionToken(mosque.id);
    repo.updateMosque(
      id: mosque.id,
      name: 'جامع النور الكبير',
      address: 'الميدان',
      city: 'دمشق',
      latitude: 33.5,
      longitude: 36.3,
    );

    final patch = opsFor(mosque.id).last;
    expect(patch['action'], 'patch');
    final data = patch['data'] as Map;
    expect(data['name'], 'جامع النور الكبير');
    expect(data.containsKey('women_access_code'), isFalse);
    expect(data.containsKey('women_branch_id'), isFalse);
    expect(data.containsKey('access_code'), isFalse);
  });

  test('redeeming inserts the branch and patches only the parent link', () {
    final parent = repo.addMosque(
        name: 'جامع النور', address: 'الميدان', city: 'دمشق', gender: 'male');
    final token = repo.issueWomenProvisionToken(parent.id)!;

    final branch = repo.createWomenBranch(
      parentMosqueId: parent.id,
      token: token,
      name: 'القسم النسائي - جامع النور',
      city: 'دمشق',
      address: 'الميدان',
    )!;

    final branchOps = opsFor(branch.id);
    expect(branchOps.single['action'], 'upsert');
    expect((branchOps.single['data'] as Map)['gender'], 'female');
    expect((branchOps.single['data'] as Map)['parent_mosque_id'], parent.id);

    final parentLink = opsFor(parent.id).last;
    expect(parentLink['action'], 'patch');
    expect(parentLink['data'], {
      'women_branch_id': branch.id,
      'women_access_code': null,
    });
  });

  test('handover and branch deletion also use column-scoped patches', () {
    final parent = repo.addMosque(
        name: 'جامع النور', address: 'الميدان', city: 'دمشق', gender: 'male');
    final branch = repo.createWomenBranch(
      parentMosqueId: parent.id,
      token: repo.issueWomenProvisionToken(parent.id)!,
      name: 'القسم النسائي',
      city: 'دمشق',
      address: 'الميدان',
    )!;

    final reissued = repo.issueWomenProvisionToken(parent.id)!;
    final handedOver = repo.consumeProvisionTokenForExistingBranch(
      parentMosqueId: parent.id,
      token: reissued,
    );
    expect(handedOver?.id, branch.id);
    expect(opsFor(parent.id).last['data'], {'women_access_code': null});

    repo.deleteMosque(branch.id);
    final release = opsFor(parent.id).last;
    expect(release['action'], 'patch');
    expect(release['data'], {
      'women_branch_id': null,
      'women_access_code': null,
    });
    expect(repo.getMosqueById(parent.id)!.hasWomenBranch, isFalse);
  });
}
