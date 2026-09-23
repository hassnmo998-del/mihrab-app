-- طُبِّقت على مشروع mltxsmonudbtnrloqawf بتاريخ 2026-09-23.
--
-- points_log اسم مستعار قديم لجدول points_logs (التطبيق لا يستخدمه). كان معرّفاً
-- بـ SECURITY DEFINER فيُقيَّم RLS بصلاحيات منشئ المنظر لا المستعلِم، وهذا كان
-- سيتجاوز بصمت أي تشديد مستقبلي لسياسات points_logs. (مستشار Supabase: ERROR)
alter view public.points_log set (security_invoker = true);
