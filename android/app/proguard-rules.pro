# ===== Flutter / Plugins =====
-keep class io.flutter.** { *; }
-dontwarn io.flutter.**

# Generated plugin registrant (safe catch-all)
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }

# ===== Networking (Dio / OkHttp / Okio / Gson) =====
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
-dontwarn okhttp3.**
-keep class okio.** { *; }
-dontwarn okio.**

# Gson + annotations
-keep class com.google.gson.** { *; }
-dontwarn com.google.gson.**
-keepclassmembers class * { @com.google.gson.annotations.SerializedName <fields>; }
-keepattributes Signature, *Annotation*
-keep class * extends java.lang.Enum { *; }
-keep class com.google.gson.stream.** { *; }

# ===== Media / Players =====
# ExoPlayer (video_player)
-keep class com.google.android.exoplayer2.** { *; }
-dontwarn com.google.android.exoplayer2.**

# ===== FFmpegKit (CRITICAL) =====
# Official package name
-keep class com.arthenica.ffmpegkit.** { *; }
-dontwarn com.arthenica.ffmpegkit.**
# Legacy names
-keep class com.arthenica.mobileffmpeg.** { *; }
-dontwarn com.arthenica.mobileffmpeg.**
# (Optional) Some forks republish under this ns — harmless to keep
-keep class com.antonkarpenko.ffmpegkit.** { *; }
-dontwarn com.antonkarpenko.ffmpegkit.**

# ===== Security / Storage =====
-keep class androidx.security.crypto.** { *; }
-dontwarn androidx.security.crypto.**

# ===== WebView / Chromium noise (optional) =====
-dontwarn org.chromium.**
-dontwarn android.net.http.**

# ===== Ringtone plugin & other reflection-prone libs (safe keeps) =====
-keep class acr.rt.ringtone_set_plus.** { *; }
