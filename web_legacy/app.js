/* ============================================================
   SMART REMINDER APP — app.js
   Google Calendar + In-App Call Simulation
   ============================================================ */

// ─── CONFIG ──────────────────────────────────────────────────
const CONFIG = {
  CLIENT_ID: '806444914386-4bir3i00vq0kap2b9rhn169q13m2th5n.apps.googleusercontent.com',
  SCOPES: 'https://www.googleapis.com/auth/calendar', // full access to support deleting events
  TIMEZONE: 'Asia/Kolkata',
  SYNC_INTERVAL_MS: 30 * 60 * 1000,
  REMINDER_BEFORE_MS: 30 * 60 * 1000,
  REPEAT_REMINDER_MS: 5 * 60 * 1000,
  CHECK_INTERVAL_MS: 1000,
};

// ─── STATE ───────────────────────────────────────────────────
const State = {
  user: null,
  accessToken: null,
  tokenClient: null,
  events: [],           // { id, title, startTime (Date), endTime (Date), timezone, reminded30, reminded5, repeatScheduled }
  currentCall: null,
  syncTimer: null,
  checkTimer: null,
  audioCtx: null,
  ringtoneInterval: null,
  lastSync: null,
  focusMode: false,      // Toggle calls off
  activeTab: 'overview', // Track navigation tab
  pendingDeleteId: null, // Track meeting deletion
};

// ─── STORAGE (localStorage) ──────────────────────────────────
const Storage = {
  save() {
    const data = State.events.map(e => ({
      ...e,
      startTime: e.startTime.toISOString(),
      endTime: e.endTime.toISOString(),
    }));
    localStorage.setItem('sra_events', JSON.stringify(data));
    localStorage.setItem('sra_user', JSON.stringify(State.user));
    if (State.lastSync) localStorage.setItem('sra_last_sync', State.lastSync.toISOString());
    localStorage.setItem('sra_focus_mode', State.focusMode ? 'true' : 'false');
  },
  load() {
    try {
      const raw = localStorage.getItem('sra_events');
      if (raw) {
        State.events = JSON.parse(raw).map(e => ({
          ...e,
          startTime: new Date(e.startTime),
          endTime: new Date(e.endTime),
        }));
      }
      const u = localStorage.getItem('sra_user');
      if (u) State.user = JSON.parse(u);
      const ls = localStorage.getItem('sra_last_sync');
      if (ls) State.lastSync = new Date(ls);
      const fm = localStorage.getItem('sra_focus_mode');
      State.focusMode = fm === 'true';
    } catch (_) {}
  },
  upsertEvents(incoming) {
    const now = Date.now();
    incoming.forEach(ev => {
      const idx = State.events.findIndex(e => e.id === ev.id);
      if (idx >= 0) {
        const existing = State.events[idx];
        const msUntil = ev.startTime.getTime() - now;
        // BUG FIX: Reset reminded30 if event is still > 31 min away
        // (handles page reload between syncs — flag stays fresh)
        const shouldResetR30 = msUntil > CONFIG.REMINDER_BEFORE_MS + 60000;
        const shouldResetR5  = msUntil > CONFIG.REPEAT_REMINDER_MS + 60000;
        State.events[idx] = {
          ...ev,
          reminded30:        shouldResetR30 ? false : existing.reminded30,
          reminded5:         shouldResetR5  ? false : existing.reminded5,
          repeatScheduled:   existing.repeatScheduled,
        };
      } else {
        State.events.push({ ...ev, reminded30: false, reminded5: false, repeatScheduled: false });
      }
    });
    // remove stale past events (>2h ago)
    const cutoff = now - 2 * 60 * 60 * 1000;
    State.events = State.events.filter(e => e.startTime.getTime() > cutoff);
    State.events.sort((a, b) => a.startTime - b.startTime);
    this.save();
  }
};

