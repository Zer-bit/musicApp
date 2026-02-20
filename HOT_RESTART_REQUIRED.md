# 🔄 Hot Restart Required!

## ⚠️ Important: You Need to Hot Restart the App

The lyrics feature has been added to the code, but you need to **hot restart** (not just hot reload) for the changes to take effect.

## 🔧 How to Hot Restart:

### Option 1: In Terminal (Recommended)
If your app is running in the terminal, press:
```
R
```
(Capital R for restart)

### Option 2: Stop and Restart
```cmd
# Stop the app (Ctrl+C in terminal)
# Then run again:
flutter run
```

### Option 3: VS Code
If using VS Code:
1. Click the restart button (🔄) in the debug toolbar
2. Or press `Ctrl+Shift+F5`

## 🆚 Hot Reload vs Hot Restart

### Hot Reload (r):
- Fast
- Keeps app state
- **Doesn't work for new state variables**
- Use for UI changes only

### Hot Restart (R):
- Slower
- Resets app state
- **Works for new features**
- Use when adding new functionality

## ✅ After Hot Restart:

You should see:
1. Go to All Songs
2. Tap ⋮ on any song
3. You'll see **3 options**:
   - Add to Playlist
   - **Add Lyrics** ← NEW!
   - Delete Song

## 🎤 Testing the Lyrics Feature:

1. **Hot restart** the app (press R)
2. Go to **All Songs** tab
3. Tap **⋮** on any song
4. Select **"Add Lyrics"**
5. Type some lyrics
6. Tap **"Save Lyrics"**
7. Open menu again - should say **"Edit Lyrics"** now
8. Icon should be **blue** 🔵

## 🐛 If It Still Doesn't Work:

### Step 1: Verify Code is Saved
Check that `lib/main.dart` was saved properly.

### Step 2: Clean Build
```cmd
flutter clean
flutter pub get
flutter run
```

### Step 3: Check Console
Look for any error messages in the terminal.

### Step 4: Verify Changes
The popup menu should have 3 items now (was 2 before):
- ✅ Add to Playlist
- ✅ Add Lyrics (NEW)
- ✅ Delete Song

## 📊 What Changed:

### New State Variables:
```dart
final Map<String, String> _lyrics = {}; // NEW!
```

### New Methods:
```dart
void _saveLyrics(String songPath, String lyrics) // NEW!
void _showLyricsDialog(String songPath, String songTitle) // NEW!
```

### Updated Menu:
```dart
PopupMenuItem(
  value: 'lyrics', // NEW OPTION!
  child: Row(
    children: [
      Icon(Icons.lyrics, ...),
      Text('Add Lyrics'),
    ],
  ),
),
```

## 🎯 Quick Test:

After hot restart:
1. Open app
2. All Songs tab
3. Tap ⋮ on first song
4. Count menu items:
   - Should be **3 items** (not 2)
   - Middle item should say "Add Lyrics"

If you see 3 items, it's working! ✅

## 🚀 Commands Summary:

### Hot Restart (Fastest):
```
Press: R (capital R)
```

### Full Restart:
```cmd
Ctrl+C
flutter run
```

### Clean Restart (if issues):
```cmd
flutter clean
flutter pub get
flutter run
```

## ✨ Expected Result:

After hot restart, you'll have a beautiful lyrics feature with:
- 🎤 Add/Edit lyrics option in menu
- 🟣🔵 Beautiful gradient dialog
- 📝 Scrollable text editor
- 💾 Save button
- 🗑️ Remove button
- 🔵 Blue icon when song has lyrics

Try it now! Press **R** to hot restart! 🎵
