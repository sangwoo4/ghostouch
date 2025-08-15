# Flutter's default ProGuard rules can be found in
# flutter/packages/flutter_tools/gradle/flutter_proguard_rules.pro

# Rules for libraries that use Java annotation processing.
-dontwarn javax.annotation.processing.**
-dontwarn javax.lang.model.**
-dontwarn javax.tools.**

-keep class javax.annotation.processing.** { *; }
-keep class javax.lang.model.** { *; }
-keep class javax.tools.** { *; }

# Keep all classes related to AutoValue, as they are often accessed via reflection.
-keep class com.google.auto.value.** { *; }
-keep @com.google.auto.value.AutoValue class * {
    <init>(...);
}

# Keep classes that are referenced by AutoValue extensions.
-keep class autovalue.shaded.com.google.** { *; }
-keep class autovalue.shaded.com.squareup.javapoet.** { *; }
