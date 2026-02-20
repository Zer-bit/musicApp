# 📱 Connecting Flutter App to Your API

## ✅ What I Just Added

I've added the complete Browse Songs feature to your Flutter app with:
- YouTube search functionality
- Download button for each video
- API integration to download and convert to MP3
- Progress indicators
- Automatic song list refresh after download

## 🔧 Setup Steps

### Step 1: Install Dependencies

Run this command in your Flutter project folder:

```cmd
cd C:\Users\jezer\Documents\musicApp
flutter pub get
```

This will install the new `http` and `youtube_explode_dart` packages.

### Step 2: Configure API URL

The API URL is set in the code at line ~2450 in `lib/main.dart`:

```dart
static const String apiUrl = 'http://10.0.2.2:3000';
```

**Change this based on your setup:**

#### Testing on Android Emulator:
```dart
static const String apiUrl = 'http://10.0.2.2:3000';
```
✅ Already set! No changes needed.

#### Testing on Real Android Device:
1. Find your computer's IP address:
   ```cmd
   ipconfig
   ```
   Look for "IPv4 Address" (e.g., `192.168.1.100`)

2. Update the code:
   ```dart
   static const String apiUrl = 'http://192.168.1.100:3000';
   ```

3. Make sure:
   - Your phone and computer are on the same WiFi network
   - Your API is running (`npm run dev`)

#### Production (After deploying to Railway):
```dart
static const String apiUrl = 'https://your-app.railway.app';
```

### Step 3: Make Sure Your API is Running

In a separate Command Prompt window:

```cmd
cd C:\Users\jezer\Documents\youtube-mp3-api
npm run dev
```

You should see:
```
╔════════════════════════════════════════╗
║   YouTube MP3 API Server Running       ║
║   Port: 3000                           ║
║   URL: http://localhost:3000           ║
╚════════════════════════════════════════╝
```

### Step 4: Run Your Flutter App

```cmd
cd C:\Users\jezer\Documents\musicApp
flutter run
```

## 🎯 How to Use

1. **Open the app** on your device/emulator
2. **Tap "Browse" tab** at the bottom (cloud download icon)
3. **Search for a song** (e.g., "Bohemian Rhapsody")
4. **Tap the download button** on any video
5. **Wait for download** (shows progress indicator)
6. **Song appears in "All Songs"** tab automatically!

## 📊 What Happens When You Download

```
1. User taps download button
   ↓
2. Flutter app sends request to your API
   POST http://10.0.2.2:3000/api/download
   Body: { "url": "https://youtube.com/watch?v=..." }
   ↓
3. Your API downloads video from YouTube
   ↓
4. Your API converts video to MP3 using FFmpeg
   ↓
5. Your API sends MP3 file back to Flutter app
   ↓
6. Flutter app saves MP3 to /storage/emulated/0/Music/
   ↓
7. Song list refreshes automatically
   ↓
8. User sees "✓ Downloaded: Song Name"
```

## 🔍 Debugging

### Check API is Running

Open browser and go to: http://localhost:3000

You should see:
```json
{
  "status": "YouTube MP3 API is running",
  "version": "1.0.0"
}
```

### Check Flutter App Logs

In the terminal where you ran `flutter run`, you'll see:
```
Searching YouTube for: [your search]
Found 20 results
Requesting download from API: https://youtube.com/watch?v=...
API URL: http://10.0.2.2:3000
API Response Status: 200
Saving to: /storage/emulated/0/Music/Song Name.mp3
✓ Downloaded: /storage/emulated/0/Music/Song Name.mp3
```

### Check API Logs

In the terminal where you ran `npm run dev`, you'll see:
```
Download requested for: https://youtube.com/watch?v=...
Downloading: Song Name
FFmpeg started
Processing: 25.00%
Processing: 50.00%
Processing: 75.00%
Download completed: Song Name
```

## ❌ Common Issues

### Issue 1: "Connection refused" or "Failed to connect"

**Cause:** API is not running or wrong URL

**Solution:**
1. Make sure API is running: `npm run dev`
2. Check API URL in code matches your setup
3. For real device, use your computer's IP address

### Issue 2: "Download failed: SocketException"

**Cause:** Phone can't reach computer

**Solution:**
1. Make sure phone and computer are on same WiFi
2. Check Windows Firewall isn't blocking port 3000
3. Try disabling Windows Firewall temporarily to test

### Issue 3: "API Error: 500"

**Cause:** API error (YouTube blocking, FFmpeg issue, etc.)

**Solution:**
1. Check API logs in Command Prompt
2. Try a different video
3. Update ytdl-core: `npm install ytdl-core@latest`

### Issue 4: Download takes forever

**Cause:** Large video or slow internet

**Solution:**
- This is normal! Video download + conversion takes time
- Short videos (3-5 min): ~30-60 seconds
- Long videos (10+ min): 2-5 minutes
- Be patient and watch the API logs for progress

### Issue 5: "Permission denied" when saving file

**Cause:** Storage permission not granted

**Solution:**
1. Go to Android Settings → Apps → Jezsic → Permissions
2. Enable "Storage" or "Files and media"
3. Restart the app

## 🚀 Testing Checklist

- [ ] API is running (`npm run dev`)
- [ ] Flutter dependencies installed (`flutter pub get`)
- [ ] API URL configured correctly in code
- [ ] App running on device/emulator
- [ ] Can see Browse tab
- [ ] Can search YouTube
- [ ] Can see search results
- [ ] Download button works
- [ ] Progress indicator shows
- [ ] Song saves to Music folder
- [ ] Song appears in All Songs tab

## 📱 Screenshots of What You'll See

### Browse Tab
- Search bar at top
- "Search for songs on YouTube" message
- After search: List of videos with thumbnails
- Download button on each video

### During Download
- Progress indicator at bottom
- "Downloading and converting to MP3..." message
- Download button shows spinner

### After Download
- Green snackbar: "✓ Downloaded: Song Name"
- Song appears in All Songs tab
- Can play immediately

## 🌐 Next Steps (Production)

Once everything works locally:

1. **Deploy API to Railway** (see COMPLETE_API_SETUP_GUIDE.md)
2. **Get your Railway URL** (e.g., `https://your-app.railway.app`)
3. **Update API URL in code:**
   ```dart
   static const String apiUrl = 'https://your-app.railway.app';
   ```
4. **Rebuild app:**
   ```cmd
   flutter build apk
   ```
5. **Install on any device** - works anywhere with internet!

## 💡 Tips

- **Search Tips:** Use specific song names for better results
- **Download Speed:** Shorter videos download faster
- **Storage:** Check your phone has enough space
- **WiFi:** Use WiFi for faster downloads (not mobile data)
- **API Logs:** Keep API terminal open to see progress

## 🎉 Success!

If you can search, download, and play songs, everything is working perfectly!

Your music app now has:
- ✅ Local music playback
- ✅ Playlists
- ✅ YouTube search
- ✅ YouTube to MP3 download
- ✅ Sleep timer
- ✅ Volume booster
- ✅ Bluetooth auto-resume

Congratulations! 🎵
