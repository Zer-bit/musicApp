# 🚀 Complete API Setup Guide - Everything in One Place

## 📋 Table of Contents
1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Step-by-Step Setup](#step-by-step-setup)
4. [Testing Your API](#testing-your-api)
5. [Connecting to Flutter App](#connecting-to-flutter-app)
6. [Deploying to Production](#deploying-to-production)
7. [Troubleshooting](#troubleshooting)

---

## Overview

### What You're Building
A YouTube to MP3 converter API that your Flutter app will use to download songs.

### Why Separate Projects?
- **Flutter App** (Dart) = User interface on Android phone
- **API Server** (JavaScript) = Backend processing on computer/cloud
- They communicate via HTTP requests (like calling a website)

### Folder Structure
```
C:\Users\jezer\Documents\
├── musicApp\              ← Your Flutter app (CURRENT)
│   └── lib\main.dart     ← No errors! ✓
│
└── youtube-mp3-api\       ← Your API (CREATE THIS)
    ├── server.js
    ├── package.json
    └── node_modules\
```

---

## Prerequisites

### 1. Install Node.js

**Download:**
- Go to https://nodejs.org/
- Download the LTS (Long Term Support) version
- Run the installer

**Installation Steps:**
1. Run the downloaded `.msi` file
2. Click "Next" through the wizard
3. **IMPORTANT:** Make sure "Add to PATH" is checked
4. Click "Install"
5. Wait for installation to complete
6. Click "Finish"

**Verify Installation:**
Open Command Prompt and run:
```cmd
node --version
npm --version
```

You should see version numbers like:
```
v20.11.0
10.2.4
```

If you see "not recognized", restart Command Prompt and try again.

---

### 2. Install FFmpeg

FFmpeg converts video to MP3 format.

#### Option A: Using Chocolatey (Easiest)

If you have Chocolatey package manager:
```cmd
choco install ffmpeg
```

#### Option B: Manual Installation (Recommended)

**Step 1: Download FFmpeg**
1. Go to https://ffmpeg.org/download.html
2. Click "Windows" builds
3. Download from gyan.dev or BtbN
4. Download the "full" build (not essentials)

**Step 2: Extract FFmpeg**
1. Extract the downloaded zip file
2. Rename the folder to just `ffmpeg`
3. Move it to `C:\ffmpeg`
4. Inside should be folders: `bin`, `doc`, `presets`

**Step 3: Add to Windows PATH**
1. Press Windows key
2. Type "Environment Variables"
3. Click "Edit the system environment variables"
4. Click "Environment Variables" button at bottom
5. Under "System variables", find and select "Path"
6. Click "Edit"
7. Click "New"
8. Type: `C:\ffmpeg\bin`
9. Click "OK" on all windows

**Step 4: Verify Installation**
1. Close and reopen Command Prompt (important!)
2. Run:
```cmd
ffmpeg -version
```

You should see FFmpeg version information.

---

## Step-by-Step Setup

### Step 1: Create API Folder

Open Command Prompt and run these commands one by one:

```cmd
cd C:\Users\jezer\Documents
mkdir youtube-mp3-api
cd youtube-mp3-api
```

You should now be in: `C:\Users\jezer\Documents\youtube-mp3-api`

---

### Step 2: Create package.json

In the `youtube-mp3-api` folder, create a file named `package.json` with this content:

```json
{
  "name": "youtube-mp3-api",
  "version": "1.0.0",
  "description": "YouTube to MP3 converter API",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "dev": "nodemon server.js"
  },
  "keywords": ["youtube", "mp3", "api"],
  "author": "Your Name",
  "license": "MIT",
  "dependencies": {
    "express": "^4.18.2",
    "cors": "^2.8.5",
    "ytdl-core": "^4.11.5",
    "fluent-ffmpeg": "^2.1.2"
  },
  "devDependencies": {
    "nodemon": "^3.0.1"
  }
}
```

**How to create the file:**
1. Open Notepad
2. Copy the content above
3. Save as `package.json` in `C:\Users\jezer\Documents\youtube-mp3-api\`
4. Make sure it's saved as `package.json` not `package.json.txt`

---

### Step 3: Create server.js

In the same folder, create a file named `server.js` with this content:

```javascript
const express = require('express');
const cors = require('cors');
const ytdl = require('ytdl-core');
const ffmpeg = require('fluent-ffmpeg');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());

// Health check endpoint
app.get('/', (req, res) => {
  res.json({ 
    status: 'YouTube MP3 API is running',
    version: '1.0.0',
    endpoints: {
      info: 'POST /api/info',
      download: 'POST /api/download'
    }
  });
});

// Get video info
app.post('/api/info', async (req, res) => {
  try {
    const { url } = req.body;
    
    console.log('Getting info for:', url);
    
    if (!url) {
      return res.status(400).json({ error: 'URL is required' });
    }

    if (!ytdl.validateURL(url)) {
      return res.status(400).json({ error: 'Invalid YouTube URL' });
    }

    const info = await ytdl.getInfo(url);
    const videoDetails = info.videoDetails;

    res.json({
      success: true,
      data: {
        title: videoDetails.title,
        duration: videoDetails.lengthSeconds,
        thumbnail: videoDetails.thumbnails[0]?.url,
        author: videoDetails.author.name,
        videoId: videoDetails.videoId
      }
    });
  } catch (error) {
    console.error('Error getting info:', error);
    res.status(500).json({ 
      success: false,
      error: error.message 
    });
  }
});

// Download MP3
app.post('/api/download', async (req, res) => {
  try {
    const { url } = req.body;
    
    console.log('Download requested for:', url);
    
    if (!url) {
      return res.status(400).json({ error: 'URL is required' });
    }

    if (!ytdl.validateURL(url)) {
      return res.status(400).json({ error: 'Invalid YouTube URL' });
    }

    const info = await ytdl.getInfo(url);
    const title = info.videoDetails.title.replace(/[^\w\s-]/gi, '').trim();
    
    console.log('Downloading:', title);
    
    // Set response headers
    res.setHeader('Content-Disposition', `attachment; filename="${title}.mp3"`);
    res.setHeader('Content-Type', 'audio/mpeg');

    // Get audio stream
    const audioStream = ytdl(url, {
      filter: 'audioonly',
      quality: 'highestaudio',
    });

    // Convert to MP3 and pipe to response
    ffmpeg(audioStream)
      .audioBitrate(128)
      .format('mp3')
      .on('start', () => {
        console.log('FFmpeg started');
      })
      .on('progress', (progress) => {
        console.log('Processing:', progress.percent ? progress.percent.toFixed(2) + '%' : 'unknown');
      })
      .on('end', () => {
        console.log('Download completed:', title);
      })
      .on('error', (err) => {
        console.error('FFmpeg error:', err);
        if (!res.headersSent) {
          res.status(500).json({ error: 'Conversion failed: ' + err.message });
        }
      })
      .pipe(res, { end: true });

  } catch (error) {
    console.error('Download error:', error);
    if (!res.headersSent) {
      res.status(500).json({ 
        success: false,
        error: error.message 
      });
    }
  }
});

// Start server
app.listen(PORT, () => {
  console.log(`
╔════════════════════════════════════════╗
║   YouTube MP3 API Server Running       ║
║   Port: ${PORT}                           ║
║   URL: http://localhost:${PORT}           ║
╚════════════════════════════════════════╝
  `);
  console.log('Endpoints:');
  console.log('  GET  / - Health check');
  console.log('  POST /api/info - Get video info');
  console.log('  POST /api/download - Download MP3');
  console.log('\nPress Ctrl+C to stop the server');
});
```

**How to create the file:**
1. Open Notepad
2. Copy the content above
3. Save as `server.js` in `C:\Users\jezer\Documents\youtube-mp3-api\`

---

### Step 4: Install Dependencies

In Command Prompt (in the `youtube-mp3-api` folder), run:

```cmd
npm install
```

**What this does:**
- Downloads and installs all required packages
- Creates a `node_modules` folder
- Takes 2-5 minutes depending on internet speed

**Expected output:**
```
added 150 packages, and audited 151 packages in 2m
```

**If you see errors:**
- Make sure you're in the correct folder
- Check your internet connection
- Try: `npm cache clean --force` then `npm install` again

---

### Step 5: Start Your API

In the `youtube-mp3-api` folder, run:

```cmd
npm run dev
```

**Expected output:**
```
╔════════════════════════════════════════╗
║   YouTube MP3 API Server Running       ║
║   Port: 3000                           ║
║   URL: http://localhost:3000           ║
╚════════════════════════════════════════╝
Endpoints:
  GET  / - Health check
  POST /api/info - Get video info
  POST /api/download - Download MP3

Press Ctrl+C to stop the server
```

**If you see this, congratulations! Your API is running! 🎉**

---

## Testing Your API

### Test 1: Browser Test (Easiest)

1. Keep the API running in Command Prompt
2. Open your web browser
3. Go to: http://localhost:3000
4. You should see:
```json
{
  "status": "YouTube MP3 API is running",
  "version": "1.0.0",
  "endpoints": {
    "info": "POST /api/info",
    "download": "POST /api/download"
  }
}
```

✅ If you see this, your API is working!

---

### Test 2: HTML Test Page

Create a file named `test.html` in the `youtube-mp3-api` folder:

```html
<!DOCTYPE html>
<html>
<head>
    <title>API Test</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            max-width: 600px;
            margin: 50px auto;
            padding: 20px;
            background: #1a1a1a;
            color: white;
        }
        input {
            width: 100%;
            padding: 10px;
            margin: 10px 0;
            font-size: 16px;
            border: 2px solid #4CAF50;
            border-radius: 5px;
            background: #2a2a2a;
            color: white;
        }
        button {
            padding: 10px 20px;
            margin: 5px;
            font-size: 16px;
            background: #4CAF50;
            color: white;
            border: none;
            border-radius: 5px;
            cursor: pointer;
        }
        button:hover {
            background: #45a049;
        }
        #result {
            margin-top: 20px;
            padding: 15px;
            background: #2a2a2a;
            border-radius: 5px;
            border: 1px solid #4CAF50;
        }
        .error {
            color: #ff4444;
        }
        .success {
            color: #4CAF50;
        }
    </style>
</head>
<body>
    <h1>🎵 YouTube MP3 API Test</h1>
    
    <input type="text" id="url" placeholder="Enter YouTube URL" 
           value="https://www.youtube.com/watch?v=dQw4w9WgXcQ">
    
    <div>
        <button onclick="getInfo()">Get Video Info</button>
        <button onclick="download()">Download MP3</button>
    </div>
    
    <div id="result"></div>

    <script>
        const API_URL = 'http://localhost:3000';

        async function getInfo() {
            const url = document.getElementById('url').value;
            const result = document.getElementById('result');
            
            result.innerHTML = '⏳ Loading...';
            
            try {
                const response = await fetch(`${API_URL}/api/info`, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                    },
                    body: JSON.stringify({ url })
                });
                
                const data = await response.json();
                
                if (data.success) {
                    result.innerHTML = `
                        <h3 class="success">✓ Video Found!</h3>
                        <p><strong>Title:</strong> ${data.data.title}</p>
                        <p><strong>Author:</strong> ${data.data.author}</p>
                        <p><strong>Duration:</strong> ${data.data.duration} seconds</p>
                        <img src="${data.data.thumbnail}" width="300" style="border-radius: 10px;">
                    `;
                } else {
                    result.innerHTML = `<p class="error">❌ Error: ${data.error}</p>`;
                }
            } catch (error) {
                result.innerHTML = `<p class="error">❌ Error: ${error.message}</p>`;
            }
        }

        async function download() {
            const url = document.getElementById('url').value;
            const result = document.getElementById('result');
            
            result.innerHTML = '⏳ Downloading... This may take a minute.';
            
            try {
                const response = await fetch(`${API_URL}/api/download`, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                    },
                    body: JSON.stringify({ url })
                });
                
                if (response.ok) {
                    const blob = await response.blob();
                    const downloadUrl = window.URL.createObjectURL(blob);
                    const a = document.createElement('a');
                    a.href = downloadUrl;
                    a.download = 'audio.mp3';
                    document.body.appendChild(a);
                    a.click();
                    a.remove();
                    
                    result.innerHTML = '<p class="success">✓ Download started! Check your Downloads folder.</p>';
                } else {
                    const error = await response.json();
                    result.innerHTML = `<p class="error">❌ Error: ${error.error}</p>`;
                }
            } catch (error) {
                result.innerHTML = `<p class="error">❌ Error: ${error.message}</p>`;
            }
        }
    </script>