// ─── AUDIO ENGINE ────────────────────────────────────────────
const Audio = {
  init() {
    if (!State.audioCtx) {
      State.audioCtx = new (window.AudioContext || window.webkitAudioContext)();
    }
  },
  playBeep(freq = 880, dur = 0.15, vol = 0.4) {
    this.init();
    const ctx = State.audioCtx;
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.connect(gain);
    gain.connect(ctx.destination);
    osc.type = 'sine';
    osc.frequency.setValueAtTime(freq, ctx.currentTime);
    gain.gain.setValueAtTime(vol, ctx.currentTime);
    gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + dur);
    osc.start(ctx.currentTime);
    osc.stop(ctx.currentTime + dur);
  },
  startRingtone() {
    if (!State.currentCall) return;
    const ev = State.currentCall;
    const tStr = TimeUtils.formatTime(ev.startTime, ev.timezone);
    const speakText = `You have a meeting: ${ev.title} at ${tStr}`;
    
    // Speak immediately and repeat 3 times in total with a gap
    let count = 0;
    const speakLoop = () => {
      if (count < 3 && State.currentCall === ev) {
        this.speakAlert(speakText);
        count++;
        // Repeat after 6 seconds to let previous speech finish
        State.ringtoneInterval = setTimeout(speakLoop, 6000);
      }
    };
    speakLoop();
  },
  stopRingtone() {
    if (State.ringtoneInterval) {
      clearTimeout(State.ringtoneInterval);
      State.ringtoneInterval = null;
    }
    if ('speechSynthesis' in window) {
      window.speechSynthesis.cancel();
    }
  },
  speakAlert(text) {
    if ('speechSynthesis' in window) {
      window.speechSynthesis.cancel();
      const utt = new SpeechSynthesisUtterance(text);
      utt.rate = 0.82; // clear robotic pace
      utt.pitch = 0.75; // low mechanical robotic pitch
      utt.volume = 1.0; // full loud volume
      window.speechSynthesis.speak(utt);
    } else {
      // fallback warning beeps
      [0, 400, 800].forEach(d => setTimeout(() => this.playBeep(660, 0.3, 0.5), d));
    }
  }
};

// Helper to parse string to UTC and convert to local time
function parseAsUtc(timeStr) {
  if (!timeStr) return new Date();
  let utcStr = timeStr;
  // If it's a date-only (all-day event), normalize it to start of day UTC
  if (/^\d{4}-\d{2}-\d{2}$/.test(utcStr)) {
    utcStr += "T00:00:00Z";
  } else if (!utcStr.endsWith('Z') && !/[+-]\d{2}:?\d{2}$/.test(utcStr)) {
    // If it does not specify UTC 'Z' or offset like '+05:30', append 'Z' to treat it as UTC
    utcStr += 'Z';
  }
  const ms = Date.parse(utcStr);
  const eventUtc = new Date(ms);
  // Converted to local system time (native Date object handles this)
  const eventLocal = new Date(eventUtc.getTime());
  return eventLocal;
}

// ─── GOOGLE CALENDAR API ─────────────────────────────────────
const Calendar = {
  async fetchEvents(token) {
    const now = new Date();
    const max = new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000);
    const url = new URL('https://www.googleapis.com/calendar/v3/calendars/primary/events');
    url.searchParams.set('timeMin', now.toISOString());
    url.searchParams.set('timeMax', max.toISOString());
    url.searchParams.set('singleEvents', 'true');
    url.searchParams.set('orderBy', 'startTime');
    url.searchParams.set('maxResults', '100');

    const res = await fetch(url.toString(), {
      headers: { Authorization: `Bearer ${token}` }
    });
    if (!res.ok) throw new Error(`Calendar API error: ${res.status}`);
    const data = await res.json();
    return (data.items || []).map(item => {
      const rawStart = item.start?.dateTime || item.start?.date;
      const rawEnd = item.end?.dateTime || item.end?.date;
      const tz = item.start?.timeZone || CONFIG.TIMEZONE;
      
      const eventLocalStart = parseAsUtc(rawStart);
      const eventLocalEnd = parseAsUtc(rawEnd);

      const meetingLink = item.hangoutLink || 
                          (item.location && item.location.startsWith('http') ? item.location : null) || 
                          item.htmlLink;

      return {
        id: item.id,
        title: item.summary || 'Untitled Event',
        startTime: eventLocalStart,
        endTime: eventLocalEnd,
        rawStart: rawStart,
        rawEnd: rawEnd,
        timezone: tz,
        meetingLink: meetingLink,
        reminded30: false,
        reminded5: false,
        repeatScheduled: false,
      };
    });
  }
};

