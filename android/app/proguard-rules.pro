-keep class com.yausername.** { *; }
-keep class org.apache.commons.compress.** { *; }
-dontwarn com.yausername.**
# commons-compress optionally references xz/LZMA codecs that are not on the
# compile classpath; R8 full mode fails the release build without this.
-dontwarn org.tukaani.xz.**
-keep class org.tukaani.xz.** { *; }
