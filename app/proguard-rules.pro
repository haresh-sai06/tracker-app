## Proguard Rules for Secure Expense & Income Tracker App

# Flutter & Engine rules (just in case)
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Hive database adapters & models keep rules
-keep class com.yourapp.tracker.** { *; }
-keep class * extends com.hive_flutter.** { *; }
-keep class * extends io.hive.** { *; }
-keep class io.hive.adapter.** { *; }
-keep class * extends io.hive.HiveInterface { *; }
-keep class * implements io.hive.HiveInterface { *; }
-keep class io.hive.binary.** { *; }
-keep class io.hive.box.** { *; }
-keep class io.hive.common.** { *; }
-keep class io.hive.crypto.** { *; }
-keep class io.hive.impl.** { *; }
-keep class io.hive.util.** { *; }

# Riverpod generated code keep rules
-keep class * extends uid.riverpod.** { *; }
-keep class * implements uid.riverpod.** { *; }

# google_sign_in & googleapis keep rules
-keep class com.google.android.gms.auth.api.signin.** { *; }
-keep class com.google.api.services.** { *; }
-keep class com.google.api.client.** { *; }

# local_auth security keep rules
-keep class androidx.biometric.** { *; }
-keep class io.flutter.plugins.localauth.** { *; }

# flutter_secure_storage keep rules
-keep class android.security.keystore.** { *; }
-keep class io.flutter.plugins.flutter_secure_storage.** { *; }

# PDF package keep rules
-keep class com.pdf.** { *; }
-keep class net.sf.pdf.** { *; }
-keep class com.itextpdf.** { *; }
-keep class org.apache.pdfbox.** { *; }