// ─── TIME UTILS ──────────────────────────────────────────────
const TimeUtils = {
  formatTime(date, tz) {
    try {
      return date.toLocaleTimeString('en-IN', {
        hour: '2-digit', minute: '2-digit',
        timeZone: tz || CONFIG.TIMEZONE,
        hour12: true
      });
    } catch (_) {
      return date.toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit', hour12: true });
    }
  },
  formatDate(date, tz) {
    try {
      return date.toLocaleDateString('en-IN', {
        weekday: 'short', day: 'numeric', month: 'short',
        timeZone: tz || CONFIG.TIMEZONE
      });
    } catch (_) {
      return date.toLocaleDateString('en-IN', { weekday: 'short', day: 'numeric', month: 'short' });
    }
  },
  formatDateRange(start, end, tz) {
    return `${this.formatTime(start, tz)} – ${this.formatTime(end, tz)}`;
  },
  getDay(date, tz) {
    try {
      return date.toLocaleDateString('en-IN', { day: 'numeric', timeZone: tz || CONFIG.TIMEZONE });
    } catch (_) { return date.getDate().toString(); }
  },
  getMonth(date, tz) {
    try {
      return date.toLocaleDateString('en-IN', { month: 'short', timeZone: tz || CONFIG.TIMEZONE });
    } catch (_) { return date.toLocaleDateString('en-IN', { month: 'short' }); }
  },
  minutesUntil(date) {
    return Math.round((date.getTime() - Date.now()) / 60000);
  }
};