</body>
</html>
```

**To test:**
1. Make sure your API is running (`npm run dev`)
2. Open `test.html` in your browser
3. Click "Get Video Info" - should show video details
4. Click "Download MP3" - should download the file

---

## Connecting to Flutter App

Once your API is working, add this code to your Flutter app.

### Step 1: Add HTTP Package

In `pubspec.yaml`, add:
```yaml
dependencies:
  http: ^1.1.0
```

Then run:
```cmd
flutter pub get
```

### Step 2: Add Download Method to main.dart

Add this import at the top:
```dart
import 'package:http/http.dart' as http;
```

Add this method to your `_AllSongsScreenState` class:

```dart
Future<void> _downloadFromAPI(String videoUrl, String title) async {
  setState(() {
    _isDownloading = true;
  });

  try {
    // Replace with your API URL
    // For emulator: http://10.0.2.2:3000
    // For real device: http://YOUR_COMPUTER_IP:3000
    const apiUrl = 'http://10.0.2.2:3000';
    
    print('Requesting download from API...');
    
    final response = await http.post(
      Uri.parse('$apiUrl/api/download'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'url': videoUrl}),
    );

    if (response.statusCode == 200) {
      // Save the MP3 file
      final directory = Directory('/storage/emulated/0/Music');
      await directory.create(recursive: true);
      
      final fileName = title.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
      final file = File('${directory.path}/$fileName.mp3');
      
      await file.writeAsBytes(response.bodyBytes);
      
      print('✓ Downloaded: ${file.path}');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✓ Downloaded: $title')),
        );
      }
      
      // Refresh song list
      await _scanForMusicFiles();
      
    } else {
      throw Exception('API Error: ${response.statusCode}');
    }
    
  } catch (e) {
    print('Download error: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: $e')),
      );
    }
  } finally {
    setState(() {
      _isDownloading = false;
    });
  }
}
```

### Step 3: Find Your Computer's IP Address

For testing on a real device, you need your computer's IP:

```cmd
ipconfig
```

Look for "IPv4 Address" under your active network adapter (usually WiFi or Ethernet).
Example: `192.168.1.100`

Then in your Flutter code, use:
```dart
const apiUrl = 'http://192.168.1.100:3000';
```

**Important:** Your phone and computer must be on the same WiFi network!

---

## Deploying to Production

Once everything works locally, deploy your API to the cloud so it works anywhere.

### Which Platform Should You Choose?

| Feature | Railway | Heroku |
|---------|---------|--------|
| **Free Tier** | ✅ Yes | ✅ Yes (limited) |
| **Timeout** | ⏱️ No limit | ⏱️ 30s |
| **FFmpeg Support** | ✅ Easy | ✅ Easy |
| **Long Processes** | ✅ Perfect | ✅ Good |
| **Setup Difficulty** | 🟢 Easy |  Medium |
| **Best For** | Video conversion | Full apps |
| **Recommendation** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ |

**For this YouTube MP3 project:**
- ✅ **Railway** - Best choice (easy setup, no timeout issues)
- ✅ **Heroku** - Good alternative (requires buildpack setup)

### Option 1: Railway (Recommended - Free Tier Available)

**Step 1: Create Railway Account**
1. Go to https://railway.app
2. Sign up with GitHub
3. Verify your email

**Step 2: Prepare Your Code**
1. Create a `.gitignore` file in `youtube-mp3-api`:
```
node_modules/
.env
```

2. Initialize git:
```cmd
cd C:\Users\jezer\Documents\youtube-mp3-api
git init
git add .
git commit -m "Initial commit"
```

**Step 3: Deploy to Railway**
1. Go to https://railway.app/new
2. Click "Deploy from GitHub repo"
3. Connect your GitHub account
4. Push your code to GitHub first:
   - Create a new repository on GitHub
   - Follow GitHub's instructions to push your code
5. Select your repository in Railway
6. Railway will auto-detect Node.js and deploy
7. Wait 2-3 minutes for deployment

**Step 4: Get Your API URL**
1. In Railway dashboard, click your project
2. Click "Settings"
3. Click "Generate Domain"
4. Copy your URL (e.g., `https://your-app.railway.app`)

