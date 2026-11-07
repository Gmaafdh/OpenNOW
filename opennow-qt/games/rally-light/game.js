(() => {
  "use strict";

  const SAVE_KEY = "opennow.rallylight.v1";
  const TAU = Math.PI * 2;
  const clamp = (value, low, high) => Math.max(low, Math.min(high, value));
  const lerp = (from, to, amount) => from + (to - from) * amount;
  const random = (low, high) => low + Math.random() * (high - low);
  const pick = (values) => values[Math.floor(Math.random() * values.length)];
  const byId = (id) => document.getElementById(id);

  const cups = [
    {
      name: "First Light",
      place: "THE ROOFTOP",
      rival: "The Wall",
      note: "A patient baseline, built to teach you to read the bounce.",
      palette: ["#69e9f5", "#83a6ff"],
      weather: "CLEAR AIR",
      target: 5,
    },
    {
      name: "Blue Hour",
      place: "GLASS GARDEN",
      rival: "Mira Moon",
      note: "A soft touch can be sharper than a hard hit. Mira knows both.",
      palette: ["#83a6ff", "#d098ff"],
      weather: "MIST RIBBONS",
      target: 5,
    },
    {
      name: "Afterglow",
      place: "OLD OBSERVATORY",
      rival: "Kite 7",
      note: "Kite changes pace whenever you settle into a rhythm.",
      palette: ["#df8cff", "#ff85bd"],
      weather: "FALLING STARS",
      target: 5,
    },
    {
      name: "Voltage",
      place: "NIGHT MARKET",
      rival: "Juniper",
      note: "The market is loud. Juniper's paddle is louder.",
      palette: ["#ff87bd", "#ffc26d"],
      weather: "NEON RAIN",
      target: 5,
    },
    {
      name: "High Tide",
      place: "TIDAL STATION",
      rival: "Saltwater",
      note: "A heavy, low bounce meets a rival who never gives ground.",
      palette: ["#64ded3", "#6eafff"],
      weather: "SEA GLASS",
      target: 5,
    },
    {
      name: "Sunroom",
      place: "ORBITAL GREENHOUSE",
      rival: "Fern",
      note: "Fern's floaty returns make every angle look almost possible.",
      palette: ["#a7e78f", "#55d7c0"],
      weather: "POLLEN GLOW",
      target: 5,
    },
    {
      name: "Last Train",
      place: "MIDNIGHT PLATFORM",
      rival: "Conductor",
      note: "One calm rally at a time. The platform is yours to cross.",
      palette: ["#f6cf77", "#ff8d70"],
      weather: "WARM SPARKS",
      target: 5,
    },
    {
      name: "After Hours",
      place: "THE SKY COURT",
      rival: "The Comet",
      note: "An impossible-looking shot is still only a ball and a line.",
      palette: ["#f4f6ff", "#7fe2ff"],
      weather: "AURORA",
      target: 5,
    },
  ];

  const rivals = [
    {
      name: "The Wall",
      style: "CALM RETURNER",
      reaction: 0.75,
      speed: 0.62,
      read: 0.7,
      reach: 0.94,
      color: "#8bb2c8",
      voice: "A wall is only hard to beat if you hit it.",
    },
    {
      name: "Mira Moon",
      style: "SOFT HANDS",
      reaction: 0.67,
      speed: 0.75,
      read: 0.82,
      reach: 0.86,
      color: "#d6a7ff",
      voice: "Let's see what the light does.",
    },
    {
      name: "Kite 7",
      style: "PACE BREAKER",
      reaction: 0.55,
      speed: 0.88,
      read: 0.91,
      reach: 0.91,
      color: "#ff8ebf",
      voice: "You were starting to get comfortable.",
    },
    {
      name: "Juniper",
      style: "ANGLE HUNTER",
      reaction: 0.46,
      speed: 0.93,
      read: 0.91,
      reach: 0.91,
      color: "#ffc176",
      voice: "There's a gap. I can feel it.",
    },
    {
      name: "Saltwater",
      style: "DEEP DEFENCE",
      reaction: 0.42,
      speed: 0.96,
      read: 0.94,
      reach: 0.98,
      color: "#70dcd5",
      voice: "Stay with the long point.",
    },
    {
      name: "Fern",
      style: "FLOAT SPECIALIST",
      reaction: 0.35,
      speed: 0.94,
      read: 0.97,
      reach: 0.97,
      color: "#a9e89b",
      voice: "Easy does it. Then not.",
    },
    {
      name: "Conductor",
      style: "RHYTHM ENGINEER",
      reaction: 0.29,
      speed: 1.05,
      read: 1.02,
      reach: 0.98,
      color: "#f3cd78",
      voice: "Every beat has a place.",
    },
    {
      name: "The Comet",
      style: "NO QUIET RETURNS",
      reaction: 0.23,
      speed: 1.12,
      read: 1.05,
      reach: 1.0,
      color: "#c2c8ff",
      voice: "Make it a rally worth remembering.",
    },
  ];

  const tips = [
    "A clean return beats a hard return. Watch the ball.",
    "Meet the ball near the edge of your paddle to add angle.",
    "A steady rally earns focus. Spend it when the point gets wild.",
    "The power serve has one charge. Make the first bounce count.",
    "You can move the paddle with WASD, arrows, mouse, or touch.",
    "A point is not lost until the ball passes your paddle.",
    "Aim high, then low. The rival learns your favorite return.",
    "Practice is safe: three clean rallies earn a little shard bonus.",
  ];

  const defaultSave = () => ({
    version: 1,
    unlockedCup: 0,
    cupWins: Array(cups.length).fill(0),
    careerWins: 0,
    careerLosses: 0,
    bestRally: 0,
    bestStreak: 0,
    currentStreak: 0,
    credits: 18,
    colorway: 0,
    bought: [],
    sound: true,
    lastCup: 0,
    completedMatches: 0,
    trainingClaimed: false,
    pending: null,
  });

  const state = {
    save: loadSave(),
    canvas: byId("court"),
    context: byId("court").getContext("2d", { alpha: false }),
    width: 960,
    height: 520,
    scale: 1,
    previousTime: 0,
    animation: 0,
    screen: "home",
    mode: "league",
    cup: 0,
    rivalIndex: 0,
    playerPoints: 0,
    rivalPoints: 0,
    playerSets: 0,
    rivalSets: 0,
    rallies: 0,
    rallyStreak: 0,
    cleanRallies: 0,
    matchReward: 0,
    matchWon: false,
    matchOver: false,
    paused: false,
    overlay: "serve",
    server: "player",
    serveCharge: 1,
    focusCharges: 2,
    focusTime: 0,
    focusUsed: false,
    powerServe: false,
    ball: { x: 0, y: 0, vx: 0, vy: 0, radius: 8, speed: 365, trail: [] },
    player: {
      x: 0,
      y: 0,
      width: 12,
      height: 88,
      targetY: 0,
      velocity: 0,
      hits: 0,
      glow: 0,
    },
    rival: {
      x: 0,
      y: 0,
      width: 12,
      height: 88,
      targetY: 0,
      velocity: 0,
      mood: 0,
      offset: 0,
    },
    particles: [],
    floaters: [],
    sparkles: [],
    shake: 0,
    flash: 0,
    time: 0,
    serveDelay: 0,
    lastTip: -1,
    pointerInside: false,
    keys: new Set(),
    practice: false,
    soundContext: null,
    lastSaveAt: 0,
    mapCup: 0,
    canvasRect: null,
    touchY: null,
  };

  function loadSave() {
    try {
      const value = JSON.parse(localStorage.getItem(SAVE_KEY) || "null");
      if (!value || value.version !== 1) return defaultSave();
      return {
        ...defaultSave(),
        ...value,
        cupWins: Array.from({ length: cups.length }, (_, i) =>
          Math.max(0, Number(value.cupWins?.[i]) || 0),
        ),
        bought: Array.isArray(value.bought) ? value.bought : [],
      };
    } catch (error) {
      console.info("Rallylight starts a fresh local season.", error);
      return defaultSave();
    }
  }

  function saveProgress(force = false) {
    const now = performance.now();
    if (!force && now - state.lastSaveAt < 350) return;
    state.lastSaveAt = now;
    try {
      localStorage.setItem(SAVE_KEY, JSON.stringify(state.save));
      byId("save-status").textContent = "SAVED JUST NOW";
      setTimeout(() => {
        if (byId("save-status")) byId("save-status").textContent = "SAVE READY";
      }, 1100);
    } catch (error) {
      byId("save-status").textContent = "SESSION ONLY";
    }
  }

  function ensureAudio() {
    if (!state.save.sound) return null;
    if (!state.soundContext) {
      const AudioContextType = window.AudioContext || window.webkitAudioContext;
      if (AudioContextType) state.soundContext = new AudioContextType();
    }
    if (state.soundContext?.state === "suspended") state.soundContext.resume();
    return state.soundContext;
  }

  function tone(
    frequency,
    duration = 0.08,
    shape = "sine",
    volume = 0.035,
    endFrequency = null,
  ) {
    const audio = ensureAudio();
    if (!audio) return;
    const oscillator = audio.createOscillator();
    const gain = audio.createGain();
    oscillator.type = shape;
    oscillator.frequency.setValueAtTime(frequency, audio.currentTime);
    if (endFrequency)
      oscillator.frequency.exponentialRampToValueAtTime(
        endFrequency,
        audio.currentTime + duration,
      );
    gain.gain.setValueAtTime(volume, audio.currentTime);
    gain.gain.exponentialRampToValueAtTime(
      0.0001,
      audio.currentTime + duration,
    );
    oscillator.connect(gain);
    gain.connect(audio.destination);
    oscillator.start();
    oscillator.stop(audio.currentTime + duration);
  }

  function showScreen(name) {
    state.screen = name;
    byId("home-screen").classList.toggle("hidden", name !== "home");
    byId("play-screen").classList.toggle("hidden", name !== "play");
    byId("map-screen").classList.toggle("hidden", name !== "map");
    if (name === "home") renderHome();
    if (name === "map") renderLeagueMap();
    if (name === "play") resizeCanvas();
  }

  function renderHome() {
    const ranks = [
      "ROOKIE",
      "RALLY REGULAR",
      "ANGLE ARTIST",
      "TABLE TACTICIAN",
      "COURT LIGHT",
      "LEAGUE LEGEND",
    ];
    const wins = state.save.careerWins;
    const rankIndex = Math.min(ranks.length - 1, Math.floor(wins / 4));
    byId("stat-rank").textContent = ranks[rankIndex];
    byId("stat-wins").textContent = String(wins).padStart(2, "0");
    byId("stat-best").textContent = String(state.save.bestStreak).padStart(
      2,
      "0",
    );
    const current = Math.min(state.save.unlockedCup, cups.length - 1);
    byId("season-caption").textContent =
      `CIRCUIT ${String(current + 1).padStart(2, "0")} · ${cups[current].name.toUpperCase()}`;
    const track = byId("league-track");
    track.replaceChildren();
    cups.forEach((cup, index) => {
      const tick = document.createElement("i");
      tick.className =
        "league-tick" +
        (index < state.save.unlockedCup ? " done" : "") +
        (index === current ? " current" : "");
      tick.title = `${cup.name}: ${state.save.cupWins[index]} wins`;
      track.append(tick);
    });
    byId("play-button").innerHTML = state.save.pending
      ? "RESUME YOUR MATCH <span>↗</span>"
      : "PLAY THE NEXT MATCH <span>↗</span>";
  }

  function renderLeagueMap() {
    byId("map-credits").textContent = state.save.credits;
    const nav = byId("cup-nav");
    nav.replaceChildren();
    cups.forEach((cup, index) => {
      const button = document.createElement("button");
      button.className =
        "cup-item" +
        (index === state.mapCup ? " selected" : "") +
        (index > state.save.unlockedCup ? " locked" : "");
      button.innerHTML = `<i>${index > state.save.unlockedCup ? "·" : String(index + 1).padStart(2, "0")}</i><span>${escapeHtml(cup.name)}</span>`;
      button.disabled = index > state.save.unlockedCup;
      button.addEventListener("click", () => {
        state.mapCup = index;
        renderLeagueMap();
      });
      nav.append(button);
    });
    const cup = cups[state.mapCup];
    const start = state.mapCup * 8;
    const opponentCards = rivals
      .map(
        (rival, index) =>
          `<div class="opponent-card"><span>${avatarGlyph(index)}</span><b>${escapeHtml(rival.name)}</b><small>${escapeHtml(rival.style)}</small></div>`,
      )
      .join("");
    byId("cup-detail").innerHTML =
      `<p class="eyebrow">CIRCUIT ${String(state.mapCup + 1).padStart(2, "0")} · ${escapeHtml(cup.place)}</p><h3>${escapeHtml(cup.name)}</h3><p>${escapeHtml(cup.note)}</p><div class="cup-meta"><span>${cup.target} POINTS TO TAKE A SET</span><span>${escapeHtml(cup.weather)}</span><span>${state.save.cupWins[state.mapCup]} / 8 MATCHES WON</span></div><div class="cup-opponents">${opponentCards}</div><button class="primary-button" id="map-play-button">PLAY THIS CIRCUIT <span>↗</span></button>`;
    byId("map-play-button").addEventListener("click", () =>
      startMatch(
        state.mapCup,
        Math.min(state.save.cupWins[state.mapCup], rivals.length - 1),
      ),
    );
  }

  function escapeHtml(value) {
    return String(value).replace(
      /[&<>"']/g,
      (character) =>
        ({
          "&": "&amp;",
          "<": "&lt;",
          ">": "&gt;",
          '"': "&quot;",
          "'": "&#39;",
        })[character],
    );
  }

  function avatarGlyph(index) {
    return ["◒", "☾", "⌁", "✺", "◌", "❋", "⌖", "✦"][index % 8];
  }

  function resizeCanvas() {
    const rect = state.canvas.getBoundingClientRect();
    if (rect.width < 2 || rect.height < 2) return;
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    state.width = rect.width;
    state.height = rect.height;
    state.scale = dpr;
    state.canvas.width = Math.round(rect.width * dpr);
    state.canvas.height = Math.round(rect.height * dpr);
    state.context.setTransform(dpr, 0, 0, dpr, 0, 0);
    state.canvasRect = rect;
    placePaddles();
    if (!state.ball.x) resetBall();
  }

  function placePaddles() {
    const pad = Math.max(28, state.width * 0.045);
    state.player.x = pad;
    state.rival.x = state.width - pad - state.rival.width;
    state.player.y = clamp(
      state.player.y || state.height * 0.5,
      state.player.height / 2 + 14,
      state.height - state.player.height / 2 - 14,
    );
    state.rival.y = clamp(
      state.rival.y || state.height * 0.5,
      state.rival.height / 2 + 14,
      state.height - state.rival.height / 2 - 14,
    );
    state.player.targetY = state.player.y;
    state.rival.targetY = state.rival.y;
  }

  function resetBall(direction = null) {
    const playerOnServe = state.server === "player";
    const sign = direction ?? (playerOnServe ? 1 : -1);
    state.ball.x = state.width / 2;
    state.ball.y = state.height / 2 + random(-20, 20);
    state.ball.speed = Math.min(670, state.width * 0.39);
    state.ball.vx = sign * state.ball.speed;
    state.ball.vy = random(-0.25, 0.25) * state.ball.speed;
    state.ball.trail = [];
    state.serveDelay = 0;
    state.overlay = "serve";
    state.rallyStreak = 0;
    showOverlay("serve");
  }

  function showOverlay(kind, detail = "") {
    const overlay = byId("court-overlay");
    overlay.classList.remove("dismissed");
    state.overlay = kind;
    if (kind === "serve") {
      const playerServe = state.server === "player";
      byId("overlay-kicker").textContent = state.practice
        ? "PRACTICE · NO SCORE"
        : playerServe
          ? "YOUR SERVE"
          : "RIVAL SERVES";
      byId("overlay-title").textContent = playerServe
        ? "SERVE WHEN YOU'RE READY"
        : `${currentRival().name.toUpperCase()} IS SERVING`;
      byId("overlay-copy").textContent = playerServe
        ? "Move with W/S or ↑/↓. Meet the ball near the paddle edge to shape the return."
        : currentRival().voice;
      byId("overlay-action").textContent = playerServe
        ? "SERVE  ↗"
        : "READY  ↗";
      byId("overlay-action").disabled = false;
    } else if (kind === "point") {
      byId("overlay-kicker").textContent =
        detail === "player" ? "POINT WON" : "POINT LOST";
      byId("overlay-title").textContent =
        detail === "player"
          ? pick([
              "NICE READ.",
              "THAT'S YOURS.",
              "CLEAN ANGLE.",
              "THE CROWD FELT THAT.",
            ])
          : pick(["NEXT BALL.", "RESET YOUR FEET.", "YOU'RE STILL IN IT."]);
      byId("overlay-copy").textContent =
        "Next serve in a moment. Take one breath and pick your line.";
      byId("overlay-action").textContent = "";
      byId("overlay-action").disabled = true;
    }
  }

  function hideOverlay() {
    byId("court-overlay").classList.add("dismissed");
    state.overlay = "none";
  }

  function currentRival() {
    return rivals[clamp(state.rivalIndex, 0, rivals.length - 1)];
  }

  function currentCup() {
    return cups[clamp(state.cup, 0, cups.length - 1)];
  }

  function startMatch(
    cupIndex = state.save.unlockedCup,
    rivalIndex = 0,
    practice = false,
  ) {
    state.mode = practice ? "practice" : "league";
    state.practice = practice;
    state.cup = clamp(cupIndex, 0, cups.length - 1);
    state.rivalIndex = clamp(rivalIndex, 0, rivals.length - 1);
    state.playerPoints = 0;
    state.rivalPoints = 0;
    state.playerSets = 0;
    state.rivalSets = 0;
    state.rallies = 0;
    state.rallyStreak = 0;
    state.cleanRallies = 0;
    state.matchReward = 0;
    state.matchOver = false;
    state.paused = false;
    state.focusCharges = 2 + (state.save.bought.includes("focus+1") ? 1 : 0);
    state.focusTime = 0;
    state.focusUsed = false;
    state.powerServe = false;
    state.serveCharge = 1;
    state.player.hits = 0;
    state.player.height = state.save.bought.includes("long-paddle") ? 104 : 88;
    state.rival.height = 82 + currentRival().reach * 14;
    state.server = Math.random() < 0.5 ? "player" : "rival";
    state.save.lastCup = state.cup;
    state.save.pending = null;
    const cup = currentCup();
    byId("match-cup").textContent =
      `${cup.name.toUpperCase()} CUP · ${cup.place}`;
    byId("match-rival").textContent =
      `VS. ${currentRival().name.toUpperCase()}`;
    byId("match-round").textContent =
      `MATCH ${String(state.save.cupWins[state.cup] + 1).padStart(2, "0")} / 08`;
    byId("rival-name").firstChild.textContent =
      currentRival().name.toUpperCase() + " ";
    byId("score-target").textContent = cup.target;
    byId("tip-text").textContent = pick(tips);
    byId("player-serve").classList.toggle("active", state.server === "player");
    byId("rival-serve").classList.toggle("active", state.server === "rival");
    updateScoreboard();
    showScreen("play");
    resetBall();
    saveProgress(true);
  }

  function resumeMatch() {
    const pending = state.save.pending;
    if (pending && pending.version === 1) {
      startMatch(pending.cup, pending.rivalIndex, pending.practice);
      state.playerPoints = pending.playerPoints || 0;
      state.rivalPoints = pending.rivalPoints || 0;
      state.playerSets = pending.playerSets || 0;
      state.rivalSets = pending.rivalSets || 0;
      state.server = pending.server || "player";
      updateScoreboard();
    } else
      startMatch(
        state.save.unlockedCup,
        state.save.cupWins[state.save.unlockedCup] || 0,
      );
  }

  function snapshotMatch() {
    if (state.practice || state.matchOver) {
      state.save.pending = null;
      return;
    }
    state.save.pending = {
      version: 1,
      cup: state.cup,
      rivalIndex: state.rivalIndex,
      practice: false,
      playerPoints: state.playerPoints,
      rivalPoints: state.rivalPoints,
      playerSets: state.playerSets,
      rivalSets: state.rivalSets,
      server: state.server,
    };
  }

  function updateScoreboard() {
    byId("score-player").textContent = state.playerPoints;
    byId("score-rival").textContent = state.rivalPoints;
    byId("set-score").textContent =
      `SETS ${state.playerSets} — ${state.rivalSets}`;
    byId("player-serve").classList.toggle("active", state.server === "player");
    byId("rival-serve").classList.toggle("active", state.server === "rival");
    byId("focus-count").textContent = state.focusCharges;
    byId("power-count").textContent = state.serveCharge;
    byId("focus-button").disabled =
      state.focusCharges <= 0 || state.focusUsed || state.practice;
    byId("power-button").disabled =
      state.serveCharge <= 0 || state.server !== "player" || state.practice;
    byId("combo-badge").textContent = `RALLY × ${state.rallyStreak}`;
  }

  function serveBall(power = false) {
    if (state.matchOver || state.paused || state.overlay !== "serve") return;
    if (state.server !== "player" && !state.practice) {
      hideOverlay();
      state.ball.x = state.rival.x - state.ball.radius - 2;
      state.ball.y = state.rival.y;
      state.ball.vx = -state.ball.speed;
      state.ball.vy = random(-0.24, 0.24) * state.ball.speed;
      state.server = "player";
      updateScoreboard();
      tone(310, 0.07, "sine");
      return;
    }
    if (power && state.serveCharge > 0 && !state.practice) {
      state.powerServe = true;
      state.serveCharge -= 1;
      state.matchReward += 1;
      state.ball.speed *= 1.28;
      tone(540, 0.18, "triangle", 0.05, 1100);
      byId("power-callout").textContent = "POWER SERVE";
      setTimeout(() => (byId("power-callout").textContent = ""), 800);
    }
    const direction = 1;
    const angle = random(-0.3, 0.3);
    state.ball.vx = direction * state.ball.speed * Math.cos(angle);
    state.ball.vy = state.ball.speed * Math.sin(angle);
    state.ball.x = state.player.x + state.player.width + state.ball.radius + 2;
    state.ball.y = state.player.y;
    state.server = "rival";
    hideOverlay();
    tone(350, 0.07, "sine");
  }

  function toggleFocus() {
    if (
      state.focusCharges <= 0 ||
      state.focusUsed ||
      state.paused ||
      state.matchOver ||
      state.practice
    )
      return;
    state.focusCharges -= 1;
    state.focusUsed = true;
    state.focusTime = 1.8;
    state.matchReward += 1;
    byId("focus-button").classList.add("is-pulsing");
    byId("power-callout").textContent = "FOCUS · TIME SOFTENS";
    setTimeout(() => {
      byId("focus-button").classList.remove("is-pulsing");
      byId("power-callout").textContent = "";
    }, 1000);
    tone(420, 0.36, "sine", 0.035, 840);
    updateScoreboard();
  }

  function setPaddleTarget(clientY) {
    if (!state.canvasRect) return;
    const localY =
      (clientY - state.canvasRect.top) *
      (state.height / state.canvasRect.height);
    state.player.targetY = clamp(
      localY,
      state.player.height / 2 + 12,
      state.height - state.player.height / 2 - 12,
    );
  }

  function moveByKeyboard(dt) {
    let direction = 0;
    if (state.keys.has("ArrowUp") || state.keys.has("KeyW")) direction -= 1;
    if (state.keys.has("ArrowDown") || state.keys.has("KeyS")) direction += 1;
    if (state.touchY !== null) state.player.targetY = state.touchY;
    if (direction) {
      state.player.targetY = clamp(
        state.player.targetY + direction * state.height * 0.92 * dt,
        state.player.height / 2 + 12,
        state.height - state.player.height / 2 - 12,
      );
    }
    const ease = state.pointerInside && !direction ? 0.24 : 0.15;
    state.player.y = lerp(
      state.player.y,
      state.player.targetY,
      1 - Math.pow(1 - ease, dt * 60),
    );
    state.player.velocity =
      (state.player.targetY - state.player.y) / Math.max(dt, 0.01);
  }

  function updateRival(dt) {
    const rival = currentRival();
    const isApproaching = state.ball.vx > 0;
    let destination = state.height / 2;
    if (isApproaching) {
      const travel =
        (state.rival.x - state.ball.x) / Math.max(120, state.ball.vx);
      const predicted = reflectY(
        state.ball.y + state.ball.vy * Math.max(0, travel),
        state.height,
      );
      const learnedBias =
        (state.player.hits % 4 === 0 ? state.rival.mood : 0) * 0.08;
      destination =
        predicted +
        random(-1, 1) * (1 - rival.read) * state.height * 0.48 +
        learnedBias;
    } else {
      destination =
        state.height / 2 +
        Math.sin(state.time * 1.4 + state.rival.mood) * state.height * 0.12;
    }
    destination += state.rival.offset;
    state.rival.targetY = clamp(
      destination,
      state.rival.height / 2 + 12,
      state.height - state.rival.height / 2 - 12,
    );
    const reactionDelay = isApproaching ? rival.reaction : 0.16;
    const speed = state.height * (0.82 + rival.speed * 1.08) * reactionDelay;
    const delta = state.rival.targetY - state.rival.y;
    const move = clamp(delta, -speed * dt, speed * dt);
    state.rival.y += move;
    state.rival.velocity = move / Math.max(dt, 0.01);
    state.rival.mood = lerp(
      state.rival.mood,
      Math.sin(state.time * (0.3 + state.rivalIndex * 0.13)) * 1.5,
      dt * 0.3,
    );
  }

  function reflectY(value, height) {
    const low = 10;
    const span = height - 20;
    const phase = (((value - low) % (span * 2)) + span * 2) % (span * 2);
    return low + (phase <= span ? phase : span * 2 - phase);
  }

  function updateBall(dt) {
    const ball = state.ball;
    if (state.overlay !== "none" || state.matchOver || state.paused) return;
    if (state.focusTime > 0) {
      state.focusTime = Math.max(0, state.focusTime - dt);
      dt *= 0.55;
    }
    ball.trail.unshift({ x: ball.x, y: ball.y, life: 1 });
    if (ball.trail.length > 12) ball.trail.pop();
    ball.x += ball.vx * dt;
    ball.y += ball.vy * dt;
    for (const trail of ball.trail) trail.life *= 0.88;
    if (ball.y - ball.radius < 8) {
      ball.y = 8 + ball.radius;
      ball.vy = Math.abs(ball.vy);
      impact(ball.x, ball.y, "#80efff", 8);
      tone(220, 0.03, "sine", 0.012);
    } else if (ball.y + ball.radius > state.height - 8) {
      ball.y = state.height - 8 - ball.radius;
      ball.vy = -Math.abs(ball.vy);
      impact(ball.x, ball.y, "#80efff", 8);
      tone(220, 0.03, "sine", 0.012);
    }
    paddleCollision(state.player, true);
    paddleCollision(state.rival, false);
    if (ball.x < -ball.radius * 2) awardPoint("rival");
    if (ball.x > state.width + ball.radius * 2) awardPoint("player");
  }

  function paddleCollision(paddle, isPlayer) {
    const ball = state.ball;
    const overlapsX = isPlayer
      ? ball.vx < 0 &&
        ball.x - ball.radius <= paddle.x + paddle.width &&
        ball.x > paddle.x
      : ball.vx > 0 &&
        ball.x + ball.radius >= paddle.x &&
        ball.x < paddle.x + paddle.width;
    if (!overlapsX) return;
    const top = paddle.y - paddle.height / 2;
    const offset = (ball.y - paddle.y) / (paddle.height / 2 + ball.radius);
    if (Math.abs(offset) > 1) return;
    const normalized = clamp(offset, -1, 1);
    const spin = clamp(paddle.velocity / (state.height * 1.6), -0.32, 0.32);
    const angle = normalized * 0.89 + spin;
    const pace = Math.min(
      state.width * 0.78,
      Math.hypot(ball.vx, ball.vy) * 1.045 + state.width * 0.012,
    );
    ball.speed = pace;
    ball.vx = (isPlayer ? 1 : -1) * pace * Math.cos(angle);
    ball.vy = pace * Math.sin(angle);
    ball.x = isPlayer
      ? paddle.x + paddle.width + ball.radius + 1
      : paddle.x - ball.radius - 1;
    paddle.hits += isPlayer ? 1 : 0;
    paddle.glow = 1;
    state.rallies += 1;
    state.rallyStreak += 1;
    state.save.bestRally = Math.max(state.save.bestRally, state.rallyStreak);
    if (state.rallyStreak >= 3) state.cleanRallies += 1;
    state.matchReward += state.rallyStreak > 4 ? 2 : 1;
    state.shake = Math.max(state.shake, 2.5);
    impact(ball.x, ball.y, isPlayer ? "#6be7ff" : currentRival().color, 18);
    tone(isPlayer ? 560 : 430, 0.055, "triangle", 0.035, 780);
    if (
      state.rallyStreak === 4 ||
      state.rallyStreak === 8 ||
      state.rallyStreak === 12
    ) {
      state.focusCharges = Math.min(3, state.focusCharges + 1);
      floatText(
        ball.x,
        ball.y - 24,
        `RALLY ${state.rallyStreak} · FOCUS +1`,
        "#f4cc74",
      );
    }
    if (!isPlayer) state.rival.offset = random(-1, 1) * 16;
    updateScoreboard();
  }

  function awardPoint(winner) {
    if (state.matchOver || state.overlay !== "none") return;
    const playerWon = winner === "player";
    if (playerWon) {
      state.playerPoints += 1;
      state.save.currentStreak += 1;
      state.save.bestStreak = Math.max(
        state.save.bestStreak,
        state.save.currentStreak,
      );
      tone(700, 0.11, "triangle", 0.05, 1100);
      impact(state.width * 0.5, state.height * 0.5, "#9df5d0", 28);
    } else {
      state.rivalPoints += 1;
      state.save.currentStreak = 0;
      tone(170, 0.16, "sine", 0.03, 90);
      impact(state.width * 0.5, state.height * 0.5, "#ff83b8", 18);
    }
    state.rallyStreak = 0;
    state.server = playerWon ? "player" : "rival";
    state.ball.vx = 0;
    state.ball.vy = 0;
    updateScoreboard();
    snapshotMatch();
    saveProgress(true);
    if (state.practice) {
      byId("practice-count").textContent = Math.min(3, state.cleanRallies);
      if (state.cleanRallies >= 3 && !state.save.trainingClaimed) {
        state.save.trainingClaimed = true;
        state.save.credits += 6;
        saveProgress(true);
      }
    }
    const target = currentCup().target;
    const pointDiff = Math.abs(state.playerPoints - state.rivalPoints);
    const setOver =
      (state.playerPoints >= target || state.rivalPoints >= target) &&
      pointDiff >= 2;
    if (setOver) {
      if (state.playerPoints > state.rivalPoints) state.playerSets += 1;
      else state.rivalSets += 1;
      state.playerPoints = 0;
      state.rivalPoints = 0;
      state.focusCharges = Math.min(3, state.focusCharges + 1);
      if (state.playerSets >= 2 || state.rivalSets >= 2) {
        finishMatch(state.playerSets > state.rivalSets);
        return;
      }
    }
    showOverlay("point", winner);
    state.serveDelay = 0.95;
  }

  function finishMatch(won) {
    state.matchOver = true;
    state.matchWon = won;
    if (state.practice) {
      state.save.pending = null;
      saveProgress(true);
      byId("result-kicker").textContent = "PRACTICE COURT · NO LEAGUE SCORE";
      byId("result-title").textContent = "THAT FELT LIKE A REAL RALLY.";
      byId("result-copy").textContent = state.save.trainingClaimed
        ? "Three clean rallies earned a little shard bonus. Come back for another quiet practice whenever you like."
        : "No score, no rush. Come back for another quiet practice whenever you like.";
      byId("reward-row").innerHTML = state.save.trainingClaimed
        ? "<div class=\"reward-chip\">PRACTICE BONUS<b>✧ 6</b></div>"
        : "<div class=\"reward-chip\">NO LEAGUE STATS<b>JUST PRACTICE</b></div>";
      byId("next-button").textContent = "FINISH PRACTICE";
      byId("result-modal").classList.remove("hidden");
      return;
    }
    state.save.completedMatches += 1;
    const cup = state.cup;
    const rival = currentRival();
    const rewards = won
      ? 10 + cup * 3 + Math.floor(state.rallies / 8)
      : 3 + Math.floor(state.rallies / 12);
    state.save.credits += rewards;
    if (won) {
      state.save.careerWins += 1;
      state.save.cupWins[cup] = Math.min(8, state.save.cupWins[cup] + 1);
      state.save.unlockedCup = Math.max(
        state.save.unlockedCup,
        Math.min(cups.length - 1, cup + (state.save.cupWins[cup] >= 4 ? 1 : 0)),
      );
      if (state.save.cupWins[cup] >= 8 && cup < cups.length - 1)
        state.save.unlockedCup = Math.max(state.save.unlockedCup, cup + 1);
      state.save.currentStreak += 1;
      state.save.bestStreak = Math.max(
        state.save.bestStreak,
        state.save.currentStreak,
      );
      tone(740, 0.45, "triangle", 0.045, 1250);
      for (let index = 0; index < 80; index++)
        impact(
          random(0, state.width),
          random(0, state.height),
          pick(["#6be7ff", "#ff82bd", "#f4cc74", "#8af0b2"]),
          1,
        );
    } else {
      state.save.careerLosses += 1;
      state.save.currentStreak = 0;
    }
    state.save.pending = null;
    state.matchReward = rewards;
    saveProgress(true);
    byId("result-kicker").textContent = won
      ? `${cup.name.toUpperCase()} · MATCH WON`
      : "GOOD MATCH · GOOD DATA";
    byId("result-title").textContent = won
      ? pick([
          "A BEAUTIFUL RALLY.",
          "THE LIGHT IS YOURS.",
          "YOU FOUND THE ANGLE.",
          "WHAT A FINISH.",
        ])
      : "THAT WAS A REAL MATCH.";
    byId("result-copy").textContent = won
      ? `${rival.name} smiles and taps their paddle to yours. The next court is already glowing.`
      : `${rival.name} gives you a small nod. The next rally is yours to write.`;
    byId("reward-row").innerHTML =
      `<div class="reward-chip">SEASON SHARDS<b>✧ ${rewards}</b></div><div class="reward-chip">LONGEST RALLY<b>◉ ${state.save.bestRally}</b></div><div class="reward-chip">MATCH STATS<b>${state.rallies} HITS</b></div>`;
    byId("next-button").textContent = won ? "NEXT MATCH  ↗" : "REMATCH  ↗";
    byId("result-modal").classList.remove("hidden");
  }

  function nextMatch() {
    if (state.practice) {
      finishPractice();
      return;
    }
    byId("result-modal").classList.add("hidden");
    if (!state.matchWon) {
      startMatch(state.cup, state.rivalIndex, false);
      return;
    }
    const nextRival = state.rivalIndex + 1;
    if (nextRival >= rivals.length) {
      state.mapCup = Math.min(state.save.unlockedCup, cups.length - 1);
      showScreen("map");
      return;
    }
    startMatch(state.cup, nextRival, false);
  }

  function openModal(id) {
    byId(id).classList.remove("hidden");
  }

  function closeModal(id) {
    byId(id).classList.add("hidden");
  }

  function impact(x, y, color, count = 12) {
    for (let index = 0; index < count; index++) {
      const angle = Math.random() * TAU;
      const speed = random(28, 190);
      state.particles.push({
        x,
        y,
        vx: Math.cos(angle) * speed,
        vy: Math.sin(angle) * speed,
        life: random(0.28, 0.72),
        maxLife: 0.72,
        radius: random(1.1, 3.8),
        color,
      });
    }
    if (state.particles.length > 420)
      state.particles.splice(0, state.particles.length - 420);
  }

  function floatText(x, y, text, color) {
    state.floaters.push({ x, y, text, color, life: 1.05, maxLife: 1.05 });
    if (state.floaters.length > 14) state.floaters.shift();
  }

  function updateEffects(dt) {
    state.time += dt;
    state.shake = Math.max(0, state.shake - dt * 18);
    state.flash = Math.max(0, state.flash - dt * 2.4);
    state.player.glow = Math.max(0, state.player.glow - dt * 2.6);
    for (const particle of state.particles) {
      particle.x += particle.vx * dt;
      particle.y += particle.vy * dt;
      particle.vx *= Math.pow(0.06, dt);
      particle.vy = particle.vy * Math.pow(0.06, dt) + 18 * dt;
      particle.life -= dt;
    }
    state.particles = state.particles.filter((particle) => particle.life > 0);
    for (const floater of state.floaters) {
      floater.y -= dt * 26;
      floater.life -= dt;
    }
    state.floaters = state.floaters.filter((floater) => floater.life > 0);
    for (const sparkle of state.sparkles) sparkle.phase += dt * sparkle.speed;
  }

  function tick(now) {
    const elapsed = state.previousTime
      ? Math.min(0.04, (now - state.previousTime) / 1000)
      : 0;
    state.previousTime = now;
    if (state.screen === "play" && !state.paused && !document.hidden) {
      moveByKeyboard(elapsed);
      updateRival(elapsed);
      updateBall(elapsed);
      updateEffects(elapsed);
      if (state.overlay === "point" && state.serveDelay > 0) {
        state.serveDelay -= elapsed;
        if (state.serveDelay <= 0) {
          state.ball.x = state.width / 2;
          state.ball.y = state.height / 2;
          state.ball.speed = state.width * 0.39;
          resetBall(state.server === "player" ? 1 : -1);
          if (state.server === "rival" && !state.practice) {
            hideOverlay();
            state.ball.x = state.width * 0.62;
            state.ball.vx = -state.ball.speed;
            state.ball.vy = random(-0.22, 0.22) * state.ball.speed;
            state.server = "player";
            updateScoreboard();
          }
        }
      }
      renderCourt();
    } else if (state.screen === "play") {
      updateEffects(elapsed);
      renderCourt();
    }
    state.animation = requestAnimationFrame(tick);
  }

  function drawBackground(ctx) {
    const width = state.width;
    const height = state.height;
    const gradient = ctx.createLinearGradient(0, 0, width, height);
    gradient.addColorStop(0, "#0c2433");
    gradient.addColorStop(0.48, "#081724");
    gradient.addColorStop(1, "#111629");
    ctx.fillStyle = gradient;
    ctx.fillRect(0, 0, width, height);
    const glow = ctx.createRadialGradient(
      width * 0.49,
      height * 0.48,
      8,
      width * 0.49,
      height * 0.48,
      width * 0.63,
    );
    glow.addColorStop(0, "#1b476122");
    glow.addColorStop(1, "#050c1500");
    ctx.fillStyle = glow;
    ctx.fillRect(0, 0, width, height);
    ctx.save();
    ctx.globalAlpha = 0.16;
    ctx.strokeStyle = "#a5d9e9";
    ctx.lineWidth = 1;
    for (let index = 0; index < 24; index++) {
      const x = (((index * 73 + 31) % 997) / 997) * width;
      const y = (((index * 127 + 57) % 991) / 991) * height;
      const twinkle =
        0.35 +
        (Math.sin(state.time * (0.7 + (index % 5) * 0.1) + index) + 1) * 0.26;
      ctx.globalAlpha = twinkle * 0.22;
      ctx.fillRect(x, y, index % 6 === 0 ? 2 : 1, index % 6 === 0 ? 2 : 1);
    }
    ctx.restore();
  }

  function drawCourt(ctx) {
    const width = state.width;
    const height = state.height;
    const insetX = Math.max(26, width * 0.042);
    const insetY = 15;
    const line = "#9bdae432";
    ctx.save();
    ctx.strokeStyle = line;
    ctx.lineWidth = 1;
    ctx.setLineDash([5, 8]);
    ctx.beginPath();
    ctx.moveTo(width / 2, insetY);
    ctx.lineTo(width / 2, height - insetY);
    ctx.stroke();
    ctx.setLineDash([]);
    ctx.strokeStyle = "#6eeaf334";
    ctx.strokeRect(insetX, insetY, width - insetX * 2, height - insetY * 2);
    ctx.strokeStyle = "#6eeaf322";
    for (const ratio of [0.19, 0.34, 0.66, 0.81]) {
      const x = width * ratio;
      ctx.beginPath();
      ctx.moveTo(x, insetY);
      ctx.lineTo(x, height - insetY);
      ctx.stroke();
    }
    ctx.beginPath();
    ctx.arc(width / 2, height / 2, Math.min(42, height * 0.095), 0, TAU);
    ctx.stroke();
    ctx.fillStyle = "#91e6f314";
    ctx.beginPath();
    ctx.arc(width / 2, height / 2, Math.min(42, height * 0.095), 0, TAU);
    ctx.fill();
    ctx.restore();
    const topShade = ctx.createLinearGradient(0, 0, 0, height);
    topShade.addColorStop(0, "#091521aa");
    topShade.addColorStop(0.12, "#09152100");
    topShade.addColorStop(0.88, "#09152100");
    topShade.addColorStop(1, "#091521aa");
    ctx.fillStyle = topShade;
    ctx.fillRect(0, 0, width, height);
  }

  function drawPaddle(ctx, paddle, side) {
    const y = paddle.y - paddle.height / 2;
    const x = paddle.x;
    const color = side === "player" ? "#70edff" : currentRival().color;
    ctx.save();
    ctx.shadowColor = color;
    ctx.shadowBlur = 12 + (side === "player" ? state.player.glow * 20 : 3);
    const gradient = ctx.createLinearGradient(
      x,
      y,
      x + paddle.width,
      y + paddle.height,
    );
    gradient.addColorStop(0, "#ffffff");
    gradient.addColorStop(0.14, color);
    gradient.addColorStop(1, side === "player" ? "#39a8e2" : "#ef6cae");
    ctx.fillStyle = gradient;
    roundRect(ctx, x, y, paddle.width, paddle.height, 7);
    ctx.fill();
    ctx.globalAlpha = 0.48;
    ctx.fillStyle = "#ffffff";
    roundRect(ctx, x + 3, y + 8, 2, paddle.height - 16, 2);
    ctx.fill();
    ctx.restore();
  }

  function drawBall(ctx) {
    const ball = state.ball;
    ball.trail.forEach((tail, index) => {
      ctx.globalAlpha = Math.max(0, tail.life * (1 - index / 14) * 0.32);
      ctx.fillStyle = index % 3 ? "#78e9ff" : "#ffffff";
      ctx.beginPath();
      ctx.arc(tail.x, tail.y, ball.radius * (1 - index / 16), 0, TAU);
      ctx.fill();
    });
    ctx.globalAlpha = 1;
    ctx.save();
    ctx.shadowColor = state.powerServe ? "#ffd477" : "#baf7ff";
    ctx.shadowBlur = state.powerServe ? 36 : 25;
    const gradient = ctx.createRadialGradient(
      ball.x - 2.5,
      ball.y - 3,
      1,
      ball.x,
      ball.y,
      ball.radius * 1.6,
    );
    gradient.addColorStop(0, "#ffffff");
    gradient.addColorStop(0.48, state.powerServe ? "#ffe4a1" : "#a5f5ff");
    gradient.addColorStop(1, state.powerServe ? "#ff9a5e" : "#4ec5ed");
    ctx.fillStyle = gradient;
    ctx.beginPath();
    ctx.arc(ball.x, ball.y, ball.radius, 0, TAU);
    ctx.fill();
    ctx.restore();
  }

  function drawParticles(ctx) {
    for (const particle of state.particles) {
      ctx.globalAlpha = clamp(particle.life / particle.maxLife, 0, 1);
      ctx.fillStyle = particle.color;
      ctx.shadowColor = particle.color;
      ctx.shadowBlur = 9;
      ctx.beginPath();
      ctx.arc(particle.x, particle.y, particle.radius, 0, TAU);
      ctx.fill();
    }
    ctx.globalAlpha = 1;
    ctx.shadowBlur = 0;
    for (const text of state.floaters) {
      ctx.globalAlpha = clamp(text.life / text.maxLife, 0, 1);
      ctx.fillStyle = text.color;
      ctx.font = "800 10px monospace";
      ctx.textAlign = "center";
      ctx.fillText(text.text, text.x, text.y);
    }
    ctx.globalAlpha = 1;
  }

  function roundRect(ctx, x, y, width, height, radius) {
    const r = Math.min(radius, width / 2, height / 2);
    ctx.beginPath();
    ctx.moveTo(x + r, y);
    ctx.arcTo(x + width, y, x + width, y + height, r);
    ctx.arcTo(x + width, y + height, x, y + height, r);
    ctx.arcTo(x, y + height, x, y, r);
    ctx.arcTo(x, y, x + width, y, r);
    ctx.closePath();
  }

  function renderCourt() {
    if (!state.context || state.width < 2) return;
    const ctx = state.context;
    const shakeX = state.shake ? random(-state.shake, state.shake) : 0;
    const shakeY = state.shake ? random(-state.shake, state.shake) : 0;
    ctx.save();
    ctx.translate(shakeX, shakeY);
    drawBackground(ctx);
    drawCourt(ctx);
    drawPaddle(ctx, state.player, "player");
    drawPaddle(ctx, state.rival, "rival");
    drawBall(ctx);
    drawParticles(ctx);
    if (state.focusTime > 0) {
      ctx.fillStyle = `rgba(108,226,245,${0.045 + Math.sin(state.time * 9) * 0.02})`;
      ctx.fillRect(0, 0, state.width, state.height);
    }
    if (state.flash > 0) {
      ctx.fillStyle = `rgba(255,255,255,${state.flash * 0.3})`;
      ctx.fillRect(0, 0, state.width, state.height);
    }
    ctx.restore();
  }

  function pauseMatch() {
    if (state.screen !== "play" || state.matchOver) return;
    state.paused = true;
    snapshotMatch();
    saveProgress(true);
    openModal("pause-modal");
  }

  function resumeMatchFromPause() {
    state.paused = false;
    closeModal("pause-modal");
    state.previousTime = performance.now();
  }

  function finishPractice() {
    closeModal("result-modal");
    state.practice = false;
    state.matchOver = true;
    state.save.pending = null;
    saveProgress(true);
    showScreen("home");
  }

  function bindEvents() {
    byId("play-button").addEventListener("click", resumeMatch);
    byId("training-button").addEventListener("click", () => {
      byId("practice-count").textContent = "0";
      openModal("practice-modal");
    });
    byId("practice-start").addEventListener("click", () => {
      closeModal("practice-modal");
      startMatch(state.save.unlockedCup, 0, true);
    });
    byId("league-button").addEventListener("click", () => {
      state.mapCup = Math.min(state.save.unlockedCup, cups.length - 1);
      showScreen("map");
    });
    byId("home-button").addEventListener("click", () => {
      snapshotMatch();
      saveProgress(true);
      showScreen("home");
    });
    byId("map-home-button").addEventListener("click", () => showScreen("home"));
    byId("overlay-action").addEventListener("click", () => serveBall(false));
    byId("power-button").addEventListener("click", () => serveBall(true));
    byId("focus-button").addEventListener("click", toggleFocus);
    byId("pause-button").addEventListener("click", pauseMatch);
    byId("resume-button").addEventListener("click", resumeMatchFromPause);
    byId("pause-home").addEventListener("click", () => {
      closeModal("pause-modal");
      state.paused = false;
      state.matchOver = true;
      state.save.pending = null;
      saveProgress(true);
      showScreen("home");
    });
    byId("next-button").addEventListener("click", nextMatch);
    byId("result-home").addEventListener("click", () => {
      closeModal("result-modal");
      showScreen("home");
    });
    byId("sound-toggle").addEventListener("click", () => {
      state.save.sound = !state.save.sound;
      byId("sound-toggle").textContent = state.save.sound ? "◖))" : "◖×";
      byId("sound-toggle").title = state.save.sound
        ? "Sound: on"
        : "Sound: off";
      if (state.save.sound) tone(520, 0.1);
      saveProgress(true);
    });
    document
      .querySelectorAll("[data-close]")
      .forEach((button) =>
        button.addEventListener("click", () =>
          closeModal(button.dataset.close),
        ),
      );
    document.addEventListener("keydown", (event) => {
      if (["ArrowUp", "ArrowDown", "Space"].includes(event.code))
        event.preventDefault();
      state.keys.add(event.code);
      if (event.code === "Space") {
        event.preventDefault();
        if (state.overlay === "serve") serveBall(false);
        else if (state.server === "player") serveBall(true);
      }
      if (event.code === "KeyF") toggleFocus();
      if (event.code === "Escape") {
        if (!byId("pause-modal").classList.contains("hidden"))
          resumeMatchFromPause();
        else if (state.screen === "play") pauseMatch();
        else showScreen("home");
      }
    });
    document.addEventListener("keyup", (event) =>
      state.keys.delete(event.code),
    );
    state.canvas.addEventListener("pointermove", (event) => {
      state.pointerInside = true;
      setPaddleTarget(event.clientY);
    });
    state.canvas.addEventListener("pointerenter", () => {
      state.pointerInside = true;
    });
    state.canvas.addEventListener("pointerleave", () => {
      state.pointerInside = false;
    });
    state.canvas.addEventListener("pointerdown", (event) => {
      state.canvas.setPointerCapture?.(event.pointerId);
      setPaddleTarget(event.clientY);
      ensureAudio();
    });
    document.querySelectorAll("[data-move]").forEach((button) => {
      const direction = button.dataset.move === "up" ? -1 : 1;
      button.addEventListener("pointerdown", (event) => {
        event.preventDefault();
        state.touchY = clamp(
          state.player.targetY + direction * state.height * 0.32,
          state.player.height / 2 + 12,
          state.height - state.player.height / 2 - 12,
        );
      });
      ["pointerup", "pointercancel", "pointerleave"].forEach((type) =>
        button.addEventListener(type, () => {
          state.touchY = null;
        }),
      );
    });
    window.addEventListener("resize", resizeCanvas);
    window.addEventListener("storage", (event) => {
      if (event.key === SAVE_KEY) state.save = loadSave();
    });
    window.addEventListener("beforeunload", () => {
      snapshotMatch();
      saveProgress(true);
      cancelAnimationFrame(state.animation);
    });
    document.addEventListener("visibilitychange", () => {
      if (document.hidden && state.screen === "play" && !state.matchOver)
        pauseMatch();
    });
  }

  function boot() {
    bindEvents();
    resizeCanvas();
    renderHome();
    state.animation = requestAnimationFrame(tick);
  }

  boot();
})();