// ─── UI HELPERS ──────────────────────────────────────────────
const UI = {
  showScreen(id) {
    document.querySelectorAll('.screen').forEach(s => s.classList.remove('active'));
    document.getElementById(id).classList.add('active');
  },
  toast(msg, ms = 3000) {
    const el = document.getElementById('toast');
    el.textContent = msg;
    el.classList.remove('hidden');
    clearTimeout(UI._toastTimer);
    UI._toastTimer = setTimeout(() => el.classList.add('hidden'), ms);
  },
  setSyncState(state) {
    const dot = document.getElementById('sync-dot');
    const label = document.getElementById('sync-label');
    const btn = document.getElementById('sync-now-btn');
    dot.className = 'sync-dot ' + state;
    if (state === 'syncing') {
      label.textContent = 'Syncing…';
      btn.classList.add('spinning');
      btn.disabled = true;
    } else if (state === 'synced') {
      label.textContent = `Last sync: ${TimeUtils.formatTime(State.lastSync, CONFIG.TIMEZONE)}`;
      btn.classList.remove('spinning');
      btn.disabled = false;
    } else {
      label.textContent = 'Last sync: never';
      btn.classList.remove('spinning');
      btn.disabled = false;
    }
  },
  renderEvents() {
    const container = document.getElementById('events-container');
    const empty = document.getElementById('empty-state');
    const countEl = document.getElementById('event-count');

    const now = Date.now();
    const upcoming = State.events.filter(e => e.startTime.getTime() > now - 60000);
    countEl.textContent = `${upcoming.length} event${upcoming.length !== 1 ? 's' : ''}`;

    // remove old cards
    document.querySelectorAll('.meeting-card:not(.meeting-history-card)').forEach(c => c.remove());

    if (upcoming.length === 0) {
      empty.style.display = 'flex';
      return;
    }
    empty.style.display = 'none';

    upcoming.forEach(ev => {
      const mins = TimeUtils.minutesUntil(ev.startTime);
      let statusLabel = '', statusClass = '', cardClass = '';
      if (mins <= 5) { statusLabel = 'NOW'; statusClass = 'soon'; cardClass = 'imminent'; }
      else if (mins <= 30) { statusLabel = `${mins}m away`; statusClass = 'soon'; cardClass = 'imminent'; }
      else if (mins <= 60) { statusLabel = 'Today'; statusClass = 'today'; cardClass = 'upcoming'; }
      else if (mins <= 1440) { statusLabel = 'Today'; statusClass = 'today'; cardClass = ''; }
      else { statusLabel = 'Upcoming'; statusClass = 'later'; cardClass = ''; }

      // Debug: show reminder status
      const reminderStatus = ev.reminded30
        ? (ev.repeatScheduled ? (ev.reminded5 ? '🔔 Both sent' : '🔁 Repeat pending') : '✅ Reminded')
        : (mins <= 30 ? '⏳ Call imminent' : `📞 Call in ${Math.max(0, mins - 30)}m`);

      const card = document.createElement('div');
      card.className = `meeting-card ${cardClass}`;
      card.dataset.evId = ev.id;

      let joinBtnHtml = '';
      if (ev.meetingLink && ev.meetingLink.trim() !== '') {
        joinBtnHtml = `<a href="${ev.meetingLink}" target="_blank" class="btn-join-card">🚀 Join</a>`;
      }

      card.innerHTML = `
        <div class="meeting-date-badge">
          <span class="meeting-month">${TimeUtils.getMonth(ev.startTime, ev.timezone)}</span>
          <span class="meeting-day">${TimeUtils.getDay(ev.startTime, ev.timezone)}</span>
        </div>
        <div class="meeting-info">
          <div class="meeting-title">${escHtml(ev.title)}</div>
          <div class="meeting-time">
            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"></circle><polyline points="12 6 12 12 16 14"></polyline></svg>
            ${TimeUtils.formatDateRange(ev.startTime, ev.endTime, ev.timezone)}
          </div>
          <div class="reminder-debug">${reminderStatus}</div>
          ${ev.agenda ? `<div style="font-size:0.75rem; color:var(--text-dim); margin-top:4px;">📝 ${escHtml(ev.agenda)}</div>` : ''}
        </div>
        <div class="meeting-right-section">
          <div class="time-badge-container">
            <span class="status-badge ${statusClass}">${statusLabel}</span>
            <span class="countdown-text">${mins > 0 ? `in ${mins}m` : 'started'}</span>
          </div>
          <div class="card-buttons-container">
            ${joinBtnHtml}
            <button class="btn-delete-card" onclick="App.confirmDeleteEvent('${ev.id}')" title="Delete meeting">🗑️ Delete</button>
          </div>
        </div>`;
      container.appendChild(card);
    });

    // Automatically render history too
    this.renderHistory();
  },
  renderHistory() {
    const container = document.getElementById('history-container');
    const empty = document.getElementById('history-empty-state');
    const countEl = document.getElementById('history-count');

    const now = Date.now();
    // Past events: startTime <= now
    const past = State.events.filter(e => e.startTime.getTime() <= now);
    if (countEl) countEl.textContent = `${past.length} event${past.length !== 1 ? 's' : ''}`;

    // Clean up old history elements
    document.querySelectorAll('.meeting-history-card').forEach(c => c.remove());

    if (past.length === 0) {
      if (empty) empty.style.display = 'flex';
      return;
    }
    if (empty) empty.style.display = 'none';

    // Show newest past events first
    const sortedPast = [...past].sort((a, b) => b.startTime - a.startTime);

    sortedPast.forEach(ev => {
      const card = document.createElement('div');
      card.className = 'meeting-card meeting-history-card';
      
      let badgeHtml = '';
      if (ev.meetingLink && ev.meetingLink.trim() !== '') {
        badgeHtml = `<a href="${ev.meetingLink}" target="_blank" class="btn-join-card" style="margin-top: 0; box-shadow: none;">🔗 Link</a>`;
      }

      card.innerHTML = `
        <div class="meeting-date-badge" style="opacity: 0.6;">
          <span class="meeting-month">${TimeUtils.getMonth(ev.startTime, ev.timezone)}</span>
          <span class="meeting-day">${TimeUtils.getDay(ev.startTime, ev.timezone)}</span>
        </div>
        <div class="meeting-info" style="opacity: 0.8;">
          <div class="meeting-title" style="text-decoration: line-through; color: var(--text-dim);">${escHtml(ev.title)}</div>
          <div class="meeting-time">
            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"></circle><polyline points="12 6 12 12 16 14"></polyline></svg>
            ${TimeUtils.formatDateRange(ev.startTime, ev.endTime, ev.timezone)}
          </div>
          ${ev.agenda ? `<div style="font-size:0.75rem; color:var(--text-dim); margin-top:4px;">📝 ${escHtml(ev.agenda)}</div>` : ''}
        </div>
        <div class="meeting-right-section" style="opacity: 0.8;">
          <div class="time-badge-container">
            <span class="status-badge later">Completed</span>
          </div>
          <div class="card-buttons-container">
            ${badgeHtml}
          </div>
        </div>`;
      container.appendChild(card);
    });
  }
};

function escHtml(s) {
  return s.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
}

// ─── CALL SCREEN ─────────────────────────────────────────────
const CallScreen = {
  show(event, isRepeat = false) {
    State.currentCall = event;
    const mins = isRepeat ? 5 : 30;
    document.getElementById('call-meeting-title').textContent = event.title;
    document.getElementById('call-meeting-time').textContent =
      TimeUtils.formatDateRange(event.startTime, event.endTime, event.timezone);
    document.getElementById('call-meeting-note').textContent =
      `Starting in ${mins} minute${mins !== 1 ? 's' : ''}`;
    document.getElementById('voice-time').textContent =
      TimeUtils.formatTime(event.startTime, event.timezone);

    document.getElementById('call-actions-main').classList.remove('hidden');
    document.getElementById('call-actions-accepted').classList.add('hidden');

    const rb = document.getElementById('repeat-btn');
    rb.disabled = event.repeatScheduled;
    rb.textContent = event.repeatScheduled
      ? '✅ Repeat already scheduled'
      : '🔁 Repeat Reminder at 5 mins before';

    UI.showScreen('call-screen');
    Audio.startRingtone();
    Particles.startCallParticles();
  }
};