**Step 5: Update Flutter App**
In your Flutter app, change:
```dart
const apiUrl = 'https://your-app.railway.app';
```

---

---

### Option 2: Heroku

**Step 1: Install Heroku CLI**
Download from: https://devcenter.heroku.com/articles/heroku-cli

**Step 2: Login**
```cmd
heroku login
```

**Step 3: Create Heroku App**
```cmd
cd C:\Users\jezer\Documents\youtube-mp3-api
heroku create your-app-name
```

**Step 4: Add Buildpacks**
```cmd
heroku buildpacks:add heroku/nodejs
heroku buildpacks:add https://github.com/jonathanong/heroku-buildpack-ffmpeg-latest.git
```

**Step 5: Deploy**
```cmd
git init
git add .
git commit -m "Initial commit"
git push heroku main
```

**Step 6: Get Your URL**
```cmd
heroku open
```

Your API URL will be: `https://your-app-name.herokuapp.com`

---

## Troubleshooting

### Problem: "node is not recognized"
**Solution:** Install Node.js from https://nodejs.org/ and restart Command Prompt

### Problem: "ffmpeg is not recognized"
**Solution:** 
1. Download FFmpeg from https://ffmpeg.org/download.html
2. Extract to `C:\ffmpeg`
3. Add `C:\ffmpeg\bin` to Windows PATH
4. Restart Command Prompt

