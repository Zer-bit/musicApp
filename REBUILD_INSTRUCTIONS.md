# 🔄 FULL REBUILD REQUIRED

## The Problem
Hot restart doesn't always load new features properly. The lyrics feature IS in your code, but your app is running an old version.

## The Solution - Full Rebuild

### Option 1: Quick Rebuild (Try This First)
```bash
flutter clean
flutter pub get
flutter run
```

### Option 2: Complete Clean Build (If Option 1 Doesn't Work)
```bash
# Stop the app completely first
flutter clean
cd android
gradlew clean
cd ..
flutter pub get
flutter run
```

### Option 3: Nuclear Option (If Nothing Else Works)
```bash
# Delete build folders manually
rmdir /s /q build
rmdir /s /q android\build
rmdir /s /q android\app\build

# Then rebuild
flutter pub get
flutter run
```

## What You Should See After Rebuild

1. Open any song in your "All Songs" list
2. Tap the three dots (⋮) menu on the right
3. You should see THREE options:
   - ➕ Add to Playlist
   - 🎵 Add Lyrics (or "Edit Lyrics" if lyrics exist)
   - 🗑️ Delete Song

4. Tap "Add Lyrics" to open the lyrics editor
5. Type or paste lyrics
6. Tap "Save" to save them
7. The lyrics icon will turn blue when a song has lyrics

## Why This Happens
- Hot restart only reloads Dart code
- New methods and state variables need a full rebuild
- Flutter sometimes caches old versions

## Verification
After rebuild, check your console for this line when the app starts:
```
✓ Loaded X lyrics from cache
```

This confirms the lyrics feature is active.
