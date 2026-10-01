// import 'dart:convert';
// import 'package:crypto/crypto.dart' as crypto;
//
// class OfflineCapsule {
// final int schemaVersion;
// final int capsuleVersion;
// final String displayVersion;
// final DateTime publishedAt;
// final int minimumAppBuild;
// final String sha256;
// final String sourceName;
// final List<OfflineItem> items;
//
// const OfflineCapsule({
// required this.schemaVersion,
// required this.capsuleVersion,
// required this.displayVersion,
// required this.publishedAt,
// required this.minimumAppBuild,
// required this.sha256,
// required this.sourceName,
// required this.items,
// });
//
// factory OfflineCapsule.fromJsonString(String source) {
// dynamic decoded;
//
// try {
// decoded = jsonDecode(source);
// } on FormatException catch (e) {
// throw FormatException(
// 'Invalid capsule JSON: ${e.message}',
// );
// }
//
// if (decoded is! Map) {
// throw const FormatException(
// 'Capsule root must be a JSON object.',
// );
// }
//
// return OfflineCapsule.fromJson(
// Map<String, dynamic>.from(decoded),
// );
// }
//
// factory OfflineCapsule.fromJson(
// Map<String, dynamic> json,
// ) {
// _requireKey(json, 'schemaVersion');
// _requireKey(json, 'capsuleVersion');
// _requireKey(json, 'displayVersion');
// _requireKey(json, 'publishedAt');
// _requireKey(json, 'minimumAppBuild');
// _requireKey(json, 'sha256');
// _requireKey(json, 'sourceName');
// _requireKey(json, 'items');
//
// if (json['schemaVersion'] is! int) {
// throw const FormatException(
// 'schemaVersion must be an integer.',
// );
// }
//
// if (json['capsuleVersion'] is! int) {
// throw const FormatException(
// 'capsuleVersion must be an integer.',
// );
// }
//
// if (json['displayVersion'] is! String) {
// throw const FormatException(
// 'displayVersion must be a string.',
// );
// }
//
// if (json['publishedAt'] is! String) {
// throw const FormatException(
// 'publishedAt must be an ISO-8601 string.',
// );
// }
//
// final publishedAtString =
// json['publishedAt'] as String;
//
// late final DateTime publishedAt;
//
// try {
// publishedAt = DateTime.parse(
// publishedAtString,
// );
// } catch (_) {
// throw const FormatException(
// 'publishedAt contains an invalid date.',
// );
// }
//
// if (json['minimumAppBuild'] is! int) {
// throw const FormatException(
// 'minimumAppBuild must be an integer.',
// );
// }
//
// if (json['sha256'] is! String) {
// throw const FormatException(
// 'sha256 must be a string.',
// );
// }
//
// final declaredSha256 =
// (json['sha256'] as String)
//     .trim()
//     .toLowerCase();
//
// if (!RegExp(
// r'^[a-f0-9]{64}$',
// ).hasMatch(declaredSha256)) {
// throw const FormatException(
// 'sha256 must contain exactly 64 hexadecimal characters.',
// );
// }
//
// if (json['sourceName'] is! String) {
// throw const FormatException(
// 'sourceName must be a string.',
// );
// }
//
// if (json['items'] is! List) {
// throw const FormatException(
// 'items must be a JSON array.',
// );
// }
//
// final itemsJson = json['items'] as List;
//
// final items = <OfflineItem>[];
//
// for (var i = 0; i < itemsJson.length; i++) {
// final rawItem = itemsJson[i];
//
// if (rawItem is! Map) {
// throw FormatException(
// 'items[$i] must be a JSON object.',
// );
// }
//
// items.add(
// OfflineItem.fromJson(
// Map<String, dynamic>.from(rawItem),
// ),
// );
// }
//
// final capsule = OfflineCapsule(
// schemaVersion:
// json['schemaVersion'] as int,
// capsuleVersion:
// json['capsuleVersion'] as int,
// displayVersion:
// json['displayVersion'] as String,
// publishedAt: publishedAt,
// minimumAppBuild:
// json['minimumAppBuild'] as int,
// sha256: declaredSha256,
// sourceName:
// json['sourceName'] as String,
// items: List.unmodifiable(items),
// );
//
// capsule.verifyIntegrity(json);
//
// return capsule;
// }
//
// /// Returns the data that is actually protected
// /// by the SHA-256 hash.
// ///
// /// The sha256 field is removed because a hash
// /// cannot contain itself.
// Map<String, dynamic> integrityPayload(
// Map<String, dynamic> originalJson,
// ) {
// final payload =
// Map<String, dynamic>.from(originalJson);
//
// payload.remove('sha256');
//
// return _canonicalizeMap(payload);
// }
//
// /// Creates deterministic JSON.
// ///
// /// Object keys are sorted recursively.
// /// List order is preserved.
// /// No unnecessary whitespace is included.
// String canonicalJson(
// Map<String, dynamic> originalJson,
// ) {
// final canonical =
// integrityPayload(originalJson);
//
// return jsonEncode(canonical);
// }
//
// /// Calculates SHA-256 from the deterministic
// /// canonical JSON.
// String calculateHash(
// Map<String, dynamic> originalJson,
// ) {
// final canonical =
// canonicalJson(originalJson);
//
// final bytes = utf8.encode(canonical);
//
// return crypto.sha256
//     .convert(bytes)
//     .toString();
// }
//
// /// Compares the calculated hash with the
// /// hash stored inside the capsule.
// void verifyIntegrity(
// Map<String, dynamic> originalJson,
// ) {
// final calculatedHash =
// calculateHash(originalJson);
//
// if (calculatedHash != sha256) {
// throw FormatException(
// 'Capsule integrity check failed.\n'
// 'Expected: $sha256\n'
// 'Calculated: $calculatedHash\n'
// 'Capsule version: $capsuleVersion\n'
// 'Display version: $displayVersion\n'
// 'Source: $sourceName',
// );
// }
// }
//
// static Map<String, dynamic> _canonicalizeMap(
// Map<String, dynamic> input,
// ) {
// final keys = input.keys.toList()..sort();
//
// final result = <String, dynamic>{};
//
// for (final key in keys) {
// result[key] =
// _canonicalizeValue(input[key]);
// }
//
// return result;
// }
//
// static dynamic _canonicalizeValue(
// dynamic value,
// ) {
// if (value is Map) {
// return _canonicalizeMap(
// Map<String, dynamic>.from(value),
// );
// }
//
// if (value is List) {
// return value
//     .map<dynamic>(_canonicalizeValue)
//     .toList();
// }
//
// return value;
// }
//
// static void _requireKey(
// Map<String, dynamic> json,
// String key,
// ) {
// if (!json.containsKey(key)) {
// throw FormatException(
// 'Capsule is missing required field: $key',
// );
// }
// }
// }
//
// class OfflineItem {
// final String id;
// final String title;
// final String category;
// final String summary;
//
// const OfflineItem({
// required this.id,
// required this.title,
// required this.category,
// required this.summary,
// });
//
// factory OfflineItem.fromJson(
// Map<String, dynamic> json,
// ) {
// _requireItemKey(json, 'id');
// _requireItemKey(json, 'title');
// _requireItemKey(json, 'category');
// _requireItemKey(json, 'summary');
//
// if (json['id'] is! String) {
// throw const FormatException(
// 'Item id must be a string.',
// );
// }
//
// if (json['title'] is! String) {
// throw const FormatException(
// 'Item title must be a string.',
// );
// }
//
// if (json['category'] is! String) {
// throw const FormatException(
// 'Item category must be a string.',
// );
// }
//
// if (json['summary'] is! String) {
// throw const FormatException(
// 'Item summary must be a string.',
// );
// }
//
// return OfflineItem(
// id: json['id'] as String,
// title: json['title'] as String,
// category: json['category'] as String,
// summary: json['summary'] as String,
// );
// }
//
// Map<String, dynamic> toJson() {
// return {
// 'id': id,
// 'title': title,
// 'category': category,
// 'summary': summary,
// };
// }
//
// static void _requireItemKey(
// Map<String, dynamic> json,
// String key,
// ) {
// if (!json.containsKey(key)) {
// throw FormatException(
// 'Offline item is missing required field: $key',
// );
// }
// }
// }
//