// ─── REMINDER ENGINE ─────────────────────────────────────────
const Reminder = {
  start() {
    if (State.checkTimer) clearInterval(State.checkTimer);
    State.checkTimer = setInterval(() => this.check(), CONFIG.CHECK_INTERVAL_MS);
    this.check(); // run immediately on start
  },
  check() {
    if (State.focusMode) {
      return;
    }
    const nowMs = Date.now();
    const now = new Date(nowMs);
    let callQueued = false;

    State.events.forEach(ev => {
      const eventLocal = ev.startTime; // Local converted Date
      const eventLocalMs = eventLocal.getTime();
      
      // Calculate exact trigger times
      const trigger30Ms = eventLocalMs - CONFIG.REMINDER_BEFORE_MS;
      const trigger5Ms  = eventLocalMs - CONFIG.REPEAT_REMINDER_MS;

      // Compact timezone debug log printed once per minute for clean performance
      if (now.getSeconds() === 0) {
        console.log(`[Timezone Debug Log] "${ev.title}" | Event IST: ${eventLocal.toString()} | Trigger 30m: ${new Date(trigger30Ms).toString()} | Current: ${now.toString()}`);
      }

      // TRIGGER CONDITION 30-min:
      // now >= trigger30Ms AND now < eventLocalMs AND not triggered yet
      if (
        !ev.reminded30 &&
        nowMs >= trigger30Ms &&
        nowMs < eventLocalMs
      ) {
        console.log(`[Reminder] Triggering 30-min call for: ${ev.title} at ${now.toISOString()}`);
        ev.reminded30 = true;
        Storage.save();
        if (!callQueued) {
          callQueued = true;
          CallScreen.show(ev, false);
        }
      }

      // TRIGGER CONDITION 5-min repeat:
      // repeat is scheduled AND now >= trigger5Ms AND now < eventLocalMs AND not triggered yet
      if (
        ev.repeatScheduled &&
        !ev.reminded5 &&
        nowMs >= trigger5Ms &&
        nowMs < eventLocalMs
      ) {
        console.log(`[Reminder] Triggering 5-min repeat call for: ${ev.title} at ${now.toISOString()}`);
        ev.reminded5 = true;
        Storage.save();
        if (!callQueued) {
          callQueued = true;
          CallScreen.show(ev, true);
        }
      }
    });

    // Update countdown timers dynamically every second
    UI.renderEvents();
  }
};

// ─── AUTO SYNC ───────────────────────────────────────────────
const Sync = {
  async perform() {
    if (!State.accessToken) return;
    UI.setSyncState('syncing');
    try {
      const events = await Calendar.fetchEvents(State.accessToken);
      Storage.upsertEvents(events);
      State.lastSync = new Date();
      Storage.save();
      UI.setSyncState('synced');
      UI.renderEvents();
      UI.toast(`✅ Synced ${events.length} events`);
    } catch (err) {
      UI.setSyncState('idle');
      console.error(err);
      // token may be expired — re-request silently
      if (err.message.includes('401') || err.message.includes('403')) {
        App.requestToken(true);
      } else {
        UI.toast('⚠️ Sync failed. Check connection.');
      }
    }
  },
  startAutoSync() {
    if (State.syncTimer) clearInterval(State.syncTimer);
    State.syncTimer = setInterval(() => this.perform(), CONFIG.SYNC_INTERVAL_MS);
  }
};

