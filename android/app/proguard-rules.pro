# ML Kit fix (مهم جدًا)
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# optional (زيادة أمان)
-keep class com.google.android.gms.internal.mlkit_vision_text_common.** { *; }
-dontwarn com.google.android.gms.internal.mlkit_vision_text_common.**