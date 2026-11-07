# Règles R8 pour Frigo Malin
# flutter_local_notifications sérialise les notifications programmées avec Gson.
-keep class com.dexterous.** { *; }
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod
-keep class com.google.gson.** { *; }
-dontwarn com.google.android.play.core.**