// ─── STAR FIELD ──────────────────────────────────────────────
const Stars = {
  canvas: null, ctx: null, stars: [], raf: null,
  init() {
    this.canvas = document.getElementById('star-canvas');
    this.ctx = this.canvas.getContext('2d');
    this.resize();
    window.addEventListener('resize', () => this.resize());
    this.spawn();
    this.animate();
  },
  resize() {
    this.canvas.width = window.innerWidth;
    this.canvas.height = window.innerHeight;
  },
  spawn() {
    this.stars = [];
    for (let i = 0; i < 180; i++) {
      this.stars.push({
        x: Math.random() * window.innerWidth,
        y: Math.random() * window.innerHeight,
        r: Math.random() * 1.6 + 0.3,
        speed: Math.random() * 0.25 + 0.05,
        opacity: Math.random() * 0.7 + 0.2,
        twinkle: Math.random() * Math.PI * 2,
      });
    }
  },
  animate() {
    const ctx = this.ctx;
    ctx.clearRect(0, 0, this.canvas.width, this.canvas.height);
    const t = Date.now() / 1000;
    this.stars.forEach(s => {
      s.y += s.speed;
      s.twinkle += 0.02;
      if (s.y > this.canvas.height + 5) { s.y = -5; s.x = Math.random() * this.canvas.width; }
      const op = s.opacity * (0.7 + 0.3 * Math.sin(s.twinkle));
      ctx.beginPath();
      ctx.arc(s.x, s.y, s.r, 0, Math.PI * 2);
      ctx.fillStyle = `rgba(255,255,255,${op})`;
      ctx.fill();
    });
    this.raf = requestAnimationFrame(() => this.animate());
  },
  stop() { if (this.raf) cancelAnimationFrame(this.raf); }
};

// ─── CALL PARTICLES ──────────────────────────────────────────
const Particles = {
  canvas: null, ctx: null, particles: [], raf: null,
  startCallParticles() {
    this.canvas = document.getElementById('call-particles');
    this.ctx = this.canvas.getContext('2d');
    this.canvas.width = window.innerWidth;
    this.canvas.height = window.innerHeight;
    this.particles = [];
    for (let i = 0; i < 60; i++) {
      this.particles.push({
        x: Math.random() * this.canvas.width,
        y: Math.random() * this.canvas.height,
        r: Math.random() * 1.2 + 0.2,
        vx: (Math.random() - 0.5) * 0.4,
        vy: (Math.random() - 0.5) * 0.4,
        op: Math.random() * 0.4 + 0.1,
        color: Math.random() > 0.5 ? '167,139,250' : '56,189,248',
      });
    }
    if (this.raf) cancelAnimationFrame(this.raf);
    this.animate();
  },
  animate() {
    const ctx = this.ctx;
    ctx.clearRect(0, 0, this.canvas.width, this.canvas.height);
    this.particles.forEach(p => {
      p.x += p.vx; p.y += p.vy;
      if (p.x < 0) p.x = this.canvas.width;
      if (p.x > this.canvas.width) p.x = 0;
      if (p.y < 0) p.y = this.canvas.height;
      if (p.y > this.canvas.height) p.y = 0;
      ctx.beginPath();
      ctx.arc(p.x, p.y, p.r, 0, Math.PI * 2);
      ctx.fillStyle = `rgba(${p.color},${p.op})`;
      ctx.fill();
    });
    this.raf = requestAnimationFrame(() => this.animate());
  },
  stop() { if (this.raf) cancelAnimationFrame(this.raf); }
};

// ─── CURSOR GLOW ─────────────────────────────────────────────
function initCursorGlow() {
  const glow = document.getElementById('cursor-glow');
  document.addEventListener('mousemove', e => {
    glow.style.left = e.clientX + 'px';
    glow.style.top = e.clientY + 'px';
  });
}

