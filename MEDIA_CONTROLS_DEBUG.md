# Media Controls Debug Guide

## What I Fixed

1. ✅ Added detailed logging to track when actions are triggered
2. ✅ Added null check for actionId (handles notification body taps)
3. ✅ Added `category: AndroidNotificationCategory.transport` for proper media notification
4. ✅ Made action constants where possible for better performance

## How to Test & Debug

### Step 1: Rebuild the App
```bash
flutter clean
flutter run
```

### Step 2: Play a Song
- Open the app
- Play any song from your library

### Step 3: Check the Notification
- Swipe down to see the notification shade
- You should see 4 buttons: Previous, Play/Pause, Next, Close

### Step 4: Test Each Button

**Watch the console logs while testing!**

When you tap a button, you should see logs like:
```
🎵 Notification action received
   Action ID: play_pause
   Notification ID: 0
   Payload: null
   Processing action: play_pause
   → Play/Pause action
```

#### Test Previous Button:
- Tap the Previous button
- Check console for: `→ Previous action`
- Song should skip to previous

#### Test Play/Pause Button:
- Tap the Play/Pause button
- Check console for: `→ Play/Pause action`
- Song should pause/resume

#### Test Next Button:
- Tap the Next button
- Check console for: `→ Next action`
- Song should skip to next

#### Test Close Button:
- Tap the Close button
- Check console for: `→ Close action`
- Playback should stop and notification should disappear

## Troubleshooting

### If buttons don't respond at all:

1. **Check console logs** - Do you see "🎵 Notification action received" when tapping buttons?
   - **NO** → The action handler isn't being called. This might be a permission issue.
   - **YES** → Continue to next step

2. **Check if actionId is null**
   - If you see "Notification body tapped - no action", you're tapping the notification itself, not the buttons
   - Make sure to tap the actual button icons

3. **Check for error messages**
   - Look for any red error messages in the console
   - Share them if you see any

### If you see the action but nothing happens:

1. **Check if GlobalAudioService has data**
   - The logs should show what's in `currentPlaylist`
   - If playlist is empty, the actions won't work

2. **Try playing a song again**
   - Sometimes the service needs to be initialized
   - Play a song from the app first, then try the notification buttons

### If Play/Pause doesn't work:

The play/pause action calls `playSong()` with the current song. This should:
- Pause if playing
- Resume if paused

If it's not working, check:
- Is `currentlyPlaying` set correctly?
- Is the song path valid?

## Expected Behavior

✅ **Previous Button**: Skips to previous song (or restarts current if > 3 seconds)
✅ **Play/Pause Button**: Toggles playback, icon changes
✅ **Next Button**: Skips to next song
✅ **Close Button**: Stops playback and dismisses notification

## What to Share if Still Not Working

If the buttons still don't work after testing, please share:

1. **Console logs** when you tap a button
2. **Which button** isn't working (or all of them?)
3. **Any error messages** you see
4. **Does the notification appear?** (Yes/No)
5. **Can you see the button icons?** (Yes/No)

This will help me identify the exact issue!
