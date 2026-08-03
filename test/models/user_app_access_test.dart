import 'package:flutter_test/flutter_test.dart';
import 'package:istakip_app/models/user_app_access.dart';

void main() {
  test('uygulama rol kodlari benzersiz ve beklenen rolleri icerir', () {
    final workCodes =
        UserAccessCatalog.isTakipRoles.map((role) => role.code).toList();
    final quoteCodes =
        UserAccessCatalog.teklifRoles.map((role) => role.code).toList();

    expect(workCodes.toSet().length, workCodes.length);
    expect(quoteCodes.toSet().length, quoteCodes.length);
    expect(workCodes, containsAll(['admin', 'manager', 'technician']));
    expect(quoteCodes, containsAll(['admin', 'manager', 'sales', 'viewer']));
  });

  test('bilinmeyen rol en kisitli role geri doner', () {
    expect(
      UserAccessCatalog.roleFor('is_takip', 'unknown').code,
      'partner_user',
    );
    expect(UserAccessCatalog.roleFor('teklif', 'unknown').code, 'viewer');
  });

  test('uygulama erisim kaydi Supabase satirindan okunur', () {
    final access = UserAppAccess.fromJson({
      'user_id': 'user-1',
      'app_code': 'teklif',
      'app_role': 'sales',
      'is_active': true,
      'updated_at': '2026-08-03T10:00:00Z',
    });

    expect(access.userId, 'user-1');
    expect(access.appCode, 'teklif');
    expect(access.appRole, 'sales');
    expect(access.isActive, isTrue);
    expect(access.updatedAt, isNotNull);
  });
}