### Problem: "Cannot find module 'express'"
**Solution:** Run `npm install` in the `youtube-mp3-api` folder

### Problem: "Port 3000 already in use"
**Solution:** 
- Close other programs using port 3000
- Or change port in `server.js`: `const PORT = 3001;`

### Problem: "YouTube download failed"
**Solution:** 
- Update ytdl-core: `npm install ytdl-core@latest`
- YouTube frequently changes their API, this is normal

### Problem: Flutter app can't connect to API
**Solution:**
- Emulator: Use `http://10.0.2.2:3000`
- Real device: Use `http://YOUR_COMPUTER_IP:3000`
- Make sure API is running
- Make sure phone and computer are on same WiFi

### Problem: "CORS error"
**Solution:** The API already has CORS enabled. If you still see errors, check the API console for error messages.

### Problem: Downloads are slow
**Solution:** This is normal. YouTube throttles downloads and conversion takes time. Be patient!

---

## Quick Reference

### Start API (Development)
```cmd
cd C:\Users\jezer\Documents\youtube-mp3-api
npm run dev
```

### Stop API
Press `Ctrl + C` in Command Prompt

### Test API
Open browser: http://localhost:3000

### Update Dependencies
```cmd
npm update
```

### Check for Errors
Look at the Command Prompt where API is running

### API Endpoints

**Health Check:**
```
GET http://localhost:3000/
```

**Get Video Info:**
```
POST http://localhost:3000/api/info
Body: { "url": "https://youtube.com/watch?v=..." }
```

**Download MP3:**
```
POST http://localhost:3000/api/download
Body: { "url": "https://youtube.com/watch?v=..." }
```

---

## Success Checklist

- [ ] Node.js installed and working (`node --version`)
- [ ] FFmpeg installed and working (`ffmpeg -version`)
- [ ] Created `youtube-mp3-api` folder
- [ ] Created `package.json` file
- [ ] Created `server.js` file
- [ ] Ran `npm install` successfully
- [ ] Started API with `npm run dev`
- [ ] Tested in browser (http://localhost:3000)
- [ ] Tested with `test.html`
- [ ] Connected Flutter app to API
- [ ] Tested download from Flutter app
- [ ] (Opti