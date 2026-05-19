# Smart Reminder App

> A web-based Smart Reminder App that syncs Google Calendar and simulates **in-app incoming call alerts** 30 minutes before your meetings — no notifications, no external APIs.

---

## 🚀 How to Run

### Step 1 — Start the Server

You need Node.js installed. Open terminal in the `smart_reminder_app/` folder and run:

```bash
node server.js
```

Then open **http://localhost:8080** in your browser.

---

### Step 2 — Google Cloud Console Setup (REQUIRED)

Your OAuth client must allow this app's origin. Go to:

👉 https://console.cloud.google.com/apis/credentials

1. Click on your OAuth 2.0 Client ID:
   ```
   806444914386-4bir3i00vq0kap2b9rhn169q13m2th5n.apps.googleusercontent.com
   ```

2. Under **"Authorized JavaScript origins"**, add:
   ```
   http://localhost:8080
   ```

3. Under **"Authorized redirect URIs"**, add:
   ```
   http://localhost:8080
   ```

4. Click **Save** and wait ~5 minutes for changes to propagate.

---

## ✅ Features

| Feature | Status |
|---|---|
| Google OAuth Login (calendar.readonly) | ✅ |
| Fetch Google Calendar events | ✅ |
| Correct timezone display (IST) | ✅ |
| Local storage (localStorage) | ✅ |
| Auto-sync every 30 minutes | ✅ |
| Manual "Sync Now" button | ✅ |
| In-app CALL screen 30 min before meeting | ✅ |
| Accept / Decline call | ✅ |
| Repeat reminder at 5 min before | ✅ |
| Looping ringtone (Web Audio API) | ✅ |
| Voice alert: "You have a meeting at [time]" | ✅ |
| Animated star field (landing) | ✅ |
| Cursor glow effect | ✅ |
| Full black theme with glow UI | ✅ |
| Floating call particles | ✅ |

---

## 🔔 How the Call System Works

1. App checks every **30 seconds** for upcoming events
2. If an event starts in **≤ 30 minutes** → Full-screen call screen appears with ringtone
3. **Accept** → Ringtone stops, voice says: *"You have a meeting at [time]"*
4. **Repeat Reminder** → Schedules another call at **5 minutes before**
5. **Decline** → Dismisses the call

---

## 📁 File Structure

```
smart_reminder_app/
├── index.html     ← All screens (Landing, Dashboard, Call)
├── style.css      ← Full black theme, glow effects, animations
├── app.js         ← Auth, Calendar API, Reminders, Audio
├── server.js      ← Simple Node.js static file server
└── README.md      ← This file
```
