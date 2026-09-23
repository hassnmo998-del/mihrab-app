import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// تسعيرة الجوائز بالمال، محفوظة محلياً على جهاز الصراف.
///
/// النقاط محفوظة في قاعدة البيانات، أما ثمن الجائزة الحقيقي (كم دفع الصراف
/// ثمن العصير أو الدفتر) فهو اتفاق بين الصراف وإدارة الجامع، لذلك يُحفظ محلياً
/// لكل جامع على حدة ويُستخدم فقط لحساب المبلغ المستحق في الكشف.
class RewardPriceStore {
  RewardPriceStore._();

  static const String _pricesKey = 'cashier_reward_prices_v1';
  static const String _currencyKey = 'cashier_currency_label_v1';
  static const String defaultCurrency = 'ل.س';

  /// أسعار جوائز جامع واحد: معرّف الجائزة -> ثمن الوحدة.
  static Future<Map<String, double>> loadPrices(String mosqueId) async {
    if (mosqueId.isEmpty) return {};
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_pricesKey);
      if (raw == null || raw.isEmpty) return {};
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      final forMosque = decoded[mosqueId];
      if (forMosque is! Map) return {};
      return {
        for (final entry in forMosque.entries)
          if (_toDouble(entry.value) != null)
            entry.key.toString(): _toDouble(entry.value)!,
      };
    } catch (e) {
      debugPrint('RewardPriceStore.loadPrices error: $e');
      return {};
    }
  }

  /// يحفظ تسعيرة جامع واحد دون المساس بتسعيرة بقية الجوامع.
  static Future<void> savePrices(
      String mosqueId, Map<String, double> prices) async {
    if (mosqueId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_pricesKey);
      final Map<String, dynamic> all = () {
        if (raw == null || raw.isEmpty) return <String, dynamic>{};
        final decoded = jsonDecode(raw);
        return decoded is Map
            ? decoded.map((k, v) => MapEntry(k.toString(), v))
            : <String, dynamic>{};
      }();

      // الأسعار الصفرية أو الفارغة تُحذف بدل أن تُحفظ
      final cleaned = <String, double>{
        for (final e in prices.entries)
          if (e.value > 0) e.key: e.value,
      };

      if (cleaned.isEmpty) {
        all.remove(mosqueId);
      } else {
        all[mosqueId] = cleaned;
      }
      await prefs.setString(_pricesKey, jsonEncode(all));
    } catch (e) {
      debugPrint('RewardPriceStore.savePrices error: $e');
    }
  }

  static Future<String> loadCurrency() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getString(_currencyKey);
      if (value == null || value.trim().isEmpty) return defaultCurrency;
      return value.trim();
    } catch (e) {
      debugPrint('RewardPriceStore.loadCurrency error: $e');
      return defaultCurrency;
    }
  }

  static Future<void> saveCurrency(String currency) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_currencyKey, currency.trim());
    } catch (e) {
      debugPrint('RewardPriceStore.saveCurrency error: $e');
    }
  }

  static double? _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim());
    return null;
  }
}