// ─── MAIN APP ─────────────────────────────────────────────────
const App = {
  init() {
    Storage.load();
    initCursorGlow();
    Stars.init();

    // Focus Mode initial UI setup
    document.getElementById('focus-mode-toggle').checked = State.focusMode;
    document.getElementById('focus-mode-badge').style.display = State.focusMode ? 'inline-block' : 'none';
    this.switchTab('overview');

    // Load Google Identity Services
    const script = document.createElement('script');
    script.src = 'https://accounts.google.com/gsi/client';
    script.onload = () => this.initGsi();
    script.onerror = () => UI.toast('⚠️ Could not load Google Sign-In. Check internet.');
    document.head.appendChild(script);

    // If we had a saved user, show dashboard with cached data
    if (State.user && State.events.length > 0) {
      document.getElementById('user-email').textContent = State.user.email || State.user.name || '';
      UI.renderEvents();
      if (State.lastSync) UI.setSyncState('synced');
    }
  },

  initGsi() {
    State.tokenClient = google.accounts.oauth2.initTokenClient({
      client_id: CONFIG.CLIENT_ID,
      scope: CONFIG.SCOPES,
      callback: (resp) => {
        if (resp.error) { UI.toast('❌ Sign-in failed: ' + resp.error); return; }
        State.accessToken = resp.access_token;
        State.tokenExpiry = Date.now() + 3500 * 1000;
        localStorage.setItem('sra_access_token', State.accessToken);
        localStorage.setItem('sra_token_expiry', State.tokenExpiry.toString());
        this.fetchUserInfo();
      },
    });

    // Check if already signed in with cached user
    if (State.user) {
      // Reload access token if stored and still valid
      const token = localStorage.getItem('sra_access_token');
      const expiry = localStorage.getItem('sra_token_expiry');
      if (token && expiry && Date.now() < parseInt(expiry)) {
        State.accessToken = token;
        State.tokenExpiry = parseInt(expiry);
      }

      UI.showScreen('dashboard-screen');
      document.getElementById('user-email').textContent = State.user.email || State.user.name || '';
      UI.renderEvents();
      Reminder.start();
      Sync.startAutoSync();
    }
  },

  signIn() {
    if (!State.tokenClient) { UI.toast('Google Sign-In not ready yet. Please wait…'); return; }
    State.tokenClient.requestAccessToken({ prompt: 'consent' });
  },

  requestToken(silent = false) {
    if (!State.tokenClient) return;
    State.tokenClient.requestAccessToken({ prompt: silent ? '' : 'consent' });
  },

  async fetchUserInfo() {
    try {
      const res = await fetch('https://www.googleapis.com/oauth2/v3/userinfo', {
        headers: { Authorization: `Bearer ${State.accessToken}` }
      });
      const info = await res.json();
      State.user = { email: info.email, name: info.name };
      Storage.save();
      document.getElementById('user-email').textContent = info.email || info.name || '';
      UI.showScreen('dashboard-screen');
      Stars.stop();
      await Sync.perform();
      Reminder.start();
      Sync.startAutoSync();
    } catch (e) {
      UI.toast('⚠️ Could not fetch user info.');
    }
  },

  async syncNow() {
    if (State.accessToken && State.tokenExpiry && Date.now() < State.tokenExpiry) {
      await Sync.perform();
    } else {
      // Silently request a new token so the user is never prompted again
      UI.toast('Syncing calendar...');
      this.requestToken(true);
    }
  },

  signOut() {
    if (State.tokenClient && State.accessToken) {
      google.accounts.oauth2.revoke(State.accessToken, () => {});
    }
    clearInterval(State.syncTimer);
    clearInterval(State.checkTimer);
    State.user = null;
    State.accessToken = null;
    State.tokenExpiry = null;
    State.events = [];
    localStorage.clear();
    UI.showScreen('landing-screen');
    Stars.init();
    UI.toast('Signed out successfully');
  },

  acceptCall() {
    Audio.stopRingtone();
    document.getElementById('call-actions-main').classList.add('hidden');
    document.getElementById('call-actions-accepted').classList.remove('hidden');

    const t = TimeUtils.formatTime(State.currentCall.startTime, State.currentCall.timezone);
    Audio.speakAlert(`You have a meeting at ${t}`);
  },

  declineCall() {
    Audio.stopRingtone();
    Particles.stop();
    UI.showScreen('dashboard-screen');
    UI.toast('Call declined');
  },

  scheduleRepeat() {
    if (!State.currentCall) return;
    const ev = State.events.find(e => e.id === State.currentCall.id);
    if (ev) {
      ev.repeatScheduled = true;
      ev.reminded5 = false;
      Storage.save();
    }
    document.getElementById('repeat-btn').disabled = true;
    document.getElementById('repeat-btn').textContent = '✅ Repeat scheduled at 5 mins before';
    UI.toast('🔁 Repeat call scheduled for 5 minutes before meeting');
  },

  dismissCall() {
    Audio.stopRingtone();
    Particles.stop();
    UI.showScreen('dashboard-screen');
  },

  // LEFT SIDEBAR TABS SWITCHING
  switchTab(tabName) {
    State.activeTab = tabName;
    
    // Toggle active class on nav buttons
    document.querySelectorAll('.sidebar-item').forEach(btn => btn.classList.remove('active'));
    const btnEl = document.getElementById(`nav-${tabName}`);
    if (btnEl) btnEl.classList.add('active');
    
    // Toggle active class on tab views
    document.querySelectorAll('.tab-view').forEach(view => view.classList.remove('active'));
    const viewEl = document.getElementById(`view-${tabName}`);
    if (viewEl) viewEl.classList.add('active');

    // Make sure lists are fresh
    if (tabName === 'history' || tabName === 'overview') {
      UI.renderEvents();
    }
  },

  // FOCUS MODE TOGGLE
  toggleFocusMode(checked) {
    State.focusMode = checked;
    localStorage.setItem('sra_focus_mode', checked ? 'true' : 'false');
    document.getElementById('focus-mode-badge').style.display = checked ? 'inline-block' : 'none';
    UI.toast(checked ? '🎯 Focus Mode Enabled' : '🎯 Focus Mode Disabled');
  },

  // MEETING DELETION & SYNC WITH GOOGLE CALENDAR
  confirmDeleteEvent(evId) {
    State.pendingDeleteId = evId;
    const modal = document.getElementById('delete-modal');
    modal.classList.remove('hidden');
    
    const confirmBtn = document.getElementById('delete-confirm-btn');
    confirmBtn.onclick = () => this.deleteEvent(evId);
  },

  closeDeleteModal() {
    State.pendingDeleteId = null;
    document.getElementById('delete-modal').classList.add('hidden');
  },

  async deleteEvent(evId) {
    const isManual = evId.startsWith('manual_');

    // 1. Delete locally
    State.events = State.events.filter(e => e.id !== evId);
    Storage.save();
    UI.renderEvents();
    this.closeDeleteModal();

    // 2. ALSO delete from Google Calendar using API if not manual
    if (!isManual && State.accessToken) {
      UI.toast('Deleting from Google Calendar...');
      try {
        const res = await fetch(`https://www.googleapis.com/calendar/v3/calendars/primary/events/${evId}`, {
          method: 'DELETE',
          headers: { Authorization: `Bearer ${State.accessToken}` }
        });
        if (res.ok) {
          UI.toast('🗑️ Event successfully deleted from Google Calendar');
        } else {
          UI.toast(`⚠️ Deleted locally. Sync status: ${res.status}`);
        }
      } catch (err) {
        UI.toast('⚠️ Deleted locally. Google sync connection failed.');
      }
    } else {
      UI.toast('🗑️ Event deleted locally');
    }
  },

  // CALENDAR UNSYNC
  confirmUnsync() {
    document.getElementById('unsync-modal').classList.remove('hidden');
  },

  closeUnsyncModal() {
    document.getElementById('unsync-modal').classList.add('hidden');
  },

  unsyncCalendar() {
    if (State.syncTimer) clearInterval(State.syncTimer);
    if (State.checkTimer) clearInterval(State.checkTimer);
    State.syncTimer = null;
    State.checkTimer = null;

    State.user = null;
    State.accessToken = null;
    State.tokenExpiry = null;
    State.events = [];
    State.lastSync = null;
    State.focusMode = false;

    localStorage.clear();
    
    // Reset toggle & badge
    document.getElementById('focus-mode-toggle').checked = false;
    document.getElementById('focus-mode-badge').style.display = 'none';

    this.closeUnsyncModal();
    this.switchTab('overview');

    UI.showScreen('landing-screen');
    UI.toast('🔌 Calendar unsynced successfully');
    Stars.init();
  },

  // MANUAL EVENT CREATION (Feature 1)
  saveManualEvent(event) {
    event.preventDefault();
    const title = document.getElementById('event-title').value.trim();
    const date = document.getElementById('event-date').value;
    const time = document.getElementById('event-time').value;
    const link = document.getElementById('event-link').value.trim();
    const agenda = document.getElementById('event-agenda').value.trim();

    if (!title || !date || !time) {
      UI.toast('⚠️ Title, Date, and Time are required.');
      return;
    }

    // Construct local date from input values
    const localStart = new Date(`${date}T${time}`);
    if (isNaN(localStart.getTime())) {
      UI.toast('⚠️ Invalid Date/Time inputs.');
      return;
    }

    const localEnd = new Date(localStart.getTime() + 30 * 60 * 1000); // default to 30 mins

    const newEvent = {
      id: 'manual_' + Date.now(),
      title: title,
      startTime: localStart,
      endTime: localEnd,
      meetingLink: link || null,
      agenda: agenda || null,
      source: 'manual',
      timezone: CONFIG.TIMEZONE,
      reminded30: false,
      reminded5: false,
      repeatScheduled: false
    };

    State.events.push(newEvent);
    Storage.save();
    UI.renderEvents();

    document.getElementById('add-event-form').reset();
    this.switchTab('overview');
    UI.toast('📅 Event manually created successfully!');
  }
};

// ─── BOOT ────────────────────────────────────────────────────
document.addEventListener('DOMContentLoaded', () => App.init());
