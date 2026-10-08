# Flutter / 플러그인은 자체 consumer 규칙을 제공한다. 추가로 필요한 것만 여기에.
-keep class com.google.android.gms.ads.** { *; }

# AGP 9 의 R8 은 Room 이 리플렉션으로 만드는 *_Impl 클래스를 지워 버린다.
# 광고 SDK 가 쓰는 WorkManager(WorkDatabase_Impl)가 없어지면 릴리즈 빌드가 시작하자마자
# "Failed to create an instance of androidx.work.impl.WorkDatabase" 로 죽는다 (2026-10-08 확인).
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
-keep class androidx.work.** { *; }
-keep class androidx.room.** { *; }
