# ──────────────────────────────────────────────────────────────────────────────
#  Jezsic Music App – ProGuard / R8 Rules
#  Required for release builds to prevent stripping of plugin classes
# ──────────────────────────────────────────────────────────────────────────────

# ── Flutter core ──────────────────────────────────────────────────────────────
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# ── audio_service (com.ryanheise) ─────────────────────────────────────────────
# Without these rules R8 renames/removes the MediaBrowserService and
# MediaButtonReceiver classes, breaking the foreground service notification.
-keep class com.ryanheise.audioservice.** { *; }
-keepnames class com.ryanheise.audioservice.** { *; }
-keep public class com.ryanheise.audioservice.AudioService { *; }
-keep public class com.ryanheise.audioservice.MediaButtonReceiver { *; }
-keep public class com.ryanheise.audioservice.AudioServiceActivity { *; }

# ── just_audio ────────────────────────────────────────────────────────────────
-keep class com.ryanheise.just_audio.** { *; }
-keepnames class com.ryanheise.just_audio.** { *; }

# ── audio_session ─────────────────────────────────────────────────────────────
-keep class com.ryanheise.audio_session.** { *; }

# ── flutter_blue_plus ─────────────────────────────────────────────────────────
-keep class com.boskokg.flutter_blue_plus.** { *; }
-dontwarn com.boskokg.flutter_blue_plus.**

# ── permission_handler ────────────────────────────────────────────────────────
-keep class com.baseflow.permissionhandler.** { *; }

# ── shared_preferences ────────────────────────────────────────────────────────
-keep class io.flutter.plugins.sharedpreferences.** { *; }

# ── path_provider ─────────────────────────────────────────────────────────────
-keep class io.flutter.plugins.pathprovider.** { *; }

# ── Kotlin coroutines (used by most plugins) ──────────────────────────────────
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory { *; }
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler { *; }
-keepclassmembers class kotlinx.coroutines.** { volatile <fields>; }

# ── General Android media / service rules ─────────────────────────────────────
# Prevent R8 from stripping Service, BroadcastReceiver subclasses referenced
# only from AndroidManifest.xml (not via code).
-keep public class * extends android.app.Service
-keep public class * extends android.content.BroadcastReceiver
-keep public class * extends android.support.v4.media.session.MediaSessionCompat

# ── flutter_local_notifications ───────────────────────────────────────────────
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-dontwarn com.dexterous.flutterlocalnotifications.**

# ── youtube_explode_dart / http (Dart-only, no native code to keep) ────────────
# Prevent R8 from stripping OkHttp/Conscrypt used by the http package
-dontwarn okhttp3.**
-dontwarn okio.**

# ── Suppress library warnings ─────────────────────────────────────────────────
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.**
