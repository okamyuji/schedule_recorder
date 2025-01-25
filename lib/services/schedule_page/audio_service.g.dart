// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'audio_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$audioServiceHash() => r'c20ebd696799957cb994a5439f8c40f39528ffb0';

/// オーディオサービスのプロバイダー
///
/// Copied from [audioService].
@ProviderFor(audioService)
final audioServiceProvider = Provider<AudioService>.internal(
  audioService,
  name: r'audioServiceProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$audioServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AudioServiceRef = ProviderRef<AudioService>;
String _$audioServiceNotifierHash() =>
    r'4d8fbfa70d9b2414eb7bfafcf6589a2c73da3b30';

/// オーディオサービスの状態を管理するプロバイダー
///
/// Copied from [AudioServiceNotifier].
@ProviderFor(AudioServiceNotifier)
final audioServiceNotifierProvider = AutoDisposeNotifierProvider<
    AudioServiceNotifier, AudioServiceState>.internal(
  AudioServiceNotifier.new,
  name: r'audioServiceNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$audioServiceNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$AudioServiceNotifier = AutoDisposeNotifier<AudioServiceState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
