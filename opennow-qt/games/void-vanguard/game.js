(() => {
  "use strict";

  const SAVE_KEY = "opennow.voidvanguard.v1";
  const TAU = Math.PI * 2;
  const clamp = (value, min, max) => Math.max(min, Math.min(max, value));
  const lerp = (a, b, t) => a + (b - a) * t;
  const rand = (min, max) => min + Math.random() * (max - min);
  const choice = (values) => values[Math.floor(Math.random() * values.length)];
  const id = (value) => document.getElementById(value);

  const sectors = [
    {
      name: "Lantern Reach",
      short: "LANTERN",
      color: "#70e4f5",
      dark: "#17384c",
      star: "#b8f8ff",
      theme: "relay fields",
      call: "A broken beacon is blinking out beyond the rim.",
    },
    {
      name: "Glasswake",
      short: "GLASSWAKE",
      color: "#8cbcff",
      dark: "#243756",
      star: "#c8e1ff",
      theme: "crystal debris",
      call: "The old ice has started to sing. Something answers.",
    },
    {
      name: "Verdant Drift",
      short: "VERDANT",
      color: "#9bdd99",
      dark: "#233e38",
      star: "#d1f7a8",
      theme: "living nebulae",
      call: "A garden ship is missing among the green clouds.",
    },
    {
      name: "Cinder Belt",
      short: "CINDER",
      color: "#ff9b78",
      dark: "#4a2c31",
      star: "#ffd0a2",
      theme: "ember storms",
      call: "The Cinder Belt has gone quiet. Too quiet.",
    },
    {
      name: "Blue Ruin",
      short: "BLUE RUIN",
      color: "#62c9e8",
      dark: "#163649",
      star: "#a8efff",
      theme: "drowned stations",
      call: "A distress signal is repeating from beneath the blue.",
    },
    {
      name: "Sunken Crown",
      short: "CROWN",
      color: "#f5d277",
      dark: "#403527",
      star: "#fff0bb",
      theme: "solar wreckage",
      call: "A convoy's golden trail ends at an empty crown.",
    },
    {
      name: "Hushline",
      short: "HUSHLINE",
      color: "#c09cff",
      dark: "#32294c",
      star: "#e7ccff",
      theme: "quiet dark matter",
      call: "No sound travels here. The warning still does.",
    },
    {
      name: "Night Orchard",
      short: "ORCHARD",
      color: "#ff82b7",
      dark: "#48253d",
      star: "#ffc0dc",
      theme: "starfruit fields",
      call: "Someone planted a trap among the old orchard lights.",
    },
    {
      name: "The Long Fold",
      short: "LONG FOLD",
      color: "#a38cff",
      dark: "#302e54",
      star: "#d9cbff",
      theme: "folded space",
      call: "The map bends. The signal does not.",
    },
    {
      name: "Homeward",
      short: "HOMEWARD",
      color: "#f4e7b0",
      dark: "#46413d",
      star: "#fff9dc",
      theme: "the last bright mile",
      call: "One final fleet waits between you and the beacon.",
    },
  ];

  const shipModels = [
    {
      id: "wayfarer",
      name: "WAYFARER",
      className: "LIGHT INTERCEPTOR · MK I",
      description:
        "A forgiving all-rounder. A steady pilot can take it anywhere.",
      unlock: 1,
      speed: 250,
      hull: 3,
      fireRate: 0.18,
      damage: 1,
      color: "#7beaff",
      accent: "#becbff",
      wing: 1.0,
      weapon: "twin",
    },
    {
      id: "needle",
      name: "NEEDLE",
      className: "STRIKE FIGHTER · MK II",
      description:
        "A narrow, quick hull with paired side cannons and a hungry boost.",
      unlock: 16,
      speed: 310,
      hull: 2,
      fireRate: 0.14,
      damage: 1,
      color: "#ff9581",
      accent: "#ffe2aa",
      wing: 0.78,
      weapon: "fan",
    },
    {
      id: "bastion",
      name: "BASTION",
      className: "HEAVY GUNSHIP · MK III",
      description:
        "Three hull plates, a broad silhouette, and one very sure answer.",
      unlock: 36,
      speed: 205,
      hull: 4,
      fireRate: 0.25,
      damage: 2,
      color: "#a992ff",
      accent: "#d9cffd",
      wing: 1.26,
      weapon: "heavy",
    },
  ];

  const enemyBook = {
    mote: {
      name: "MOTE",
      hp: 1,
      speed: 74,
      radius: 13,
      points: 100,
      shards: 1,
      fire: 0,
      color: "#ff9b86",
      behavior: "drift",
    },
    skiff: {
      name: "SKIFF",
      hp: 2,
      speed: 98,
      radius: 17,
      points: 180,
      shards: 2,
      fire: 0.8,
      color: "#f3bf83",
      behavior: "sweep",
    },
    wisp: {
      name: "WISP",
      hp: 1,
      speed: 122,
      radius: 12,
      points: 150,
      shards: 1,
      fire: 1.3,
      color: "#c2a3ff",
      behavior: "weave",
    },
    bomber: {
      name: "BOMBER",
      hp: 4,
      speed: 49,
      radius: 22,
      points: 350,
      shards: 3,
      fire: 1.5,
      color: "#ff7c8a",
      behavior: "aim",
    },
    bulwark: {
      name: "BULWARK",
      hp: 7,
      speed: 35,
      radius: 27,
      points: 520,
      shards: 4,
      fire: 1.2,
      color: "#f3a678",
      behavior: "heavy",
    },
    hunter: {
      name: "HUNTER",
      hp: 3,
      speed: 82,
      radius: 18,
      points: 400,
      shards: 3,
      fire: 0.7,
      color: "#90d9b0",
      behavior: "pursue",
    },
    boss: {
      name: "WARDEN",
      hp: 54,
      speed: 34,
      radius: 58,
      points: 4000,
      shards: 18,
      fire: 0.75,
      color: "#ff7f97",
      behavior: "boss",
    },
  };

  const upgrades = [
    {
      key: "hull",
      icon: "▰",
      name: "Reinforced hull",
      detail: "One extra hit point, permanently.",
      base: 24,
      cap: 5,
    },
    {
      key: "cannon",
      icon: "⌁",
      name: "Pulse capacitors",
      detail: "Fire faster and keep a tighter rhythm.",
      base: 28,
      cap: 6,
    },
    {
      key: "plating",
      icon: "◈",
      name: "Ablative plating",
      detail: "Reduce incoming damage on every mission.",
      base: 32,
      cap: 4,
    },
    {
      key: "thruster",
      icon: "➤",
      name: "Vector thrusters",
      detail: "Move and dash farther per second.",
      base: 25,
      cap: 5,
    },
    {
      key: "nova",
      icon: "✹",
      name: "Nova capacitors",
      detail: "Carry one additional emergency nova.",
      base: 45,
      cap: 2,
    },
  ];

  const freshSave = () => ({
    version: 1,
    unlockedLevel: 1,
    highestCleared: 0,
    credits: 30,
    stars: 0,
    bosses: 0,
    bestScore: 0,
    totalScore: 0,
    missionsFlown: 0,
    wins: 0,
    upgrades: { hull: 0, cannon: 0, plating: 0, thruster: 0, nova: 0 },
    ship: "wayfarer",
    shipsUnlocked: ["wayfarer"],
    missionStars: {},
    achievements: [],
    lastLevel: 1,
    sound: true,
    daily: { date: "", claimed: false, streak: 0 },
    pending: null,
  });

  const ui = {
    home: id("home-view"),
    flight: id("flight-view"),
    map: id("map-view"),
    loadout: id("loadout-view"),
    flightCanvas: id("flight-canvas"),
    showcaseCanvas: id("showcase-canvas"),
    bayCanvas: id("bay-canvas"),
  };
  const game = {
    save: loadSave(),
    screen: "home",
    level: 1,
    mission: null,
    state: "briefing",
    paused: false,
    last: 0,
    elapsed: 0,
    width: 960,
    height: 520,
    dpr: 1,
    ctx: null,
    player: null,
    enemies: [],
    bullets: [],
    enemyBullets: [],
    pickups: [],
    particles: [],
    stars: [],
    asteroids: [],
    score: 0,
    combo: 1,
    comboTimer: 0,
    kills: 0,
    spawned: 0,
    spawnClock: 0,
    objectiveCount: 0,
    boss: null,
    bossSpawned: false,
    specialCharges: 1,
    dashCooldown: 0,
    fireClock: 0,
    invulnerable: 0,
    shake: 0,
    levelTime: 0,
    resultTimer: 0,
    touch: { up: false, down: false, left: false, right: false, fire: false },
    keys: new Set(),
    pointer: { active: false, x: 0, y: 0 },
    inputMode: "keyboard",
    shipIndex: 0,
    selectedSector: 0,
    audio: null,
    saveClock: 0,
    checkpointTimer: 0,
    dailyRewarded: false,
  };

  function loadSave() {
    try {
      const data = JSON.parse(localStorage.getItem(SAVE_KEY) || "null");
      if (!data || data.version !== 1) return freshSave();
      const base = freshSave();
      return {
        ...base,
        ...data,
        upgrades: { ...base.upgrades, ...(data.upgrades || {}) },
        missionStars: data.missionStars || {},
        achievements: Array.isArray(data.achievements) ? data.achievements : [],
        shipsUnlocked: Array.isArray(data.shipsUnlocked)
          ? data.shipsUnlocked
          : ["wayfarer"],
      };
    } catch (error) {
      console.warn("A new flight log was started.", error);
      return freshSave();
    }
  }

  function persist(force = false) {
    if (!force && performance.now() - game.saveClock < 550) return;
    game.saveClock = performance.now();
    try {
      localStorage.setItem(SAVE_KEY, JSON.stringify(game.save));
      id("save-label").textContent = "FLIGHT LOG SAVED";
      setTimeout(() => {
        if (id("save-label")) id("save-label").textContent = "FLIGHT LOG READY";
      }, 1000);
    } catch (_) {
      id("save-label").textContent = "SESSION ONLY";
    }
  }

  function safeText(value) {
    return String(value).replace(
      /[&<>"']/g,
      (c) =>
        ({
          "&": "&amp;",
          "<": "&lt;",
          ">": "&gt;",
          '"': "&quot;",
          "'": "&#39;",
        })[c],
    );
  }

  function seeded(seed) {
    let value = seed >>> 0;
    return () => {
      value += 0x6d2b79f5;
      let t = value;
      t = Math.imul(t ^ (t >>> 15), t | 1);
      t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
  }

  function missionFor(level) {
    const n = clamp(Math.floor(level), 1, 100);
    const sectorIndex = Math.floor((n - 1) / 10);
    const within = (n - 1) % 10;
    const sector = sectors[sectorIndex];
    const boss = within === 9;
    const waveCount = boss
      ? 8 + sectorIndex
      : 5 + within + Math.floor(sectorIndex / 2);
    const duration = 72 + sectorIndex * 8 + within * 2;
    const modifiers = [
      "CLEAN SKY",
      "ION STATIC",
      "DEBRIS FIELD",
      "LOW VISIBILITY",
      "HOT ENGINES",
      "SPLIT SIGNAL",
      "ECHOES",
      "CROSSWIND",
    ];
    const objective = boss
      ? "DEFEAT THE SECTOR WARDEN"
      : [
          "CLEAR THE HOSTILES",
          "PROTECT THE RELAY",
          "BREAK THE AMBUSH",
          "ESCORT THE BEACON",
          "HOLD THE FLIGHT PATH",
        ][within % 5];
    const rng = seeded(n * 971 + 29);
    const pattern = [
      "formation",
      "sweep",
      "spiral",
      "pincer",
      "drift",
      "stagger",
    ][Math.floor(rng() * 6)];
    const missionNames = [
      "The First Beacon",
      "Pocket of Quiet",
      "A Lantern for Two",
      "Shards in the Current",
      "Soft Signal",
      "The Long Return",
      "Paper Moons",
      "A Little Detour",
      "Small Bright Thing",
      "Warden at the Gate",
    ];
    const title = boss
      ? `Warden ${String(sectorIndex + 1).padStart(2, "0")}: ${sector.name}`
      : missionNames[within] || `Signal ${String(within + 1).padStart(2, "0")}`;
    return {
      level: n,
      sectorIndex,
      within,
      sector,
      boss,
      waveCount,
      duration,
      modifier: modifiers[(n * 3 + sectorIndex) % modifiers.length],
      objective,
      pattern,
      title,
      target: waveCount,
      seed: n * 131 + sectorIndex * 17,
      difficulty: 0.8 + sectorIndex * 0.12 + within * 0.035,
      reward: 9 + sectorIndex * 3 + within,
    };
  }

  function activeShip() {
    return (
      shipModels.find((model) => model.id === game.save.ship) || shipModels[0]
    );
  }

  function currentStats() {
    const ship = activeShip();
    const levels = game.save.upgrades;
    return {
      speed: ship.speed * (1 + levels.thruster * 0.075),
      maxHull: ship.hull + levels.hull,
      fireRate: Math.max(0.085, ship.fireRate * Math.pow(0.91, levels.cannon)),
      damage: ship.damage,
      plating: levels.plating,
      dashCooldown: Math.max(1.9, 4.1 - levels.thruster * 0.28),
      novaCharges: 1 + levels.nova,
    };
  }

  function setScreen(name) {
    game.screen = name;
    for (const [key, element] of Object.entries({
      home: ui.home,
      flight: ui.flight,
      map: ui.map,
      loadout: ui.loadout,
    }))
      element.classList.toggle("hidden", key !== name);
    if (name === "home") renderHome();
    if (name === "map") renderMap();
    if (name === "loadout") renderLoadout();
    if (name === "flight") resizeFlight();
  }

  function renderHome() {
    id("credits").textContent = game.save.credits;
    id("campaign-progress").textContent = `${game.save.highestCleared} / 100`;
    id("campaign-fill").style.width = `${game.save.highestCleared}%`;
    const next = missionFor(game.save.unlockedLevel);
    id("sector-caption").textContent =
      `SECTOR ${String(next.sectorIndex + 1).padStart(2, "0")} · ${next.sector.name.toUpperCase()}`;
    id("pilot-rank").textContent = pilotRank();
    id("medal-stars").textContent = game.save.stars;
    id("medal-bosses").textContent = game.save.bosses;
    id("medal-highscore").textContent =
      game.save.bestScore.toLocaleString("en-US");
    id("next-mission-title").textContent = next.title.toUpperCase();
    id("next-mission-copy").textContent = next.sector.call;
    id("next-mission-sector").textContent =
      `SECTOR ${String(next.sectorIndex + 1).padStart(2, "0")}`;
    id("continue-button").innerHTML = game.save.pending
      ? "RESUME FLIGHT <span>↗</span>"
      : `LAUNCH MISSION ${String(game.save.unlockedLevel).padStart(2, "0")} <span>↗</span>`;
    drawShowcase();
  }

  function pilotRank() {
    const clear = game.save.highestCleared;
    if (clear >= 100) return "BEACON KEEPER";
    if (clear >= 80) return "FOLD WALKER";
    if (clear >= 60) return "ORCHARD ACE";
    if (clear >= 40) return "SECTOR CAPTAIN";
    if (clear >= 20) return "WING LEADER";
    if (clear >= 5) return "FLIGHT CADET";
    return "CADET";
  }

  function drawShowcase() {
    drawShipOnCanvas(
      ui.showcaseCanvas,
      activeShip(),
      0.5,
      0.5,
      Math.min(ui.showcaseCanvas.clientWidth, ui.showcaseCanvas.clientHeight) *
        0.0019,
      performance.now() / 1000,
      true,
    );
    if (game.screen === "loadout")
      drawShipOnCanvas(
        ui.bayCanvas,
        activeShip(),
        0.5,
        0.52,
        Math.min(ui.bayCanvas.clientWidth, ui.bayCanvas.clientHeight) * 0.0021,
        performance.now() / 1000,
        true,
      );
  }

  function drawShipOnCanvas(canvas, ship, nx, ny, scale, time, showcase) {
    if (!canvas || !canvas.clientWidth || !canvas.clientHeight) return;
    const ratio = Math.min(devicePixelRatio || 1, 2);
    if (
      canvas.width !== Math.round(canvas.clientWidth * ratio) ||
      canvas.height !== Math.round(canvas.clientHeight * ratio)
    ) {
      canvas.width = Math.round(canvas.clientWidth * ratio);
      canvas.height = Math.round(canvas.clientHeight * ratio);
    }
    const ctx = canvas.getContext("2d");
    ctx.setTransform(ratio, 0, 0, ratio, 0, 0);
    const w = canvas.clientWidth,
      h = canvas.clientHeight;
    ctx.clearRect(0, 0, w, h);
    for (let i = 0; i < 55; i++) {
      const x = (((i * 79 + 41) % 997) / 997) * w;
      const y = (((i * 127 + 17) % 991) / 991) * h;
      ctx.globalAlpha = 0.2 + (Math.sin(time * 1.2 + i) + 1) * 0.2;
      ctx.fillStyle = i % 6 === 0 ? ship.color : "#c5cbff";
      ctx.fillRect(x, y, i % 9 === 0 ? 2 : 1, i % 9 === 0 ? 2 : 1);
    }
    ctx.globalAlpha = 1;
    const cx = w * nx,
      cy = h * ny;
    const s = Math.min(w, h) * (showcase ? 0.00135 : 0.00155) * ship.wing;
    drawFighter(
      ctx,
      ship.id,
      cx,
      cy,
      s * 190,
      0,
      time,
      ship.color,
      ship.accent,
      true,
    );
  }

  function beginLevel(level = game.save.unlockedLevel, resume = false) {
    game.level = clamp(level, 1, 100);
    game.mission = missionFor(game.level);
    game.state = "briefing";
    game.paused = false;
    game.elapsed = 0;
    game.checkpointTimer = 0;
    game.levelTime = 0;
    game.score = 0;
    game.kills = 0;
    game.spawned = 0;
    game.spawnClock = 1.5;
    game.objectiveCount = 0;
    game.boss = null;
    game.bossSpawned = false;
    game.enemies = [];
    game.bullets = [];
    game.enemyBullets = [];
    game.pickups = [];
    game.particles = [];
    game.combo = 1;
    game.comboTimer = 0;
    game.shake = 0;
    game.invulnerable = 1.25;
    game.dashCooldown = 0;
    game.fireClock = 0;
    game.specialCharges = currentStats().novaCharges;
    game.dailyRewarded = false;
    const stats = currentStats();
    game.player = {
      x: game.width * 0.19,
      y: game.height * 0.5,
      vx: 0,
      vy: 0,
      radius: game.width * 0.027,
      hull: stats.maxHull,
      maxHull: stats.maxHull,
      special: game.specialCharges,
      dash: 0,
      weaponFlash: 0,
      shieldPulse: 0,
      damageBlink: 0,
      trail: [],
      aim: 0,
    };
    seedEnvironment(game.mission.seed);
    id("flight-sector").textContent =
      `SECTOR ${String(game.mission.sectorIndex + 1).padStart(2, "0")} · ${game.mission.sector.name.toUpperCase()}`;
    id("flight-title").textContent = game.mission.title.toUpperCase();
    id("flight-level").textContent =
      `MISSION ${String(game.level).padStart(2, "0")} / 100`;
    id("objective-text").textContent = game.mission.objective;
    id("boss-bar").classList.toggle("hidden", !game.mission.boss);
    id("boss-name").textContent =
      `SECTOR ${game.mission.sectorIndex + 1} WARDEN`;
    id("message-kicker").textContent =
      `MISSION ${String(game.level).padStart(2, "0")} · ${game.mission.sector.short}`;
    id("message-title").textContent = resume
      ? "THE SIGNAL IS STILL OPEN."
      : game.mission.boss
        ? "WARDEN INBOUND."
        : "READY, WAYFARER?";
    id("message-copy").textContent =
      `${game.mission.modifier} · ${game.mission.objective}. Move with WASD or arrows. Hold Space to fire; Shift to dash.`;
    id("message-action").textContent = resume
      ? "RESUME FLIGHT"
      : "BEGIN FLIGHT";
    updateHud();
    setScreen("flight");
    id("stage-message").classList.remove("dismissed");
    game.state = "briefing";
    if (resume) id("message-title").textContent = "CHECKPOINT RESTORED.";
    if (game.ctx) paintFlight();
  }

  function seedEnvironment(seed) {
    const random = seeded(seed);
    game.stars = Array.from({ length: 150 }, (_, i) => ({
      x: random() * game.width,
      y: random() * game.height,
      z: 0.2 + random() * 0.8,
      size: 0.4 + random() * 1.8,
      phase: random() * TAU,
      hue: i % 17 === 0,
    }));
    game.asteroids = Array.from(
      { length: 14 + game.mission.sectorIndex * 2 },
      (_, i) => ({
        x: random() * game.width,
        y: random() * game.height,
        radius: 7 + random() * (10 + game.mission.sectorIndex),
        rotation: random() * TAU,
        spin: (random() - 0.5) * 0.22,
        detail: random(),
        color: game.mission.sector.color,
      }),
    );
  }

  function resizeFlight() {
    const canvas = ui.flightCanvas;
    if (!canvas || canvas.clientWidth < 2 || canvas.clientHeight < 2) return;
    const ratio = Math.min(devicePixelRatio || 1, 2);
    const oldW = game.width,
      oldH = game.height;
    game.width = canvas.clientWidth;
    game.height = canvas.clientHeight;
    game.dpr = ratio;
    canvas.width = Math.round(game.width * ratio);
    canvas.height = Math.round(game.height * ratio);
    game.ctx = canvas.getContext("2d", { alpha: false });
    game.ctx.setTransform(ratio, 0, 0, ratio, 0, 0);
    if (game.player) {
      game.player.x = (game.player.x / oldW) * game.width;
      game.player.y = (game.player.y / oldH) * game.height;
      game.player.radius = game.width * 0.027;
    }
    for (const object of [
      ...game.enemies,
      ...game.bullets,
      ...game.enemyBullets,
      ...game.pickups,
    ]) {
      object.x = (object.x / oldW) * game.width;
      object.y = (object.y / oldH) * game.height;
    }
    if (game.mission) seedEnvironment(game.mission.seed);
  }

  function startFlight() {
    if (game.state !== "briefing") return;
    game.state = "playing";
    id("stage-message").classList.add("dismissed");
    game.last = performance.now();
    startAudio();
    persist(true);
  }

  function resumePending() {
    const pending = game.save.pending;
    beginLevel(pending?.level || game.save.unlockedLevel, Boolean(pending));
    if (!pending) return;
    game.score = pending.score || 0;
    game.kills = pending.kills || 0;
    game.spawned = pending.spawned || 0;
    game.elapsed = pending.elapsed || 0;
    game.player.hull = clamp(
      pending.hull || game.player.maxHull,
      1,
      game.player.maxHull,
    );
    game.player.x = clamp(
      pending.x || game.width * 0.19,
      game.width * 0.08,
      game.width * 0.82,
    );
    game.player.y = clamp(pending.y || game.height * 0.5, 30, game.height - 30);
    game.state = "briefing";
    updateHud();
  }

  function checkpoint() {
    if (game.state !== "playing" || !game.player) return;
    game.save.pending = {
      level: game.level,
      score: game.score,
      kills: game.kills,
      spawned: game.spawned,
      elapsed: game.elapsed,
      hull: game.player.hull,
      x: game.player.x,
      y: game.player.y,
    };
    persist();
  }

  function startAudio() {
    if (!game.save.sound) return;
    if (!game.audio) {
      const Type = window.AudioContext || window.webkitAudioContext;
      if (Type) game.audio = new Type();
    }
    if (game.audio?.state === "suspended") game.audio.resume();
  }

  function beep(
    freq,
    duration = 0.06,
    type = "triangle",
    gainValue = 0.025,
    glide = null,
  ) {
    if (!game.save.sound) return;
    startAudio();
    if (!game.audio) return;
    const oscillator = game.audio.createOscillator();
    const gain = game.audio.createGain();
    oscillator.type = type;
    oscillator.frequency.setValueAtTime(freq, game.audio.currentTime);
    if (glide)
      oscillator.frequency.exponentialRampToValueAtTime(
        glide,
        game.audio.currentTime + duration,
      );
    gain.gain.setValueAtTime(gainValue, game.audio.currentTime);
    gain.gain.exponentialRampToValueAtTime(
      0.0001,
      game.audio.currentTime + duration,
    );
    oscillator.connect(gain);
    gain.connect(game.audio.destination);
    oscillator.start();
    oscillator.stop(game.audio.currentTime + duration);
  }

  function levelEnemies() {
    const level = game.mission.level;
    const available = ["mote", "skiff", "wisp"];
    if (level >= 4) available.push("bomber");
    if (level >= 8) available.push("bulwark");
    if (level >= 12) available.push("hunter");
    if (level % 10 === 0) available.push("hunter", "bomber");
    return available;
  }

  function spawnWave() {
    if (
      game.spawned >= game.mission.waveCount ||
      (game.mission.boss && game.bossSpawned)
    )
      return;
    const remaining = game.mission.waveCount - game.spawned;
    const amount = Math.min(
      remaining,
      1 + Math.floor(game.level / 23),
      choice([1, 2, 2, 3]),
    );
    const pattern = game.mission.pattern;
    for (let i = 0; i < amount; i++) {
      const kind = choice(levelEnemies());
      const metadata = enemyBook[kind];
      const formationOffset =
        pattern === "formation" ? (i - (amount - 1) / 2) * 48 : rand(-70, 70);
      let y = game.height * 0.5 + formationOffset + rand(-30, 30);
      if (pattern === "spiral")
        y = game.height * (0.18 + (i / Math.max(1, amount - 1)) * 0.64);
      if (pattern === "stagger") y = game.height * (((i % 4) + 1) / 5);
      const enemy = {
        id: `${game.level}-${game.spawned}-${i}-${performance.now()}`,
        kind,
        x: game.width + metadata.radius + rand(0, 95),
        y: clamp(y, 35, game.height - 35),
        homeY: y,
        radius:
          metadata.radius *
          (1 + Math.min(0.55, game.mission.sectorIndex * 0.045)),
        hp: Math.ceil(metadata.hp * game.mission.difficulty),
        maxHp: Math.ceil(metadata.hp * game.mission.difficulty),
        speed:
          metadata.speed *
          (1 + game.mission.sectorIndex * 0.065) *
          rand(0.82, 1.13),
        phase: rand(0, TAU),
        fireClock: rand(0.5, 2.1),
        hit: 0,
        score: metadata.points,
        shards: metadata.shards,
        color: metadata.color,
        behavior: metadata.behavior,
        pattern,
        age: 0,
        lane: i,
      };
      game.enemies.push(enemy);
      game.spawned += 1;
    }
    if (
      pattern === "pincer" &&
      game.spawned < game.mission.waveCount &&
      game.enemies.length < 7
    ) {
      const kind = choice(["wisp", "mote"]);
      spawnEnemy(kind, game.width + 50, rand(30, game.height - 30), -1);
      game.spawned += 1;
    }
  }

  function spawnEnemy(kind, x, y, direction = 1) {
    const meta = enemyBook[kind];
    game.enemies.push({
      id: `${game.level}-${Math.random()}`,
      kind,
      x,
      y,
      homeY: y,
      radius: meta.radius,
      hp: Math.ceil(meta.hp * game.mission.difficulty),
      maxHp: Math.ceil(meta.hp * game.mission.difficulty),
      speed: meta.speed * game.mission.difficulty,
      phase: rand(0, TAU),
      fireClock: rand(0.6, 1.6),
      hit: 0,
      score: meta.points,
      shards: meta.shards,
      color: meta.color,
      behavior: meta.behavior,
      age: 0,
      direction,
    });
  }

  function spawnBoss() {
    const bossMeta = enemyBook.boss;
    const health =
      bossMeta.hp + game.mission.sectorIndex * 16 + game.level * 0.32;
    const boss = {
      id: `warden-${game.level}`,
      kind: "boss",
      x: game.width + 110,
      y: game.height / 2,
      homeY: game.height / 2,
      radius: Math.min(76, game.height * 0.15),
      hp: health,
      maxHp: health,
      speed: 36 + game.mission.sectorIndex * 3,
      phase: 0,
      fireClock: 1,
      hit: 0,
      score: bossMeta.points + game.level * 18,
      shards: bossMeta.shards + game.mission.sectorIndex,
      color: game.mission.sector.color,
      behavior: "boss",
      age: 0,
      pattern: game.level % 3,
      stage: 0,
      direction: -1,
    };
    game.enemies.push(boss);
    game.boss = boss;
    game.bossSpawned = true;
    id("boss-name").textContent =
      `WARDEN ${String(game.mission.sectorIndex + 1).padStart(2, "0")}`;
    id("boss-bar").classList.remove("hidden");
    bossCallout("WARDEN SIGNATURE · MATCH ITS PATTERN");
    beep(110, 0.5, "sawtooth", 0.035, 55);
  }

  function bossCallout(text) {
    const message = id("pickup-flash");
    message.textContent = text;
    message.classList.add("active");
    setTimeout(() => message.classList.remove("active"), 380);
  }

  function updateFlight(dt) {
    if (game.state !== "playing" || game.paused) return;
    dt = Math.min(dt, 0.035);
    game.elapsed += dt;
    game.levelTime += dt;
    game.checkpointTimer += dt;
    game.comboTimer = Math.max(0, game.comboTimer - dt);
    if (game.comboTimer <= 0) game.combo = 1;
    game.dashCooldown = Math.max(0, game.dashCooldown - dt);
    game.invulnerable = Math.max(0, game.invulnerable - dt);
    game.player.damageBlink = Math.max(0, game.player.damageBlink - dt);
    game.player.weaponFlash = Math.max(0, game.player.weaponFlash - dt);
    game.player.shieldPulse = Math.max(0, game.player.shieldPulse - dt);
    game.shake = Math.max(0, game.shake - dt * 18);
    movePlayer(dt);
    firePlayer(dt);
    updateStars(dt);
    updateAsteroids(dt);
    updateEnemies(dt);
    updateBullets(dt);
    updatePickups(dt);
    updateParticles(dt);
    collideWorld();
    if (
      game.mission.boss &&
      !game.bossSpawned &&
      game.spawned >= game.mission.waveCount &&
      game.enemies.length === 0
    )
      spawnBoss();
    if (!game.mission.boss && game.spawned < game.mission.waveCount) {
      game.spawnClock -= dt;
      if (game.spawnClock <= 0) {
        spawnWave();
        game.spawnClock =
          Math.max(
            0.42,
            1.7 - game.mission.sectorIndex * 0.07 - game.level * 0.004,
          ) * rand(0.76, 1.2);
      }
    }
    const regularWavesCleared =
      !game.mission.boss &&
      game.spawned >= game.mission.waveCount &&
      game.enemies.length === 0;
    const wardenDefeated =
      game.mission.boss && game.bossSpawned && !game.boss && game.enemies.length === 0;
    if (regularWavesCleared || wardenDefeated) completeLevel();
    if (game.player.hull <= 0) failLevel();
    if (game.checkpointTimer >= 5) {
      game.checkpointTimer = 0;
      checkpoint();
    }
    updateHud();
  }

  function movePlayer(dt) {
    const player = game.player;
    const stats = currentStats();
    const input = readMovement();
    if (game.pointer.active && game.inputMode === "pointer") {
      const dx = game.pointer.x - player.x;
      const dy = game.pointer.y - player.y;
      input.x = clamp(dx / 120, -1, 1);
      input.y = clamp(dy / 95, -1, 1);
    }
    let magnitude = Math.hypot(input.x, input.y);
    if (magnitude > 1) {
      input.x /= magnitude;
      input.y /= magnitude;
      magnitude = 1;
    }
    const targetVx = input.x * stats.speed;
    const targetVy = input.y * stats.speed;
    const acceleration = 1 - Math.pow(0.0008, dt);
    player.vx = lerp(player.vx, targetVx, acceleration);
    player.vy = lerp(player.vy, targetVy, acceleration);
    player.x = clamp(
      player.x + player.vx * dt,
      player.radius + 8,
      game.width - player.radius - 12,
    );
    player.y = clamp(
      player.y + player.vy * dt,
      player.radius + 8,
      game.height - player.radius - 8,
    );
    player.aim = lerp(player.aim, input.y * 0.22, 0.15);
    player.trail.unshift({ x: player.x, y: player.y, life: 0.34 });
    if (player.trail.length > 9) player.trail.pop();
    player.trail.forEach((item) => (item.life -= dt));
    player.trail = player.trail.filter((item) => item.life > 0);
    if (
      game.keys.has("ShiftLeft") ||
      game.keys.has("ShiftRight") ||
      game.touch.dash
    )
      dash();
  }

  function readMovement() {
    const input = { x: 0, y: 0 };
    if (game.keys.has("ArrowLeft") || game.keys.has("KeyA") || game.touch.left)
      input.x -= 1;
    if (
      game.keys.has("ArrowRight") ||
      game.keys.has("KeyD") ||
      game.touch.right
    )
      input.x += 1;
    if (game.keys.has("ArrowUp") || game.keys.has("KeyW") || game.touch.up)
      input.y -= 1;
    if (game.keys.has("ArrowDown") || game.keys.has("KeyS") || game.touch.down)
      input.y += 1;
    const pads = navigator.getGamepads?.() || [];
    const pad = Array.from(pads).find(Boolean);
    if (pad) {
      const x = Math.abs(pad.axes[0] || 0) > 0.18 ? pad.axes[0] : 0;
      const y = Math.abs(pad.axes[1] || 0) > 0.18 ? pad.axes[1] : 0;
      input.x += x;
      input.y += y;
      if (pad.buttons[0]?.pressed) game.touch.fire = true;
      if (pad.buttons[1]?.pressed) dash();
      if (pad.buttons[2]?.pressed) useSpecial();
    }
    return input;
  }

  function dash() {
    const player = game.player;
    if (!player || game.dashCooldown > 0 || game.state !== "playing") return;
    const stats = currentStats();
    let dx = player.vx,
      dy = player.vy;
    if (Math.hypot(dx, dy) < 25) dx = stats.speed;
    const length = Math.max(1, Math.hypot(dx, dy));
    player.x = clamp(
      player.x + (dx / length) * game.width * 0.15,
      player.radius,
      game.width - player.radius,
    );
    player.y = clamp(
      player.y + (dy / length) * game.width * 0.15,
      player.radius,
      game.height - player.radius,
    );
    player.dash = 0.28;
    game.invulnerable = Math.max(game.invulnerable, 0.36);
    game.dashCooldown = stats.dashCooldown;
    game.shake = Math.max(game.shake, 3);
    burst(player.x, player.y, activeShip().color, 20, 160);
    beep(460, 0.12, "sawtooth", 0.025, 920);
  }

  function firePlayer(dt) {
    const firing =
      game.keys.has("Space") ||
      game.keys.has("KeyJ") ||
      game.touch.fire ||
      game.pointer.active;
    if (!firing) return;
    game.fireClock -= dt;
    const stats = currentStats();
    if (game.fireClock > 0) return;
    game.fireClock = stats.fireRate;
    const ship = activeShip();
    const player = game.player;
    const speed = game.width * 0.82;
    const color = ship.color;
    const damage = stats.damage;
    const shoot = (offsetY, angle = 0, radius = 4.2, multiplier = 1) =>
      game.bullets.push({
        x: player.x + player.radius * 0.92,
        y: player.y + offsetY,
        vx: Math.cos(angle) * speed,
        vy: Math.sin(angle) * speed,
        radius,
        damage: damage * multiplier,
        color,
        life: 1.6,
        trail: [],
      });
    if (ship.weapon === "twin") {
      shoot(-8, -0.015);
      shoot(8, 0.015);
    } else if (ship.weapon === "fan") {
      shoot(-8, -0.1, 3.4);
      shoot(0, 0, 4);
      shoot(8, 0.1, 3.4);
    } else {
      shoot(0, 0, 7, 1.25);
    }
    player.weaponFlash = 0.07;
    if (Math.random() < 0.24)
      beep(660 + Math.random() * 80, 0.026, "square", 0.008, 430);
  }

  function useSpecial() {
    if (!game.player || game.state !== "playing" || game.specialCharges <= 0)
      return;
    game.specialCharges -= 1;
    game.player.special = game.specialCharges;
    game.player.shieldPulse = 0.8;
    game.invulnerable = Math.max(game.invulnerable, 0.8);
    const radius = Math.min(game.width, game.height) * 0.68;
    for (const enemy of game.enemies) {
      const distance = Math.hypot(
        enemy.x - game.player.x,
        enemy.y - game.player.y,
      );
      if (distance < radius)
        damageEnemy(enemy, Math.max(3, enemy.maxHp * 0.42), true);
    }
    for (const bullet of game.enemyBullets)
      burst(bullet.x, bullet.y, "#9cf6ff", 2, 45);
    game.enemyBullets = game.enemyBullets.filter(
      (bullet) =>
        Math.hypot(bullet.x - game.player.x, bullet.y - game.player.y) > radius,
    );
    burst(game.player.x, game.player.y, "#a8f5ff", 100, 330);
    game.shake = 13;
    id("pickup-flash").classList.add("active");
    setTimeout(() => id("pickup-flash").classList.remove("active"), 180);
    beep(170, 0.65, "sawtooth", 0.07, 1100);
    updateHud();
  }

  function updateStars(dt) {
    const speed = 42 + game.mission.sectorIndex * 8;
    for (const star of game.stars) {
      star.x -= speed * star.z * dt;
      star.phase += dt * (1 + star.z * 2);
      if (star.x < -2) {
        star.x = game.width + 1;
        star.y = Math.random() * game.height;
      }
    }
  }

  function updateAsteroids(dt) {
    for (const asteroid of game.asteroids) {
      asteroid.x -= (18 + game.mission.sectorIndex * 4) * dt;
      asteroid.rotation += asteroid.spin * dt;
      if (asteroid.x < -asteroid.radius * 2) {
        asteroid.x = game.width + asteroid.radius;
        asteroid.y = rand(0, game.height);
      }
    }
  }

  function updateEnemies(dt) {
    for (const enemy of game.enemies) {
      enemy.age += dt;
      enemy.hit = Math.max(0, enemy.hit - dt * 3);
      if (enemy.kind === "boss") updateBoss(enemy, dt);
      else updateEnemy(enemy, dt);
      if (enemy.x < -enemy.radius * 2 && enemy.kind !== "boss") {
        enemy.x = game.width + enemy.radius;
        enemy.y = clamp(
          enemy.y + rand(-90, 90),
          enemy.radius,
          game.height - enemy.radius,
        );
      }
    }
  }

  function updateEnemy(enemy, dt) {
    const target = game.player;
    const horizontal = enemy.direction === -1 ? -1 : -1;
    enemy.x += horizontal * enemy.speed * dt;
    if (enemy.behavior === "drift")
      enemy.y = enemy.homeY + Math.sin(enemy.age * 2.4 + enemy.phase) * 25;
    if (enemy.behavior === "sweep")
      enemy.y = enemy.homeY + Math.sin(enemy.age * 1.8 + enemy.phase) * 85;
    if (enemy.behavior === "weave")
      enemy.y = enemy.homeY + Math.sin(enemy.age * 4.1 + enemy.phase) * 58;
    if (enemy.behavior === "aim") {
      enemy.y = lerp(
        enemy.y,
        target.y + Math.sin(enemy.age * 2 + enemy.phase) * 30,
        dt * 0.7,
      );
      enemy.fireClock -= dt;
      if (enemy.fireClock <= 0 && enemy.x < game.width * 0.88) {
        enemy.fireClock = rand(1.4, 2.1) / game.mission.difficulty;
        enemyShoot(enemy, "aim");
      }
    }
    if (enemy.behavior === "heavy") {
      enemy.y = enemy.homeY + Math.sin(enemy.age * 0.9 + enemy.phase) * 28;
      enemy.fireClock -= dt;
      if (enemy.fireClock <= 0) {
        enemy.fireClock = 1.6 / game.mission.difficulty;
        enemyShoot(enemy, "fan");
      }
    }
    if (enemy.behavior === "pursue") {
      enemy.y = lerp(enemy.y, target.y, Math.min(1, dt * 0.6));
      enemy.fireClock -= dt;
      if (enemy.fireClock <= 0 && enemy.x < game.width * 0.9) {
        enemy.fireClock = rand(0.9, 1.6);
        enemyShoot(enemy, "aim");
      }
    }
  }

  function updateBoss(boss, dt) {
    if (boss.x > game.width * 0.77) boss.x -= boss.speed * 1.8 * dt;
    else boss.x += Math.sin(game.elapsed * 0.5) * 4 * dt;
    boss.y =
      game.height * 0.5 +
      Math.sin(game.elapsed * (0.8 + game.mission.sectorIndex * 0.05)) *
        game.height *
        0.27;
    const health = boss.hp / boss.maxHp;
    boss.stage = health < 0.33 ? 2 : health < 0.68 ? 1 : 0;
    boss.fireClock -= dt;
    const interval = Math.max(
      0.34,
      1.25 - game.mission.sectorIndex * 0.055 - boss.stage * 0.2,
    );
    if (boss.fireClock <= 0 && boss.x < game.width * 0.9) {
      boss.fireClock = interval;
      const pattern =
        (boss.pattern + boss.stage + Math.floor(boss.age / 6)) % 4;
      if (pattern === 0) bossBurst(boss, 7, Math.PI * 0.5, 0.55, "fan");
      if (pattern === 1) bossBurst(boss, 3, Math.PI * 0.5, 0.22, "aim");
      if (pattern === 2) bossBurst(boss, 5, Math.PI * 0.45, 0.24, "ring");
      if (pattern === 3) bossBurst(boss, 2, Math.PI * 0.08, 0.12, "aim");
      if (boss.stage === 2 && Math.random() < 0.28)
        spawnEnemy("wisp", boss.x - 30, boss.y + rand(-60, 60));
    }
    if (boss.hp <= boss.maxHp * 0.68 && !boss.phaseOne) {
      boss.phaseOne = true;
      bossCallout("WARDEN HULL FRACTURED · PATTERN SHIFT");
      burst(boss.x, boss.y, boss.color, 42, 210);
    }
    if (boss.hp <= boss.maxHp * 0.33 && !boss.phaseTwo) {
      boss.phaseTwo = true;
      bossCallout("CORE EXPOSED · STAY SHARP");
      burst(boss.x, boss.y, "#fff0bc", 64, 260);
    }
    id("boss-hp-label").textContent = `${Math.ceil(health * 100)}%`;
    id("boss-hp-fill").style.width = `${clamp(health * 100, 0, 100)}%`;
  }

  function bossBurst(boss, count, arc, spread, pattern) {
    const angleToPlayer = Math.atan2(
      game.player.y - boss.y,
      game.player.x - boss.x,
    );
    for (let i = 0; i < count; i++) {
      let angle;
      if (pattern === "ring") angle = (i / count) * TAU + game.elapsed * 0.5;
      else angle = angleToPlayer + (i - (count - 1) / 2) * spread;
      enemyProjectile(
        boss.x - boss.radius * 0.45,
        boss.y + rand(-boss.radius * 0.6, boss.radius * 0.6),
        angle,
        120 + game.level * 1.2,
        boss.color,
        pattern === "fan" ? 6 : 5,
      );
    }
    beep(145, 0.06, "sawtooth", 0.012, 100);
  }

  function enemyShoot(enemy, pattern) {
    const angle = Math.atan2(game.player.y - enemy.y, game.player.x - enemy.x);
    if (pattern === "fan") {
      for (const offset of [-0.29, 0, 0.29])
        enemyProjectile(
          enemy.x - enemy.radius * 0.45,
          enemy.y,
          angle + offset,
          142 + game.mission.sectorIndex * 8,
          enemy.color,
          4.5,
        );
    } else
      enemyProjectile(
        enemy.x - enemy.radius * 0.4,
        enemy.y,
        angle,
        156 + game.level * 0.8,
        enemy.color,
        4.7,
      );
  }

  function enemyProjectile(x, y, angle, speed, color, radius) {
    game.enemyBullets.push({
      x,
      y,
      vx: Math.cos(angle) * speed,
      vy: Math.sin(angle) * speed,
      radius,
      color,
      life: 4,
      age: 0,
    });
  }

  function updateBullets(dt) {
    for (const bullet of game.bullets) {
      bullet.x += bullet.vx * dt;
      bullet.y += bullet.vy * dt;
      bullet.life -= dt;
      bullet.trail.unshift({ x: bullet.x, y: bullet.y });
      if (bullet.trail.length > 4) bullet.trail.pop();
      for (const enemy of game.enemies) {
        if (enemy.hp <= 0) continue;
        const dx = enemy.x - bullet.x,
          dy = enemy.y - bullet.y;
        if (dx * dx + dy * dy < (enemy.radius + bullet.radius) ** 2) {
          damageEnemy(enemy, bullet.damage, false);
          bullet.life = 0;
          break;
        }
      }
    }
    game.bullets = game.bullets.filter(
      (bullet) =>
        bullet.life > 0 &&
        bullet.x < game.width + 40 &&
        bullet.y > -30 &&
        bullet.y < game.height + 30,
    );
    for (const bullet of game.enemyBullets) {
      bullet.x += bullet.vx * dt;
      bullet.y += bullet.vy * dt;
      bullet.life -= dt;
      bullet.age += dt;
    }
    game.enemyBullets = game.enemyBullets.filter(
      (bullet) =>
        bullet.life > 0 &&
        bullet.x > -40 &&
        bullet.x < game.width + 40 &&
        bullet.y > -40 &&
        bullet.y < game.height + 40,
    );
    game.enemies = game.enemies.filter((enemy) => enemy.hp > 0);
  }

  function damageEnemy(enemy, damage, special) {
    enemy.hp -= damage;
    enemy.hit = 1;
    game.shake = Math.max(game.shake, enemy.kind === "boss" ? 4 : 1.4);
    burst(
      enemy.x - enemy.radius * 0.25,
      enemy.y + rand(-5, 5),
      enemy.color,
      special ? 5 : 3,
      85,
    );
    if (enemy.hp <= 0) destroyEnemy(enemy);
    else if (enemy.kind !== "boss") beep(370, 0.025, "square", 0.007, 260);
  }

  function destroyEnemy(enemy) {
    enemy.hp = 0;
    game.kills += 1;
    game.objectiveCount += 1;
    game.combo = Math.min(9, game.combo + 1);
    game.comboTimer = 2.8;
    game.score += enemy.score * game.combo;
    game.save.bestScore = Math.max(game.save.bestScore, game.score);
    game.save.totalScore += enemy.score;
    burst(
      enemy.x,
      enemy.y,
      enemy.color,
      enemy.kind === "boss" ? 110 : 22,
      enemy.kind === "boss" ? 300 : 150,
    );
    if (enemy.kind === "boss") {
      game.boss = null;
      game.save.bosses += 1;
      game.enemies = game.enemies.filter((value) => value !== enemy);
      game.enemyBullets = [];
      spawnPickup("shard", enemy.x, enemy.y, enemy.shards + 7);
      game.shake = 18;
      beep(94, 0.8, "sawtooth", 0.07, 900);
      return;
    }
    if (Math.random() < 0.16)
      spawnPickup(
        Math.random() < 0.65 ? "shard" : "repair",
        enemy.x,
        enemy.y,
        enemy.shards,
      );
    beep(260 + Math.random() * 100, 0.09, "triangle", 0.022, 115);
  }

  function spawnPickup(kind, x, y, amount = 1) {
    game.pickups.push({
      kind,
      x,
      y,
      vx: -36,
      vy: rand(-36, 36),
      radius: kind === "repair" ? 10 : 8,
      amount,
      phase: rand(0, TAU),
      life: 12,
    });
  }

  function updatePickups(dt) {
    for (const pickup of game.pickups) {
      pickup.x += pickup.vx * dt;
      pickup.y += pickup.vy * dt;
      pickup.phase += dt * 3;
      pickup.life -= dt;
      pickup.vy = lerp(pickup.vy, (game.player.y - pickup.y) * 0.65, dt * 0.14);
      const dx = pickup.x - game.player.x,
        dy = pickup.y - game.player.y;
      if (Math.hypot(dx, dy) < game.player.radius + pickup.radius + 5) {
        if (pickup.kind === "repair")
          game.player.hull = Math.min(
            game.player.maxHull,
            game.player.hull + 1,
          );
        else {
          game.save.credits += pickup.amount;
          game.score += 50 * pickup.amount;
        }
        pickup.life = 0;
        game.player.shieldPulse = 0.3;
        id("pickup-flash").classList.add("active");
        setTimeout(() => id("pickup-flash").classList.remove("active"), 110);
        beep(pickup.kind === "repair" ? 740 : 1020, 0.15, "sine", 0.035, 1320);
        persist(true);
      }
    }
    game.pickups = game.pickups.filter(
      (pickup) => pickup.life > 0 && pickup.x > -20,
    );
  }

  function collideWorld() {
    const p = game.player;
    for (const enemy of game.enemies) {
      const distance = Math.hypot(enemy.x - p.x, enemy.y - p.y);
      if (distance < enemy.radius + p.radius * 0.62) {
        if (game.invulnerable <= 0)
          hurtPlayer(enemy.kind === "boss" ? 2 : 1, enemy.x, enemy.y);
        if (enemy.kind !== "boss") damageEnemy(enemy, enemy.hp, true);
      }
    }
    if (game.invulnerable <= 0) {
      for (const bullet of game.enemyBullets) {
        if (
          Math.hypot(bullet.x - p.x, bullet.y - p.y) <
          bullet.radius + p.radius * 0.68
        ) {
          hurtPlayer(1, bullet.x, bullet.y);
          bullet.life = 0;
          break;
        }
      }
    }
    game.enemyBullets = game.enemyBullets.filter((bullet) => bullet.life > 0);
    for (const rock of game.asteroids) {
      if (
        Math.hypot(rock.x - p.x, rock.y - p.y) <
          rock.radius + p.radius * 0.42 &&
        game.invulnerable <= 0
      ) {
        hurtPlayer(1, rock.x, rock.y);
        rock.x = -100;
      }
    }
  }

  function hurtPlayer(amount, x, y) {
    if (game.invulnerable > 0 || game.state !== "playing") return;
    const damage = Math.max(1, amount - Math.floor(currentStats().plating / 2));
    game.player.hull -= damage;
    game.player.damageBlink = 0.45;
    game.invulnerable = 0.9;
    game.shake = 10;
    game.combo = Math.max(1, game.combo - 1);
    burst(x, y, "#ff897e", 24, 160);
    beep(120, 0.22, "sawtooth", 0.055, 52);
    updateHud();
    checkpoint();
  }

  function burst(x, y, color, count = 12, speed = 100) {
    for (let i = 0; i < count; i++) {
      const angle = Math.random() * TAU;
      const velocity = rand(speed * 0.18, speed);
      game.particles.push({
        x,
        y,
        vx: Math.cos(angle) * velocity,
        vy: Math.sin(angle) * velocity,
        radius: rand(1, 3.8),
        color,
        life: rand(0.22, 0.85),
        max: 0.85,
        drag: rand(0.93, 0.985),
      });
    }
    if (game.particles.length > 1000)
      game.particles.splice(0, game.particles.length - 1000);
  }

  function updateParticles(dt) {
    for (const particle of game.particles) {
      particle.x += particle.vx * dt;
      particle.y += particle.vy * dt;
      particle.vx *= Math.pow(particle.drag, dt * 60);
      particle.vy *= Math.pow(particle.drag, dt * 60);
      particle.life -= dt;
    }
    game.particles = game.particles.filter((particle) => particle.life > 0);
  }

  function updateHud() {
    if (!game.player) return;
    const hull = id("hull-pips");
    hull.replaceChildren();
    for (let i = 0; i < game.player.maxHull; i++) {
      const pip = document.createElement("i");
      pip.className = "hull-pip" + (i >= game.player.hull ? " empty" : "");
      hull.append(pip);
    }
    id("hull-number").textContent =
      `${String(game.player.hull).padStart(2, "0")} / ${String(game.player.maxHull).padStart(2, "0")}`;
    id("score-number").textContent = String(game.score).padStart(6, "0");
    id("combo-number").textContent = `COMBO × ${game.combo}`;
    id("special-count").textContent = game.specialCharges;
    const progress = game.mission.boss
      ? game.boss
        ? 1 - game.boss.hp / game.boss.maxHp
        : game.bossSpawned
          ? 1
          : 0.45
      : game.kills / game.mission.target;
    id("objective-fill").style.width = `${clamp(progress * 100, 0, 100)}%`;
    id("shield-label").textContent =
      game.invulnerable > 0.15
        ? "SHIELD PHASING"
        : game.player.hull <= 1
          ? "HULL CRITICAL"
          : "SHIELD STABLE";
    id("shield-label").style.color = game.player.hull <= 1 ? "#ff988a" : "";
  }

  function completeLevel() {
    if (game.state !== "playing") return;
    game.state = "result";
    const time = game.levelTime;
    const hullRatio = game.player.hull / game.player.maxHull;
    const stars =
      1 + (hullRatio > 0.55 ? 1 : 0) + (time < game.mission.duration ? 1 : 0);
    const oldStars = game.save.missionStars[game.level] || 0;
    const newStars = Math.max(oldStars, stars);
    const reward =
      game.mission.reward + stars * 3 + Math.floor(game.score / 2200);
    game.save.credits += reward;
    game.save.stars += newStars - oldStars;
    game.save.missionStars[game.level] = newStars;
    game.save.highestCleared = Math.max(game.save.highestCleared, game.level);
    game.save.unlockedLevel = Math.min(
      100,
      Math.max(game.save.unlockedLevel, game.level + 1),
    );
    for (const ship of shipModels) {
      if (
        game.level >= ship.unlock &&
        !game.save.shipsUnlocked.includes(ship.id)
      ) {
        game.save.shipsUnlocked.push(ship.id);
        bossCallout(`NEW HULL BLUEPRINT · ${ship.name}`);
      }
    }
    game.save.wins += 1;
    game.save.missionsFlown += 1;
    game.save.pending = null;
    checkAchievements();
    persist(true);
    showResult(true, stars, reward);
    if (game.mission.boss) {
      burst(game.width * 0.78, game.height * 0.5, "#fff1c0", 120, 340);
      id("boss-bar").classList.add("hidden");
    }
  }

  function failLevel() {
    if (game.state !== "playing") return;
    game.state = "result";
    game.save.pending = null;
    game.save.credits += Math.max(2, Math.floor(game.score / 1500));
    persist(true);
    showResult(false, 0, Math.max(2, Math.floor(game.score / 1500)));
  }

  function showResult(won, stars, reward) {
    id("result-modal").classList.remove("hidden");
    id("result-kicker").textContent = won
      ? `MISSION ${String(game.level).padStart(2, "0")} · LOG UPDATED`
      : "FLIGHT LOG SAVED · TRY AGAIN";
    id("result-emblem").textContent = won ? "✦" : "◈";
    id("result-title").textContent = won
      ? [
          "THE SIGNAL IS HOME.",
          "CLEAN FLIGHT, PILOT.",
          "THE FRONTIER BREATHES.",
        ][game.level % 3]
      : "THE STARS CAN WAIT.";
    id("result-copy").textContent = won
      ? `${game.mission.title} is complete. The next signal is already on your map.`
      : "Your run is safe in the flight log. Tune your ship or try a different line.";
    id("result-summary").innerHTML =
      `<span>SCORE <b>${game.score.toLocaleString("en-US")}</b></span><span>ELAPSED <b>${formatTime(game.levelTime)}</b></span><span>SHARDS <b>✧ ${reward}</b></span>`;
    id("star-awards").innerHTML = [0, 1, 2]
      .map((index) => `<span class="${index < stars ? "earned" : ""}">★</span>`)
      .join("");
    id("result-next").textContent =
      won && game.level < 100
        ? "NEXT MISSION ↗"
        : won
          ? "CAMPAIGN COMPLETE ✦"
          : "RETRY MISSION ↗";
    id("result-next").onclick = () => {
      id("result-modal").classList.add("hidden");
      if (!won) beginLevel(game.level);
      else if (game.level >= 100) setScreen("map");
      else beginLevel(game.level + 1);
    };
    if (game.mission.boss) id("boss-bar").classList.add("hidden");
  }

  function formatTime(value) {
    const seconds = Math.floor(value);
    return `${String(Math.floor(seconds / 60)).padStart(2, "0")}:${String(seconds % 60).padStart(2, "0")}`;
  }

  function checkAchievements() {
    const achievements = [
      ["first-clear", game.save.highestCleared >= 1, "First signal"],
      ["first-boss", game.save.bosses > 0, "Warden breaker"],
      ["ten-clear", game.save.highestCleared >= 10, "Lantern keeper"],
      ["halfway", game.save.highestCleared >= 50, "Halfway home"],
      ["all-clear", game.save.highestCleared >= 100, "Beacon keeper"],
      [
        "three-star",
        Object.values(game.save.missionStars).includes(3),
        "Perfect orbit",
      ],
      ["ship-collector", game.save.shipsUnlocked.length >= 3, "Hangar full"],
      ["shard-hoard", game.save.credits >= 250, "Little fortune"],
    ];
    for (const [key, unlocked, title] of achievements) {
      if (unlocked && !game.save.achievements.includes(key)) {
        game.save.achievements.push(key);
        bossCallout(`FLIGHT HONOR · ${title.toUpperCase()}`);
      }
    }
  }

  function renderMap() {
    const next = game.save.unlockedLevel;
    const currentSector = Math.min(9, Math.floor((next - 1) / 10));
    game.selectedSector = clamp(game.selectedSector, 0, 9);
    const tabs = id("sector-tabs");
    tabs.replaceChildren();
    sectors.forEach((sector, index) => {
      const button = document.createElement("button");
      button.className =
        "sector-tab" +
        (game.selectedSector === index ? " selected" : "") +
        (index > currentSector ? " locked" : "");
      button.disabled = index > currentSector;
      button.innerHTML = `<b>${String(index + 1).padStart(2, "0")} · ${safeText(sector.short)}</b>${Math.min(10, Math.max(0, game.save.highestCleared - index * 10))}/10 CLEAR`;
      button.addEventListener("click", () => {
        game.selectedSector = index;
        renderMap();
      });
      tabs.append(button);
    });
    const grid = id("level-grid");
    grid.replaceChildren();
    for (let i = 1; i <= 100; i++) {
      if (Math.floor((i - 1) / 10) !== game.selectedSector) continue;
      const stars = game.save.missionStars[i] || 0;
      const button = document.createElement("button");
      button.className =
        "level-card" +
        (i <= game.save.highestCleared ? " cleared" : "") +
        (i === game.save.unlockedLevel ? " current" : "") +
        (i <= game.save.unlockedLevel ? " available" : "");
      button.disabled = i > game.save.unlockedLevel;
      button.innerHTML = `${String(i).padStart(2, "0")}${i % 10 === 0 ? "<small>✦ BOSS</small>" : stars ? `<small>${"★".repeat(stars)}</small>` : ""}`;
      button.title = `${missionFor(i).title}${stars ? ` · ${stars} stars` : ""}`;
      button.addEventListener("click", () => beginLevel(i));
      grid.append(button);
    }
    id("map-launch").onclick = () => beginLevel(game.save.unlockedLevel);
  }

  function renderLoadout() {
    id("loadout-credits").textContent = game.save.credits;
    id("credits").textContent = game.save.credits;
    game.shipIndex = Math.max(
      0,
      shipModels.findIndex((ship) => ship.id === game.save.ship),
    );
    const ship = activeShip();
    id("bay-class").textContent = ship.className;
    id("bay-name").textContent = ship.name;
    id("bay-desc").textContent = ship.description;
    id("ship-count").textContent =
      `${String(game.shipIndex + 1).padStart(2, "0")} / ${String(shipModels.length).padStart(2, "0")}`;
    drawShowcase();
    const list = id("upgrade-list");
    list.replaceChildren();
    for (const upgrade of upgrades) {
      const level = game.save.upgrades[upgrade.key] || 0;
      const cost = Math.floor(upgrade.base * Math.pow(1.52, level));
      const card = document.createElement("div");
      card.className = "upgrade-card";
      card.innerHTML = `<span class="upgrade-icon">${upgrade.icon}</span><div><b>${safeText(upgrade.name)} · ${level}/${upgrade.cap}</b><p>${safeText(upgrade.detail)}</p></div><button ${level >= upgrade.cap || game.save.credits < cost ? "disabled" : ""}>${level >= upgrade.cap ? "MAXED" : `✧ ${cost}`}</button>`;
      card
        .querySelector("button")
        .addEventListener("click", () => buyUpgrade(upgrade, cost));
      list.append(card);
    }
    const unlocks = id("ship-unlocks");
    unlocks.replaceChildren();
    shipModels.forEach((model) => {
      const button = document.createElement("button");
      const unlocked = game.save.shipsUnlocked.includes(model.id);
      button.className = game.save.ship === model.id ? "selected" : "";
      button.textContent = unlocked
        ? model.name
        : `${model.name} · M${model.unlock}`;
      button.disabled = !unlocked;
      button.addEventListener("click", () => {
        game.save.ship = model.id;
        persist(true);
        renderLoadout();
      });
      unlocks.append(button);
    });
  }

  function buyUpgrade(upgrade, cost) {
    const level = game.save.upgrades[upgrade.key] || 0;
    if (level >= upgrade.cap || game.save.credits < cost) return;
    game.save.credits -= cost;
    game.save.upgrades[upgrade.key] = level + 1;
    persist(true);
    renderLoadout();
    beep(680, 0.18, "triangle", 0.04, 1100);
  }

  function drawBackground(ctx, dt) {
    const gradient = ctx.createLinearGradient(0, 0, game.width, game.height);
    gradient.addColorStop(0, game.mission.sector.dark);
    gradient.addColorStop(0.56, "#0b0b1b");
    gradient.addColorStop(1, "#090814");
    ctx.fillStyle = gradient;
    ctx.fillRect(0, 0, game.width, game.height);
    const nebula = ctx.createRadialGradient(
      game.width * 0.68,
      game.height * 0.46,
      1,
      game.width * 0.68,
      game.height * 0.46,
      game.width * 0.55,
    );
    nebula.addColorStop(0, `${game.mission.sector.color}18`);
    nebula.addColorStop(1, "#00000000");
    ctx.fillStyle = nebula;
    ctx.fillRect(0, 0, game.width, game.height);
    for (const star of game.stars) {
      const twinkle = 0.35 + (Math.sin(star.phase) + 1) * 0.24;
      ctx.globalAlpha = twinkle * star.z;
      ctx.fillStyle = star.hue ? game.mission.sector.star : "#d7dcff";
      ctx.fillRect(star.x, star.y, star.size * star.z, star.size * star.z);
    }
    ctx.globalAlpha = 1;
    for (const asteroid of game.asteroids) drawAsteroid(ctx, asteroid);
  }

  function drawAsteroid(ctx, rock) {
    ctx.save();
    ctx.translate(rock.x, rock.y);
    ctx.rotate(rock.rotation);
    ctx.strokeStyle = `${rock.color}44`;
    ctx.fillStyle = "#201f31";
    ctx.lineWidth = 1.3;
    const sides = 7;
    ctx.beginPath();
    for (let i = 0; i <= sides; i++) {
      const angle = (i / sides) * TAU;
      const variation =
        0.72 + ((i * 13 + Math.floor(rock.detail * 40)) % 7) * 0.047;
      const x = Math.cos(angle) * rock.radius * variation;
      const y = Math.sin(angle) * rock.radius * variation;
      i ? ctx.lineTo(x, y) : ctx.moveTo(x, y);
    }
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    ctx.strokeStyle = "#c4c3db22";
    ctx.beginPath();
    ctx.moveTo(-rock.radius * 0.4, -rock.radius * 0.1);
    ctx.lineTo(rock.radius * 0.25, rock.radius * 0.25);
    ctx.stroke();
    ctx.restore();
  }

  function drawFighter(
    ctx,
    model,
    x,
    y,
    size,
    angle = 0,
    time = 0,
    color = "#7beaff",
    accent = "#becbff",
    hero = false,
    blink = 0,
  ) {
    ctx.save();
    ctx.translate(x, y);
    ctx.rotate(angle);
    const s = size / 100;
    ctx.scale(s, s);
    ctx.shadowColor = color;
    ctx.shadowBlur = hero ? 30 : 14;
    if (model === "wayfarer") drawWayfarer(ctx, color, accent, time);
    else if (model === "needle") drawNeedle(ctx, color, accent, time);
    else drawBastion(ctx, color, accent, time);
    if (blink > 0) {
      ctx.globalCompositeOperation = "screen";
      ctx.globalAlpha = blink * 0.6;
      ctx.fillStyle = "#ffffff";
      ctx.beginPath();
      ctx.ellipse(0, 0, 49, 26, 0, 0, TAU);
      ctx.fill();
    }
    ctx.restore();
  }

  function drawWayfarer(ctx, color, accent, time) {
    const flame = 19 + Math.sin(time * 36) * 5;
    ctx.fillStyle = "#ffbb77";
    ctx.beginPath();
    ctx.moveTo(-35, -8);
    ctx.lineTo(-35 - flame, 0);
    ctx.lineTo(-35, 8);
    ctx.fill();
    ctx.fillStyle = "#75f4ff";
    ctx.beginPath();
    ctx.moveTo(-36, -4);
    ctx.lineTo(-36 - flame * 0.62, 0);
    ctx.lineTo(-36, 4);
    ctx.fill();
    ctx.fillStyle = "#26314e";
    ctx.strokeStyle = color;
    ctx.lineWidth = 2.5;
    ctx.beginPath();
    ctx.moveTo(48, 0);
    ctx.lineTo(13, -8);
    ctx.lineTo(-9, -14);
    ctx.lineTo(-28, -33);
    ctx.lineTo(-37, -30);
    ctx.lineTo(-30, -9);
    ctx.lineTo(-44, -4);
    ctx.lineTo(-44, 4);
    ctx.lineTo(-30, 9);
    ctx.lineTo(-37, 30);
    ctx.lineTo(-28, 33);
    ctx.lineTo(-9, 14);
    ctx.lineTo(13, 8);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    ctx.fillStyle = color;
    ctx.beginPath();
    ctx.moveTo(48, 0);
    ctx.lineTo(11, -3);
    ctx.lineTo(-14, 0);
    ctx.lineTo(11, 3);
    ctx.closePath();
    ctx.fill();
    ctx.fillStyle = "#d5fbff";
    ctx.beginPath();
    ctx.ellipse(12, 0, 14, 4, 0, 0, TAU);
    ctx.fill();
    ctx.fillStyle = accent;
    for (const y of [-22, 22]) {
      ctx.beginPath();
      ctx.arc(-26, y, 3, 0, TAU);
      ctx.fill();
    }
    ctx.fillStyle = "#79eaff";
    ctx.fillRect(-5, -2, 18, 4);
    ctx.strokeStyle = "#ffffff70";
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(-8, -11);
    ctx.lineTo(14, -6);
    ctx.moveTo(-8, 11);
    ctx.lineTo(14, 6);
    ctx.stroke();
  }

  function drawNeedle(ctx, color, accent, time) {
    const flame = 22 + Math.sin(time * 42) * 7;
    ctx.fillStyle = "#fff0a0";
    ctx.beginPath();
    ctx.moveTo(-38, -5);
    ctx.lineTo(-38 - flame, 0);
    ctx.lineTo(-38, 5);
    ctx.fill();
    ctx.fillStyle = "#ff9479";
    ctx.beginPath();
    ctx.moveTo(49, 0);
    ctx.lineTo(12, -6);
    ctx.lineTo(-12, -9);
    ctx.lineTo(-31, -25);
    ctx.lineTo(-36, -24);
    ctx.lineTo(-30, -6);
    ctx.lineTo(-46, -2);
    ctx.lineTo(-46, 2);
    ctx.lineTo(-30, 6);
    ctx.lineTo(-36, 24);
    ctx.lineTo(-31, 25);
    ctx.lineTo(-12, 9);
    ctx.lineTo(12, 6);
    ctx.closePath();
    ctx.fill();
    ctx.strokeStyle = accent;
    ctx.lineWidth = 2;
    ctx.stroke();
    ctx.fillStyle = "#3f273c";
    ctx.beginPath();
    ctx.ellipse(9, 0, 17, 3.8, 0, 0, TAU);
    ctx.fill();
    ctx.fillStyle = "#fff0a0";
    ctx.fillRect(9, -1.7, 27, 3.4);
    ctx.fillStyle = accent;
    for (const y of [-17, 17]) {
      ctx.beginPath();
      ctx.arc(-25, y, 3.4, 0, TAU);
      ctx.fill();
    }
    ctx.strokeStyle = "#ffffff80";
    ctx.lineWidth = 1.4;
    ctx.beginPath();
    ctx.moveTo(-21, -15);
    ctx.lineTo(18, -4);
    ctx.moveTo(-21, 15);
    ctx.lineTo(18, 4);
    ctx.stroke();
  }

  function drawBastion(ctx, color, accent, time) {
    const flame = 15 + Math.sin(time * 25) * 4;
    ctx.fillStyle = "#c1aaff";
    for (const y of [-17, 17]) {
      ctx.beginPath();
      ctx.moveTo(-37, y - 5);
      ctx.lineTo(-37 - flame, y);
      ctx.lineTo(-37, y + 5);
      ctx.fill();
    }
    ctx.fillStyle = "#29263f";
    ctx.strokeStyle = color;
    ctx.lineWidth = 3;
    ctx.beginPath();
    ctx.moveTo(48, 0);
    ctx.lineTo(18, -10);
    ctx.lineTo(2, -20);
    ctx.lineTo(-7, -39);
    ctx.lineTo(-22, -39);
    ctx.lineTo(-20, -17);
    ctx.lineTo(-38, -25);
    ctx.lineTo(-43, -20);
    ctx.lineTo(-34, -5);
    ctx.lineTo(-45, -2);
    ctx.lineTo(-45, 2);
    ctx.lineTo(-34, 5);
    ctx.lineTo(-43, 20);
    ctx.lineTo(-38, 25);
    ctx.lineTo(-20, 17);
    ctx.lineTo(-22, 39);
    ctx.lineTo(-7, 39);
    ctx.lineTo(2, 20);
    ctx.lineTo(18, 10);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    ctx.fillStyle = accent;
    ctx.beginPath();
    ctx.moveTo(49, 0);
    ctx.lineTo(17, -4);
    ctx.lineTo(-12, 0);
    ctx.lineTo(17, 4);
    ctx.closePath();
    ctx.fill();
    ctx.fillStyle = "#fcf3c3";
    ctx.beginPath();
    ctx.ellipse(5, 0, 13, 5, 0, 0, TAU);
    ctx.fill();
    ctx.fillStyle = color;
    ctx.fillRect(-14, -30, 12, 4);
    ctx.fillRect(-14, 26, 12, 4);
  }

  function drawEnemy(ctx, enemy) {
    ctx.save();
    ctx.translate(enemy.x, enemy.y);
    ctx.rotate(Math.PI);
    const s = enemy.radius / (enemy.kind === "boss" ? 60 : 20);
    ctx.scale(s, s);
    ctx.shadowColor = enemy.color;
    ctx.shadowBlur = 12;
    if (enemy.kind === "boss") drawBossModel(ctx, enemy);
    else if (enemy.kind === "mote") drawMote(ctx, enemy);
    else if (enemy.kind === "skiff") drawSkiff(ctx, enemy);
    else if (enemy.kind === "wisp") drawWisp(ctx, enemy);
    else if (enemy.kind === "bomber") drawBomber(ctx, enemy);
    else if (enemy.kind === "bulwark") drawBulwark(ctx, enemy);
    else drawHunter(ctx, enemy);
    if (enemy.hit > 0) {
      ctx.globalCompositeOperation = "screen";
      ctx.globalAlpha = enemy.hit * 0.8;
      ctx.fillStyle = "#ffffff";
      ctx.beginPath();
      ctx.arc(0, 0, enemy.radius + 4, 0, TAU);
      ctx.fill();
    }
    if (enemy.kind !== "boss" && enemy.hp < enemy.maxHp) {
      ctx.globalAlpha = 0.85;
      ctx.fillStyle = "#302231";
      ctx.fillRect(-18, -enemy.radius - 9, 36, 3);
      ctx.fillStyle = enemy.color;
      ctx.fillRect(-18, -enemy.radius - 9, (36 * enemy.hp) / enemy.maxHp, 3);
    }
    ctx.restore();
  }

  function drawMote(ctx, enemy) {
    ctx.fillStyle = "#2c1e35";
    ctx.strokeStyle = enemy.color;
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(23, 0);
    ctx.lineTo(5, -11);
    ctx.lineTo(-15, -10);
    ctx.lineTo(-24, 0);
    ctx.lineTo(-15, 10);
    ctx.lineTo(5, 11);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    ctx.fillStyle = enemy.color;
    ctx.beginPath();
    ctx.arc(3, 0, 4 + Math.sin(enemy.age * 8) * 1.1, 0, TAU);
    ctx.fill();
    ctx.fillStyle = "#ffd7b2";
    ctx.fillRect(-18, -2, 8, 4);
  }

  function drawSkiff(ctx, enemy) {
    ctx.fillStyle = "#382638";
    ctx.strokeStyle = enemy.color;
    ctx.lineWidth = 2.2;
    ctx.beginPath();
    ctx.moveTo(23, 0);
    ctx.lineTo(3, -7);
    ctx.lineTo(-5, -22);
    ctx.lineTo(-15, -19);
    ctx.lineTo(-11, -6);
    ctx.lineTo(-25, -3);
    ctx.lineTo(-25, 3);
    ctx.lineTo(-11, 6);
    ctx.lineTo(-15, 19);
    ctx.lineTo(-5, 22);
    ctx.lineTo(3, 7);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    ctx.fillStyle = "#ffc975";
    ctx.beginPath();
    ctx.ellipse(3, 0, 9, 3, 0, 0, TAU);
    ctx.fill();
    ctx.fillStyle = enemy.color;
    ctx.fillRect(-20, -2, 8, 4);
  }

  function drawWisp(ctx, enemy) {
    ctx.fillStyle = "#2b2544";
    ctx.strokeStyle = enemy.color;
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(24, 0);
    ctx.lineTo(0, -5);
    ctx.lineTo(-20, -18);
    ctx.lineTo(-12, 0);
    ctx.lineTo(-20, 18);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    ctx.fillStyle = "#f3d9ff";
    ctx.beginPath();
    ctx.arc(3, 0, 4, 0, TAU);
    ctx.fill();
  }

  function drawBomber(ctx, enemy) {
    ctx.fillStyle = "#432333";
    ctx.strokeStyle = enemy.color;
    ctx.lineWidth = 2.4;
    ctx.beginPath();
    ctx.moveTo(22, 0);
    ctx.lineTo(11, -11);
    ctx.lineTo(0, -24);
    ctx.lineTo(-15, -22);
    ctx.lineTo(-12, -7);
    ctx.lineTo(-25, -5);
    ctx.lineTo(-25, 5);
    ctx.lineTo(-12, 7);
    ctx.lineTo(-15, 22);
    ctx.lineTo(0, 24);
    ctx.lineTo(11, 11);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    ctx.fillStyle = enemy.color;
    ctx.beginPath();
    ctx.arc(0, 0, 6, 0, TAU);
    ctx.fill();
    ctx.fillStyle = "#ffe1bd";
    ctx.fillRect(-17, -15, 9, 4);
    ctx.fillRect(-17, 11, 9, 4);
  }

  function drawBulwark(ctx, enemy) {
    ctx.fillStyle = "#392735";
    ctx.strokeStyle = enemy.color;
    ctx.lineWidth = 3;
    ctx.beginPath();
    ctx.moveTo(27, 0);
    ctx.lineTo(13, -16);
    ctx.lineTo(9, -31);
    ctx.lineTo(-9, -29);
    ctx.lineTo(-16, -18);
    ctx.lineTo(-28, -15);
    ctx.lineTo(-23, 0);
    ctx.lineTo(-28, 15);
    ctx.lineTo(-16, 18);
    ctx.lineTo(-9, 29);
    ctx.lineTo(9, 31);
    ctx.lineTo(13, 16);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    ctx.fillStyle = "#ffca97";
    ctx.beginPath();
    ctx.arc(3, 0, 9, 0, TAU);
    ctx.fill();
    ctx.strokeStyle = "#ffc18c99";
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.arc(0, 0, 23, -0.7, 0.7);
    ctx.stroke();
  }

  function drawHunter(ctx, enemy) {
    ctx.fillStyle = "#203642";
    ctx.strokeStyle = enemy.color;
    ctx.lineWidth = 2.2;
    ctx.beginPath();
    ctx.moveTo(27, 0);
    ctx.lineTo(7, -8);
    ctx.lineTo(-11, -25);
    ctx.lineTo(-17, -22);
    ctx.lineTo(-12, -7);
    ctx.lineTo(-27, -3);
    ctx.lineTo(-27, 3);
    ctx.lineTo(-12, 7);
    ctx.lineTo(-17, 22);
    ctx.lineTo(-11, 25);
    ctx.lineTo(7, 8);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    ctx.fillStyle = "#b9f3c8";
    ctx.fillRect(-6, -2, 13, 4);
  }

  function drawBossModel(ctx, boss) {
    const pulse = 1 + Math.sin(game.elapsed * 6) * 0.035;
    ctx.scale(pulse, pulse);
    ctx.fillStyle = "#321e3c";
    ctx.strokeStyle = boss.color;
    ctx.lineWidth = 3;
    ctx.beginPath();
    ctx.moveTo(53, 0);
    ctx.lineTo(30, -20);
    ctx.lineTo(10, -38);
    ctx.lineTo(2, -55);
    ctx.lineTo(-17, -48);
    ctx.lineTo(-13, -25);
    ctx.lineTo(-35, -42);
    ctx.lineTo(-48, -35);
    ctx.lineTo(-37, -14);
    ctx.lineTo(-56, -7);
    ctx.lineTo(-57, 7);
    ctx.lineTo(-37, 14);
    ctx.lineTo(-48, 35);
    ctx.lineTo(-35, 42);
    ctx.lineTo(-13, 25);
    ctx.lineTo(-17, 48);
    ctx.lineTo(2, 55);
    ctx.lineTo(10, 38);
    ctx.lineTo(30, 20);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    ctx.fillStyle = boss.color;
    ctx.beginPath();
    ctx.moveTo(48, 0);
    ctx.lineTo(12, -10);
    ctx.lineTo(-25, 0);
    ctx.lineTo(12, 10);
    ctx.closePath();
    ctx.fill();
    ctx.fillStyle = "#fff0c7";
    ctx.shadowBlur = 20;
    ctx.beginPath();
    ctx.ellipse(2, 0, 15, 10, 0, 0, TAU);
    ctx.fill();
    ctx.strokeStyle = "#ffd6f188";
    ctx.lineWidth = 2;
    for (const sign of [-1, 1]) {
      ctx.beginPath();
      ctx.moveTo(-15, sign * 15);
      ctx.lineTo(8, sign * 34);
      ctx.lineTo(27, sign * 23);
      ctx.stroke();
    }
    ctx.fillStyle = "#ffac97";
    ctx.fillRect(-42, -3, 12, 6);
    ctx.fillRect(-42, -27, 10, 4);
    ctx.fillRect(-42, 23, 10, 4);
  }

  function drawProjectiles(ctx) {
    for (const bullet of game.bullets) {
      ctx.save();
      ctx.strokeStyle = bullet.color;
      ctx.lineWidth = bullet.radius * 1.4;
      ctx.lineCap = "round";
      ctx.shadowColor = bullet.color;
      ctx.shadowBlur = 12;
      ctx.beginPath();
      ctx.moveTo(bullet.x - 20, bullet.y);
      ctx.lineTo(bullet.x + 2, bullet.y);
      ctx.stroke();
      ctx.restore();
    }
    for (const bullet of game.enemyBullets) {
      ctx.save();
      ctx.fillStyle = bullet.color;
      ctx.shadowColor = bullet.color;
      ctx.shadowBlur = 12;
      ctx.beginPath();
      ctx.arc(
        bullet.x,
        bullet.y,
        bullet.radius * (0.88 + Math.sin(bullet.age * 10) * 0.12),
        0,
        TAU,
      );
      ctx.fill();
      ctx.restore();
    }
  }

  function drawPickups(ctx) {
    for (const pickup of game.pickups) {
      const bob = Math.sin(pickup.phase) * 3;
      ctx.save();
      ctx.translate(pickup.x, pickup.y + bob);
      ctx.rotate(pickup.phase * 0.4);
      const color = pickup.kind === "repair" ? "#8cf0b5" : "#f6d177";
      ctx.fillStyle = `${color}2c`;
      ctx.strokeStyle = color;
      ctx.lineWidth = 1.5;
      ctx.shadowColor = color;
      ctx.shadowBlur = 14;
      ctx.beginPath();
      ctx.moveTo(0, -pickup.radius);
      ctx.lineTo(pickup.radius, 0);
      ctx.lineTo(0, pickup.radius);
      ctx.lineTo(-pickup.radius, 0);
      ctx.closePath();
      ctx.fill();
      ctx.stroke();
      ctx.fillStyle = color;
      ctx.font = "bold 10px monospace";
      ctx.textAlign = "center";
      ctx.textBaseline = "middle";
      ctx.fillText(pickup.kind === "repair" ? "+" : "✧", 0, 0);
      ctx.restore();
    }
  }

  function drawPlayer(ctx) {
    const player = game.player;
    if (!player) return;
    for (let i = 0; i < player.trail.length; i++) {
      const trail = player.trail[i];
      ctx.globalAlpha = (1 - i / player.trail.length) * 0.13;
      ctx.fillStyle = activeShip().color;
      ctx.beginPath();
      ctx.arc(trail.x, trail.y, player.radius * 0.7, 0, TAU);
      ctx.fill();
    }
    ctx.globalAlpha = 1;
    if (game.invulnerable > 0 && Math.floor(game.elapsed * 16) % 2 === 0)
      ctx.globalAlpha = 0.4;
    drawFighter(
      ctx,
      activeShip().id,
      player.x,
      player.y,
      player.radius * 2.55,
      player.aim,
      game.elapsed,
      activeShip().color,
      activeShip().accent,
      false,
      player.damageBlink,
    );
    if (player.shieldPulse > 0 || game.invulnerable > 0.4) {
      ctx.save();
      ctx.strokeStyle = `rgba(151,237,255,${0.25 + Math.sin(game.elapsed * 15) * 0.1})`;
      ctx.lineWidth = 2;
      ctx.shadowColor = "#8bf1fa";
      ctx.shadowBlur = 13;
      ctx.beginPath();
      ctx.ellipse(
        player.x,
        player.y,
        player.radius * 1.8,
        player.radius * 1.22,
        0,
        0,
        TAU,
      );
      ctx.stroke();
      ctx.restore();
    }
    ctx.globalAlpha = 1;
  }

  function drawParticles(ctx) {
    for (const particle of game.particles) {
      ctx.globalAlpha = clamp(particle.life / particle.max, 0, 1);
      ctx.fillStyle = particle.color;
      ctx.shadowColor = particle.color;
      ctx.shadowBlur = 8;
      ctx.beginPath();
      ctx.arc(
        particle.x,
        particle.y,
        particle.radius * (0.5 + particle.life / particle.max),
        0,
        TAU,
      );
      ctx.fill();
    }
    ctx.globalAlpha = 1;
    ctx.shadowBlur = 0;
  }

  function paintFlight() {
    const ctx = game.ctx;
    if (!ctx || !game.mission) return;
    ctx.save();
    if (game.shake > 0)
      ctx.translate(
        rand(-game.shake, game.shake),
        rand(-game.shake, game.shake),
      );
    drawBackground(ctx);
    drawPickups(ctx);
    drawProjectiles(ctx);
    for (const enemy of game.enemies) drawEnemy(ctx, enemy);
    drawPlayer(ctx);
    drawParticles(ctx);
    if (game.state === "playing" && game.player) {
      const vignette = ctx.createRadialGradient(
        game.player.x,
        game.player.y,
        game.height * 0.15,
        game.player.x,
        game.player.y,
        game.width * 0.75,
      );
      vignette.addColorStop(0, "#00000000");
      vignette.addColorStop(1, "#06061177");
      ctx.fillStyle = vignette;
      ctx.fillRect(0, 0, game.width, game.height);
    }
    ctx.restore();
  }

  function frame(now) {
    const dt = game.last ? Math.min(0.05, (now - game.last) / 1000) : 0;
    game.last = now;
    if (
      game.screen === "flight" &&
      game.state === "playing" &&
      !game.paused &&
      !document.hidden
    )
      updateFlight(dt);
    if (game.screen === "flight") paintFlight();
    if (game.screen === "home") drawShowcase();
    if (game.screen === "loadout") drawShowcase();
    requestAnimationFrame(frame);
  }

  function formatUpgradeCost(upgrade) {
    return Math.floor(
      upgrade.base * Math.pow(1.52, game.save.upgrades[upgrade.key] || 0),
    );
  }

  function bindEvents() {
    id("continue-button").addEventListener("click", () => resumePending());
    id("campaign-button").addEventListener("click", () => setScreen("map"));
    id("hangar-button").addEventListener("click", () => setScreen("loadout"));
    id("audio-toggle").addEventListener("click", () => {
      game.save.sound = !game.save.sound;
      id("audio-toggle").textContent = game.save.sound ? "◖))" : "◖×";
      persist(true);
      if (game.save.sound) beep(500, 0.1);
    });
    id("flight-home").addEventListener("click", () => {
      checkpoint();
      setScreen("home");
    });
    id("map-home").addEventListener("click", () => setScreen("home"));
    id("loadout-home").addEventListener("click", () => setScreen("home"));
    id("map-launch").addEventListener("click", () =>
      beginLevel(game.save.unlockedLevel),
    );
    id("pause-button").addEventListener("click", openPause);
    id("resume-flight").addEventListener("click", () => {
      closeModal("pause-modal");
      game.paused = false;
      game.last = performance.now();
    });
    id("quit-flight").addEventListener("click", () => {
      closeModal("pause-modal");
      game.paused = false;
      checkpoint();
      setScreen("home");
    });
    id("result-hangar").addEventListener("click", () => {
      closeModal("result-modal");
      setScreen("home");
    });
    id("special-button").addEventListener("click", useSpecial);
    id("message-action").addEventListener("click", startFlight);
    id("ship-prev").addEventListener("click", () => cycleShip(-1));
    id("ship-next").addEventListener("click", () => cycleShip(1));
    document
      .querySelectorAll("[data-close]")
      .forEach((button) =>
        button.addEventListener("click", () =>
          closeModal(button.dataset.close),
        ),
      );
    document.addEventListener("keydown", (event) => {
      if (
        ["ArrowUp", "ArrowDown", "ArrowLeft", "ArrowRight", "Space"].includes(
          event.code,
        )
      )
        event.preventDefault();
      game.keys.add(event.code);
      if (
        [
          "ArrowUp",
          "ArrowDown",
          "ArrowLeft",
          "ArrowRight",
          "KeyW",
          "KeyA",
          "KeyS",
          "KeyD",
        ].includes(event.code)
      )
        game.inputMode = "keyboard";
      if (
        event.code === "Space" &&
        game.state === "briefing" &&
        game.screen === "flight"
      )
        startFlight();
      if (event.code === "KeyX") useSpecial();
      if (
        (event.code === "Escape" || event.code === "KeyP") &&
        game.screen === "flight" &&
        game.state === "playing"
      )
        openPause();
      if (
        (event.code === "ShiftLeft" || event.code === "ShiftRight") &&
        game.state === "playing"
      )
        dash();
    });
    document.addEventListener("keyup", (event) => game.keys.delete(event.code));
    ui.flightCanvas.addEventListener("pointermove", (event) => {
      if (event.pointerType === "touch") return;
      const rect = ui.flightCanvas.getBoundingClientRect();
      game.pointer.x = ((event.clientX - rect.left) / rect.width) * game.width;
      game.pointer.y = ((event.clientY - rect.top) / rect.height) * game.height;
      game.inputMode = "pointer";
      game.pointer.active = true;
    });
    ui.flightCanvas.addEventListener("pointerdown", (event) => {
      startAudio();
      const rect = ui.flightCanvas.getBoundingClientRect();
      game.pointer.x = ((event.clientX - rect.left) / rect.width) * game.width;
      game.pointer.y = ((event.clientY - rect.top) / rect.height) * game.height;
      game.pointer.active = event.pointerType === "mouse";
      if (event.pointerType === "touch") {
        game.touch.fire = true;
        game.inputMode = "keyboard";
      }
    });
    ui.flightCanvas.addEventListener("pointerleave", () => {
      if (game.inputMode === "pointer") game.pointer.active = false;
    });
    ui.flightCanvas.addEventListener("pointerup", () => {
      game.pointer.active = false;
      game.touch.fire = false;
    });
    document.querySelectorAll("[data-control]").forEach((button) => {
      const name = button.dataset.control;
      const down = (event) => {
        event.preventDefault();
        if (name === "special") useSpecial();
        else if (name === "dash") dash();
        else game.touch[name] = true;
      };
      const up = () => {
        if (name in game.touch) game.touch[name] = false;
      };
      button.addEventListener("pointerdown", down);
      ["pointerup", "pointercancel", "pointerleave"].forEach((type) =>
        button.addEventListener(type, up),
      );
    });
    window.addEventListener("resize", () => {
      resizeFlight();
      drawShowcase();
    });
    window.addEventListener("beforeunload", () => {
      checkpoint();
      persist(true);
    });
    document.addEventListener("visibilitychange", () => {
      if (document.hidden && game.state === "playing") openPause();
    });
    window.addEventListener("storage", (event) => {
      if (event.key === SAVE_KEY) game.save = loadSave();
    });
  }

  function cycleShip(direction) {
    const unlocked = shipModels.filter((ship) =>
      game.save.shipsUnlocked.includes(ship.id),
    );
    let index = unlocked.findIndex((ship) => ship.id === game.save.ship);
    index = (index + direction + unlocked.length) % unlocked.length;
    game.save.ship = unlocked[index].id;
    persist(true);
    renderLoadout();
  }

  function openPause() {
    if (game.state !== "playing" || game.paused) return;
    game.paused = true;
    checkpoint();
    id("pause-modal").classList.remove("hidden");
  }

  function closeModal(name) {
    id(name).classList.add("hidden");
    if (name === "pause-modal") {
      game.paused = false;
      game.last = performance.now();
    }
  }

  function boot() {
    game.ctx = ui.flightCanvas.getContext("2d", { alpha: false });
    bindEvents();
    resizeFlight();
    renderHome();
    requestAnimationFrame(frame);
  }

  boot();
})();
