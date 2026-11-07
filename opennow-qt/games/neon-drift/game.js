(() => {
  "use strict";
  const SAVE_KEY = "opennow.neondrift.v1";
  const TAU = Math.PI * 2;
  const clamp = (n, lo, hi) => Math.max(lo, Math.min(hi, n));
  const lerp = (a, b, t) => a + (b - a) * t;
  const rand = (a, b) => a + Math.random() * (b - a);
  const el = (name) => document.getElementById(name);

  const districts = [
    {
      name: "Rainline",
      short: "RAINLINE",
      color: "#ff8fc4",
      sky: ["#35243b", "#151923", "#0c111a"],
      accent: "#ff8fc4",
      road: "#25232e",
      roadLine: "#e9c3db",
      scenery: "canal lamps",
      line: "The water keeps the city's second set of lights.",
    },
    {
      name: "Glass Mile",
      short: "GLASS MILE",
      color: "#84e8ec",
      sky: ["#1e3445", "#111d28", "#0a1119"],
      accent: "#84e8ec",
      road: "#202a31",
      roadLine: "#c1eced",
      scenery: "skybridges",
      line: "A clear night, a high road, and a little nerve.",
    },
    {
      name: "Sunset Loop",
      short: "SUNSET",
      color: "#ffae72",
      sky: ["#633a49", "#211a29", "#0c111b"],
      accent: "#ffc477",
      road: "#2a242b",
      roadLine: "#f4c8a7",
      scenery: "rooftop gardens",
      line: "The rooftops hold the last warm color.",
    },
    {
      name: "Moss Circuit",
      short: "MOSS CIRCUIT",
      color: "#a8e492",
      sky: ["#274238", "#142521", "#090f15"],
      accent: "#9ce5a1",
      road: "#1f2926",
      roadLine: "#c8e8b8",
      scenery: "greenhouse arcs",
      line: "The old city grew a new way around the road.",
    },
    {
      name: "Blue Static",
      short: "BLUE STATIC",
      color: "#9ca5ff",
      sky: ["#333558", "#171929", "#0b0d18"],
      accent: "#a7adff",
      road: "#232430",
      roadLine: "#d2d1ff",
      scenery: "radio masts",
      line: "Every quiet rooftop has a station tuned for you.",
    },
    {
      name: "Last Light",
      short: "LAST LIGHT",
      color: "#ffd879",
      sky: ["#514138", "#211b1e", "#090d13"],
      accent: "#ffdc8a",
      road: "#28252a",
      roadLine: "#f4dcab",
      scenery: "far-edge viaducts",
      line: "One more bridge. One more look at home.",
    },
  ];

  const routeNames = [
    "Canal Lights",
    "Soft Corner",
    "Window Rain",
    "Lantern Row",
    "Blue Bridge",
    "Slow Bloom",
    "Low Tide",
    "Side Street",
    "Long Reflection",
    "The Last Ferry",
  ];
  const carModels = [
    {
      id: "lumen",
      name: "Lumen GT",
      type: "CITY SPRINTER · SERIES 01",
      copy: "A gentle first ride. Honest grip, bright tail-lights.",
      unlock: 1,
      speed: 260,
      grip: 1,
      boost: 1,
      width: 0.91,
      color: "#ff8fc4",
      trim: "#ffdfb4",
      silhouette: "coupe",
    },
    {
      id: "wisp",
      name: "Wisp R",
      type: "NIGHT RALLY · SERIES 02",
      copy: "A nimble little thing. It loves a late apex.",
      unlock: 8,
      speed: 282,
      grip: 1.16,
      boost: 0.92,
      width: 0.78,
      color: "#82e7e3",
      trim: "#d5ffed",
      silhouette: "hatch",
    },
    {
      id: "comet",
      name: "Comet S",
      type: "GRAND TOURER · SERIES 03",
      copy: "A longer wheelbase, a deeper breath, a bigger boost.",
      unlock: 19,
      speed: 310,
      grip: 0.91,
      boost: 1.2,
      width: 1.08,
      color: "#aa9bff",
      trim: "#f5d5ff",
      silhouette: "tourer",
    },
  ];
  const upgradeSpecs = [
    {
      key: "engine",
      icon: "⌁",
      name: "Quiet horsepower",
      text: "Raise the speed ceiling on long straights.",
      base: 24,
      cap: 6,
    },
    {
      key: "grip",
      icon: "◉",
      name: "Soft compound tyres",
      text: "Hold a tighter line through fast corners.",
      base: 25,
      cap: 6,
    },
    {
      key: "boost",
      icon: "✦",
      name: "Afterburner cell",
      text: "Carry a little more boost energy.",
      base: 30,
      cap: 5,
    },
    {
      key: "magnet",
      icon: "✧",
      name: "Shard magnet",
      text: "Collect route shards from a wider line.",
      base: 22,
      cap: 5,
    },
  ];
  const paintColors = [
    "#ff8fc4",
    "#82e7e3",
    "#aa9bff",
    "#ffbc77",
    "#a6e78e",
    "#eef1ff",
  ];
  const freshSave = () => ({
    version: 1,
    unlockedRoute: 1,
    highestRoute: 0,
    credits: 25,
    wins: 0,
    totalRuns: 0,
    bestTime: 0,
    routeTimes: {},
    routeStars: {},
    ghosts: {},
    upgrades: { engine: 0, grip: 0, boost: 0, magnet: 0 },
    car: "lumen",
    unlockedCars: ["lumen"],
    paint: 0,
    score: 0,
    bestScore: 0,
    driftRecord: 0,
    sound: true,
    pending: null,
    achievements: [],
  });
  const ui = {
    home: el("home-view"),
    race: el("race-view"),
    map: el("map-view"),
    tuning: el("tuning-view"),
    display: el("display-canvas"),
    track: el("track-canvas"),
    tune: el("tune-canvas"),
  };
  const game = {
    save: readSave(),
    screen: "home",
    state: "idle",
    route: 1,
    routeInfo: null,
    district: 0,
    time: 0,
    elapsed: 0,
    last: 0,
    width: 960,
    height: 520,
    ctx: null,
    player: null,
    traffic: [],
    props: [],
    particles: [],
    rivalCars: [],
    ghostSamples: [],
    currentGhost: [],
    ghostClock: 0,
    roadSegments: [],
    progress: 0,
    distance: 0,
    lap: 1,
    boost: 100,
    combo: 0,
    comboTimer: 0,
    score: 0,
    drift: 0,
    driftAngle: 0,
    driftHeld: false,
    boosting: false,
    brakeHeld: false,
    gasHeld: false,
    keys: new Set(),
    touch: {
      left: false,
      right: false,
      gas: false,
      boost: false,
      brake: false,
    },
    countdown: 3,
    countdownClock: 0,
    spawnClock: 0,
    shake: 0,
    screenFlash: 0,
    timeCounter: 0,
    paintIndex: 0,
    audio: null,
    checkpointClock: 0,
    lastMessage: "",
    particlesSeed: 0,
  };

  const routes = Array.from({ length: 60 }, (_, index) => {
    const districtIndex = Math.floor(index / 10);
    const local = index % 10;
    const district = districts[districtIndex];
    const bossRun = local === 9;
    const length = 4200 + local * 220 + districtIndex * 190;
    const names = routeNames.slice();
    const name = bossRun
      ? [
          "Moonrise Run",
          "Last Light Sprint",
          "The Long Way Home",
          "One More Loop",
          "After Midnight",
          "Citywide Goodnight",
        ][districtIndex]
      : names[local];
    return {
      id: index + 1,
      district: districtIndex,
      local,
      name,
      length,
      laps: 2,
      seed: (index + 17) * 3187,
      difficulty: 1 + districtIndex * 0.12 + local * 0.035,
      boss: bossRun,
      goldTime: (length / (255 + districtIndex * 4)) * (bossRun ? 0.82 : 0.92),
      rivals: bossRun ? 4 : 3 + Math.floor(districtIndex / 2),
      weather: ["DRIZZLE", "CLEAR", "WARM HAZE", "GLASS RAIN", "MOON FOG"][
        index % 5
      ],
      routeClass: ["FLOW", "SWITCHBACK", "SPRINT", "CROSSWIND"][index % 4],
    };
  });

  function readSave() {
    try {
      const data = JSON.parse(localStorage.getItem(SAVE_KEY) || "null");
      if (!data || data.version !== 1) return freshSave();
      const base = freshSave();
      return {
        ...base,
        ...data,
        routeTimes: data.routeTimes || {},
        routeStars: data.routeStars || {},
        ghosts: data.ghosts || {},
        upgrades: { ...base.upgrades, ...(data.upgrades || {}) },
        unlockedCars: Array.isArray(data.unlockedCars)
          ? data.unlockedCars
          : ["lumen"],
        achievements: Array.isArray(data.achievements) ? data.achievements : [],
      };
    } catch (error) {
      console.warn("A new garage card was opened.", error);
      return freshSave();
    }
  }

  function save(force = false) {
    if (!force && performance.now() - game.checkpointClock < 500) return;
    game.checkpointClock = performance.now();
    try {
      localStorage.setItem(SAVE_KEY, JSON.stringify(game.save));
      el("save-state").textContent = "GARAGE SAVED";
      setTimeout(() => {
        if (el("save-state")) el("save-state").textContent = "GARAGE SYNCED";
      }, 1000);
    } catch (_) {
      el("save-state").textContent = "SESSION ONLY";
    }
  }

  function currentCar() {
    return carModels.find((car) => car.id === game.save.car) || carModels[0];
  }
  function routeById(number) {
    return routes[clamp(number - 1, 0, routes.length - 1)];
  }
  function districtFor(route = game.routeInfo) {
    return districts[route?.district || 0];
  }
  function statLine(car = currentCar()) {
    return `GRIP ${String(Math.round((car.grip + game.save.upgrades.grip * 0.08) * 6)).padStart(2, "0")} · BOOST ${String(4 + game.save.upgrades.boost).padStart(2, "0")} · TOP ${String(Math.min(10, Math.round(car.speed / 32 + game.save.upgrades.engine * 0.35))).padStart(2, "0")}`;
  }

  function setScreen(name) {
    game.screen = name;
    for (const [key, element] of Object.entries({
      home: ui.home,
      race: ui.race,
      map: ui.map,
      tuning: ui.tuning,
    }))
      element.classList.toggle("hidden", key !== name);
    if (name === "home") renderHome();
    if (name === "map") renderMap();
    if (name === "tuning") renderTuning();
    if (name === "race") resizeTrack();
  }

  function renderHome() {
    el("credits").textContent = game.save.credits;
    el("car-tag-class").textContent = currentCar().type;
    el("car-tag-name").textContent = currentCar().name.toUpperCase();
    el("car-tag-stats").textContent = statLine();
    const rank =
      game.save.highestRoute >= 60
        ? "CITY LEGEND"
        : game.save.highestRoute >= 35
          ? "NIGHT RUNNER"
          : game.save.highestRoute >= 12
            ? "LINE FINDER"
            : "NIGHT ROOKIE";
    el("record-rank").textContent = rank;
    el("record-wins").textContent = String(game.save.wins).padStart(2, "0");
    el("record-best").textContent = game.save.bestTime
      ? formatLap(game.save.bestTime)
      : "--:--.---";
    const districtIndex = Math.min(
      5,
      Math.floor((game.save.unlockedRoute - 1) / 10),
    );
    el("tour-title").textContent =
      `DISTRICT ${String(districtIndex + 1).padStart(2, "0")} · ${districts[districtIndex].short}`;
    el("tour-detail").textContent =
      `${districts[districtIndex].line} · ${districts[districtIndex].scenery}.`;
    el("tour-count").textContent =
      `${String(game.save.highestRoute).padStart(2, "0")} / 60`;
    el("tour-fill").style.width = `${(game.save.highestRoute / 60) * 100}%`;
    el("race-button").innerHTML = game.save.pending
      ? "RESUME YOUR RUN <span>↗</span>"
      : "START YOUR NEXT RUN <span>↗</span>";
    drawCarPreview(ui.display, currentCar(), true);
  }

  function formatLap(time) {
    if (!time || !Number.isFinite(time)) return "--:--.---";
    const minutes = Math.floor(time / 60);
    const seconds = Math.floor(time % 60);
    const millis = Math.floor((time * 1000) % 1000);
    return `${String(minutes).padStart(2, "0")}:${String(seconds).padStart(2, "0")}.${String(millis).padStart(3, "0")}`;
  }

  function readRouteProgress() {
    return Math.max(0, game.save.highestRoute);
  }

  function startRace(routeNumber = game.save.unlockedRoute, resumed = false) {
    game.route = clamp(routeNumber, 1, 60);
    game.routeInfo = routeById(game.route);
    game.state = "countdown";
    game.elapsed = 0;
    game.time = 0;
    game.progress = 0;
    game.distance = game.routeInfo.length * game.routeInfo.laps;
    game.lap = 1;
    game.boost = 100 + game.save.upgrades.boost * 9;
    game.combo = 0;
    game.comboTimer = 0;
    game.score = 0;
    game.drift = 0;
    game.driftAngle = 0;
    game.driftHeld = false;
    game.boosting = false;
    game.brakeHeld = false;
    game.traffic = [];
    game.props = [];
    game.particles = [];
    game.rivalCars = [];
    game.ghostSamples = [];
    game.currentGhost = game.save.ghosts[game.route] || [];
    game.ghostClock = 0;
    game.shake = 0;
    game.screenFlash = 0;
    game.countdown = resumed ? 1 : 3;
    game.countdownClock = 0;
    game.spawnClock = 0.7;
    game.player = {
      offset: 0,
      velocity: 0,
      speed: 0,
      maxSpeed: currentCar().speed + game.save.upgrades.engine * 8,
      grip: currentCar().grip + game.save.upgrades.grip * 0.08,
      width: currentCar().width,
      paint: paintColors[game.save.paint % paintColors.length],
      damage: 0,
      offroad: 0,
      driftAngle: 0,
      boostHeat: 0,
      passed: 0,
      collisions: 0,
      pickups: 0,
      clean: true,
      wheelAngle: 0,
      sway: 0,
      invincible: 0,
    };
    game.routeInfo = routeById(game.route);
    game.ctx = ui.track.getContext("2d", { alpha: false });
    seedRoad();
    const district = districtFor();
    el("route-name").textContent =
      `${district.short} · ROUTE ${String(game.route).padStart(2, "0")}`;
    el("race-title").textContent = game.routeInfo.name.toUpperCase();
    el("run-time").textContent = "00:00.000";
    el("lap-number").textContent = `LAP 1 / ${game.routeInfo.laps}`;
    el("race-position").innerHTML = `1<span>ST</span>`;
    el("countdown-number").textContent = String(game.countdown);
    el("countdown").classList.remove("done");
    el("race-callout").textContent = game.routeInfo.boss
      ? "NIGHT TOUR FINAL · RIVAL PACK AHEAD"
      : `${game.routeInfo.weather} · ${game.routeInfo.routeClass}`;
    el("race-callout").classList.add("visible");
    setTimeout(() => el("race-callout").classList.remove("visible"), 1500);
    setScreen("race");
    if (resumed && game.save.pending) {
      game.progress = game.save.pending.progress || 0;
      game.elapsed = game.save.pending.elapsed || 0;
      game.boost = game.save.pending.boost ?? game.boost;
      game.player.offset = game.save.pending.offset || 0;
      game.player.speed = game.save.pending.speed || 0;
      game.lap = Math.min(
        game.routeInfo.laps,
        Math.floor(game.progress / game.routeInfo.length) + 1,
      );
      game.countdown = 1;
    }
  }

  function resumeRun() {
    const pending = game.save.pending;
    startRace(pending?.route || game.save.unlockedRoute, Boolean(pending));
  }

  function seedRoad() {
    const seed = game.routeInfo.seed;
    game.roadSegments = Array.from({ length: 200 }, (_, index) => ({
      index,
      side: (index * 91 + seed) % 7,
      light: index % 4 < 2,
      sign: index % 19 === 0,
      lamp: index % 8 === 0,
    }));
  }

  function resizeTrack() {
    const canvas = ui.track;
    if (!canvas?.clientWidth || !canvas?.clientHeight) return;
    const dpr = Math.min(devicePixelRatio || 1, 2);
    const oldWidth = game.width,
      oldHeight = game.height;
    game.width = canvas.clientWidth;
    game.height = canvas.clientHeight;
    canvas.width = Math.round(game.width * dpr);
    canvas.height = Math.round(game.height * dpr);
    game.ctx = canvas.getContext("2d", { alpha: false });
    game.ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    if (game.player) game.player.offset *= game.width / Math.max(1, oldWidth);
    if (game.screen === "race") drawTrack();
  }

  function startAudio() {
    if (!game.save.sound) return;
    if (!game.audio) {
      const Type = window.AudioContext || window.webkitAudioContext;
      if (Type) game.audio = new Type();
    }
    if (game.audio?.state === "suspended") game.audio.resume();
  }

  function note(
    freq,
    duration = 0.08,
    type = "sine",
    volume = 0.025,
    end = null,
  ) {
    if (!game.save.sound) return;
    startAudio();
    if (!game.audio) return;
    const osc = game.audio.createOscillator(),
      gain = game.audio.createGain();
    osc.type = type;
    osc.frequency.setValueAtTime(freq, game.audio.currentTime);
    if (end)
      osc.frequency.exponentialRampToValueAtTime(
        end,
        game.audio.currentTime + duration,
      );
    gain.gain.setValueAtTime(volume, game.audio.currentTime);
    gain.gain.exponentialRampToValueAtTime(
      0.0001,
      game.audio.currentTime + duration,
    );
    osc.connect(gain);
    gain.connect(game.audio.destination);
    osc.start();
    osc.stop(game.audio.currentTime + duration);
  }

  function roadCenter(distance) {
    const seed = game.routeInfo?.seed || 1;
    const bend =
      Math.sin(distance * 0.00105 + seed) * 0.25 +
      Math.sin(distance * 0.00039 + seed * 0.03) * 0.42 +
      Math.sin(distance * 0.0024 + seed * 0.1) * 0.08;
    const local = Math.sin(distance * 0.00017 + seed * 0.2) * 0.13;
    return (bend + local) * game.width * 0.32;
  }

  function groundColor(index) {
    const district = districtFor();
    if (index % 2) return district.darkGround || "#13201e";
    return "#101a19";
  }

  function spawnTraffic() {
    if (game.traffic.length > 11) return;
    const route = game.routeInfo;
    const lanes = [-0.56, -0.18, 0.2, 0.57];
    const lane = lanes[Math.floor(Math.random() * lanes.length)];
    const ahead = game.distance * (0.18 + Math.random() * 0.74);
    const isProp = Math.random() < 0.38;
    const kind = isProp
      ? ["shard", "shard", "boost", "cone", "slick"][
          Math.floor(Math.random() * 5)
        ]
      : ["taxi", "hatch", "van", "rival"][
          Math.floor(Math.random() * Math.min(4, 2 + Math.floor(route.id / 12)))
        ];
    game.traffic.push({
      kind,
      lane,
      ahead,
      speed: isProp ? 0 : rand(85, 180) * route.difficulty,
      phase: rand(0, TAU),
      passed: false,
      color: choice(["#eaa1c9", "#85dcd8", "#ffd180", "#a9a1ed", "#d9e7d0"]),
      radius: isProp ? 12 : 20 + Math.random() * 5,
      collected: false,
    });
  }

  function updateRace(dt) {
    if (game.state === "countdown") {
      game.countdownClock += dt;
      if (game.countdownClock >= 0.75) {
        game.countdownClock = 0;
        game.countdown -= 1;
        if (game.countdown <= 0) {
          game.state = "racing";
          el("countdown-number").textContent = "GO!";
          note(520, 0.22, "triangle", 0.04, 880);
          setTimeout(() => el("countdown").classList.add("done"), 450);
        } else el("countdown-number").textContent = String(game.countdown);
      }
      return;
    }
    if (game.state !== "racing") return;
    game.elapsed += dt;
    game.time += dt;
    game.comboTimer = Math.max(0, game.comboTimer - dt);
    if (!game.comboTimer) game.combo = 0;
    game.shake = Math.max(0, game.shake - dt * 20);
    game.screenFlash = Math.max(0, game.screenFlash - dt * 2);
    game.player.invincible = Math.max(0, game.player.invincible - dt);
    const car = currentCar();
    const input = readSteering();
    const driftHeld =
      game.keys.has("Space") || game.brakeHeld || game.touch.brake;
    const boostHeld =
      game.keys.has("ShiftLeft") ||
      game.keys.has("ShiftRight") ||
      game.touch.boost;
    const gas =
      game.keys.has("ArrowUp") ||
      game.keys.has("KeyW") ||
      game.touch.gas ||
      !game.keys.has("ArrowDown");
    const braking =
      game.keys.has("ArrowDown") || game.keys.has("KeyS") || game.touch.brake;
    const maxSpeed =
      game.player.maxSpeed * (1 + game.save.upgrades.engine * 0.045);
    const enginePull = gas ? 130 : -70;
    const boostActive = boostHeld && game.boost > 0 && !braking;
    game.boosting = boostActive;
    if (boostActive) {
      game.boost = Math.max(0, game.boost - 36 * dt);
      game.player.boostHeat = 1;
    } else {
      game.boost = Math.min(
        100 + game.save.upgrades.boost * 9,
        game.boost + 4.5 * dt,
      );
      game.player.boostHeat = Math.max(0, game.player.boostHeat - dt * 1.2);
    }
    const boostMultiplier = boostActive ? 1.32 * car.boost : 1;
    const speedTarget = clamp(
      (game.player.speed + enginePull * dt) * boostMultiplier,
      braking ? 50 : 90,
      maxSpeed * boostMultiplier,
    );
    game.player.speed = lerp(
      game.player.speed,
      speedTarget,
      1 - Math.pow(0.012, dt),
    );
    const steerRate =
      (0.82 + (game.player.speed / maxSpeed) * 0.95) * game.player.grip;
    game.player.velocity += input * steerRate * dt;
    const damping = driftHeld ? 0.988 : 0.94;
    game.player.velocity *= Math.pow(damping, dt * 60);
    game.player.offset += game.player.velocity * dt * 520;
    game.player.offset = clamp(game.player.offset, -1.18, 1.18);
    game.player.wheelAngle = lerp(game.player.wheelAngle, input * 0.28, dt * 9);
    game.player.sway = lerp(
      game.player.sway,
      input * (driftHeld ? 0.14 : 0.045),
      dt * 4,
    );
    game.player.driftAngle = lerp(
      game.player.driftAngle,
      driftHeld && Math.abs(game.player.velocity) > 0.18
        ? -game.player.velocity * 0.23
        : 0,
      dt * 5,
    );
    game.driftHeld = driftHeld;
    game.driftAngle = game.player.driftAngle;
    if (
      driftHeld &&
      game.player.speed > 135 &&
      Math.abs(game.player.velocity) > 0.12
    ) {
      game.drift +=
        Math.abs(game.player.velocity) * dt * game.player.speed * 0.022;
      game.boost = Math.min(
        100 + game.save.upgrades.boost * 9,
        game.boost +
          Math.abs(game.player.velocity) *
            10 *
            dt *
            (1 + game.save.upgrades.boost * 0.12),
      );
      game.combo = Math.min(12, game.combo + dt * 2.2);
      game.comboTimer = 1.6;
      game.score += Math.floor(
        Math.abs(game.player.velocity) *
          game.player.speed *
          dt *
          game.combo *
          0.12,
      );
      game.save.driftRecord = Math.max(
        game.save.driftRecord,
        Math.floor(game.drift),
      );
      game.player.clean = false;
    }
    if (braking) game.player.speed = Math.max(75, game.player.speed - 230 * dt);
    const roadLimit = 0.83;
    if (Math.abs(game.player.offset) > roadLimit) {
      game.player.offroad = Math.min(1, game.player.offroad + dt * 1.8);
      game.player.speed = Math.max(70, game.player.speed - 210 * dt);
      if (Math.random() < 0.15) emitDust();
      if (game.player.offroad > 0.15) game.player.clean = false;
    } else game.player.offroad = Math.max(0, game.player.offroad - dt * 2.6);
    const previousLap = game.lap;
    game.progress += game.player.speed * dt;
    game.ghostClock += dt;
    if (game.ghostClock >= 0.12) {
      game.ghostClock = 0;
      game.ghostSamples.push({ time: game.elapsed, progress: game.progress, offset: game.player.offset, boost: game.boosting });
    }
    game.lap = Math.min(
      game.routeInfo.laps,
      Math.floor(game.progress / game.routeInfo.length) + 1,
    );
    if (game.lap !== previousLap) {
      callout(`LAP ${game.lap} · THE NIGHT IS STILL YOURS`);
      note(460, 0.19, "triangle", 0.03, 730);
    }
    updateTraffic(dt);
    updateRivals(dt);
    updateProps(dt);
    updateParticles(dt);
    game.spawnClock -= dt;
    if (game.spawnClock <= 0) {
      spawnTraffic();
      game.spawnClock = rand(0.95, 1.7) / game.routeInfo.difficulty;
    }
    game.player.passed = Math.max(
      0,
      game.traffic.filter((item) => item.passed).length,
    );
    if (game.progress >= game.distance) finishRace();
    updateHud();
    if (game.elapsed >= game.checkpointClock + 5) checkpoint();
  }

  function readSteering() {
    let value = 0;
    if (game.keys.has("ArrowLeft") || game.keys.has("KeyA") || game.touch.left)
      value -= 1;
    if (
      game.keys.has("ArrowRight") ||
      game.keys.has("KeyD") ||
      game.touch.right
    )
      value += 1;
    const pads = navigator.getGamepads?.() || [];
    const pad = Array.from(pads).find(Boolean);
    if (pad && Math.abs(pad.axes[0]) > 0.15) value += pad.axes[0];
    return clamp(value, -1, 1);
  }

  function checkpoint() {
    if (game.state !== "racing") return;
    game.checkpointClock = game.elapsed;
    game.save.pending = {
      route: game.route,
      progress: game.progress,
      elapsed: game.elapsed,
      boost: game.boost,
      offset: game.player.offset,
      speed: game.player.speed,
    };
    save(true);
  }

  function updateTraffic(dt) {
    for (const traffic of game.traffic) {
      traffic.ahead -= Math.max(45, game.player.speed - traffic.speed) * dt;
      traffic.phase += dt * 3;
      const overlap =
        Math.abs(traffic.lane - game.player.offset) <
        (traffic.kind === "cone" ? 0.11 : 0.18);
      if (
        traffic.ahead < 92 &&
        traffic.ahead > -14 &&
        overlap &&
        !traffic.collected
      ) {
        if (traffic.kind === "shard" || traffic.kind === "boost")
          collect(traffic);
        else if (traffic.kind === "slick") {
          game.player.speed *= 0.72;
          game.player.velocity += rand(-0.8, 0.8);
          hitCar(traffic);
        } else if (traffic.kind === "cone") {
          game.player.speed *= 0.88;
          game.player.velocity +=
            traffic.lane > game.player.offset ? -0.38 : 0.38;
          traffic.collected = true;
          hitCar(traffic);
        } else hitCar(traffic);
      }
      if (traffic.ahead < -72 && !traffic.passed) {
        traffic.passed = true;
        if (
          !traffic.collected &&
          !["shard", "boost", "cone", "slick"].includes(traffic.kind) &&
          traffic.lane !== 99
        ) {
          game.score += 90;
          game.player.passed += 1;
          game.comboTimer = 2.5;
          game.combo = Math.min(12, game.combo + 0.7);
          if (game.player.passed % 3 === 0)
            game.boost = Math.min(
              100 + game.save.upgrades.boost * 9,
              game.boost + 5,
            );
        }
      }
    }
    game.traffic = game.traffic.filter(
      (item) => item.ahead > -130 && !item.expired,
    );
  }

  function hitCar(traffic) {
    if (game.player.invincible > 0) return;
    game.player.collisions += 1;
    game.player.invincible = 0.62;
    game.player.speed = Math.max(75, game.player.speed - 115);
    game.player.velocity += game.player.offset > traffic.lane ? 0.38 : -0.38;
    game.player.damage = Math.min(1, game.player.damage + 0.16);
    game.shake = 7;
    game.player.clean = false;
    burst(
      game.width * 0.5 + game.player.offset * game.width * 0.27,
      game.height * 0.76,
      "#ffd18a",
      22,
    );
    callout("EASY · RESET YOUR LINE");
    note(130, 0.2, "sawtooth", 0.035, 65);
  }

  function collect(item) {
    item.collected = true;
    game.player.pickups += 1;
    game.save.credits +=
      item.kind === "shard" ? 1 + Math.floor(game.save.upgrades.magnet / 3) : 0;
    game.score += item.kind === "shard" ? 250 : 100;
    if (item.kind === "boost")
      game.boost = Math.min(
        100 + game.save.upgrades.boost * 9,
        game.boost + 26,
      );
    game.combo = Math.min(12, game.combo + 1);
    game.comboTimer = 2.5;
    burst(
      game.width * (0.5 + item.lane * 0.28),
      game.height * 0.72,
      item.kind === "shard" ? "#ffd074" : "#7de8da",
      16,
    );
    game.screenFlash = 0.35;
    note(item.kind === "shard" ? 960 : 650, 0.13, "sine", 0.035, 1450);
    save(true);
  }

  function updateRivals(dt) {
    const total = game.routeInfo.rivals;
    if (game.rivalCars.length === 0) {
      game.rivalCars = Array.from({ length: total }, (_, index) => ({
        id: index,
        progress: game.progress - rand(0, 260),
        speed:
          game.player.maxSpeed * rand(0.82, 1.05) * game.routeInfo.difficulty,
        lane: [-0.55, -0.2, 0.2, 0.55][index % 4],
        color: choice(["#81dfda", "#e991bb", "#ffcb79", "#a19aff"]),
        name: ["MOTH", "LARK", "SUNDAY", "ASTER"][index % 4],
        phase: rand(0, TAU),
      }));
    }
    for (const rival of game.rivalCars) {
      rival.progress +=
        rival.speed *
        dt *
        (1 + Math.sin(game.elapsed * 0.12 + rival.phase) * 0.025);
      rival.lane += Math.sin(game.elapsed * 0.4 + rival.phase) * dt * 0.014;
      rival.lane = clamp(rival.lane, -0.66, 0.66);
    }
  }

  function updateProps(dt) {
    for (const particle of game.particles) {
      particle.x += particle.vx * dt;
      particle.y += particle.vy * dt;
      particle.life -= dt;
      particle.vx *= 0.96;
      particle.vy *= 0.96;
    }
    game.particles = game.particles.filter((p) => p.life > 0);
  }

  function burst(x, y, color, count = 14) {
    for (let i = 0; i < count; i++) {
      const angle = Math.random() * TAU,
        speed = rand(25, 180);
      game.particles.push({
        x,
        y,
        vx: Math.cos(angle) * speed,
        vy: Math.sin(angle) * speed,
        color,
        life: rand(0.22, 0.7),
        radius: rand(1.2, 3.4),
      });
    }
  }

  function emitDust() {
    const side = game.player.offset > 0 ? 1 : -1;
    burst(game.width * (0.5 + side * 0.42), game.height * 0.88, "#d4b8a088", 2);
  }

  function callout(text) {
    el("race-callout").textContent = text;
    el("race-callout").classList.add("visible");
    clearTimeout(game.lastMessage);
    game.lastMessage = setTimeout(
      () => el("race-callout").classList.remove("visible"),
      950,
    );
  }

  function updateHud() {
    el("run-time").textContent = formatLap(game.elapsed);
    const lapProgress = game.progress / game.distance;
    el("lap-number").textContent = `LAP ${game.lap} / ${game.routeInfo.laps}`;
    el("lap-fill").style.width = `${clamp(lapProgress * 100, 0, 100)}%`;
    const position =
      1 +
      game.rivalCars.filter((rival) => rival.progress > game.progress).length;
    const suffix =
      position === 1
        ? "ST"
        : position === 2
          ? "ND"
          : position === 3
            ? "RD"
            : "TH";
    el("race-position").innerHTML = `${position}<span>${suffix}</span>`;
    el("speed-number").textContent = String(
      Math.round(game.player.speed * 0.7),
    ).padStart(3, "0");
    const maxBoost = 100 + game.save.upgrades.boost * 9;
    el("boost-fill").style.width =
      `${clamp((game.boost / maxBoost) * 100, 0, 100)}%`;
    el("boost-percent").textContent =
      `${Math.round((game.boost / maxBoost) * 100)}%`;
    el("drive-status").textContent =
      game.player.offroad > 0.1
        ? "OFF THE LINE · EASE BACK"
        : game.driftHeld && Math.abs(game.player.velocity) > 0.2
          ? `DRIFT × ${Math.max(1, Math.floor(game.combo))} · BOOST BUILDING`
          : game.boosting
            ? "AFTERBURNER · HOLD THE LINE"
            : game.player.clean
              ? "GRIP GOOD · CLEAN LINE"
              : "FIND THE NEXT CLEAN LINE";
  }

  function finishRace() {
    if (game.state !== "racing") return;
    game.state = "result";
    const rank =
      1 +
      game.rivalCars.filter((rival) => rival.progress > game.progress).length;
    const placeStars = rank === 1 ? 2 : rank <= 3 ? 1 : 0;
    const cleanStar = game.player.collisions === 0 && game.player.clean ? 1 : 0;
    const routeStars = Math.min(3, placeStars + cleanStar);
    const oldStars = game.save.routeStars[game.route] || 0;
    const reward = Math.max(
      4,
      10 + placeStars * 5 + cleanStar * 4 + Math.floor(game.score / 5000),
    );
    game.save.credits += reward;
    game.save.routeStars[game.route] = Math.max(oldStars, routeStars);
    game.save.highestRoute = Math.max(game.save.highestRoute, game.route);
    game.save.unlockedRoute = Math.min(
      60,
      Math.max(game.save.unlockedRoute, game.route + 1),
    );
    game.save.wins += rank <= 3 ? 1 : 0;
    game.save.totalRuns += 1;
    game.save.score += game.score;
    game.save.bestScore = Math.max(game.save.bestScore, game.score);
    const oldTime = game.save.routeTimes[game.route] || Infinity;
    const isBest = game.elapsed < oldTime;
    if (isBest) {
      game.save.routeTimes[game.route] = game.elapsed;
      game.save.ghosts[game.route] = game.ghostSamples.slice(0, 900);
    }
    game.save.bestTime = game.save.bestTime
      ? Math.min(game.save.bestTime, game.elapsed)
      : game.elapsed;
    game.save.pending = null;
    unlockCars();
    checkBadges();
    save(true);
    showResults(rank, routeStars, reward, isBest);
    if (rank === 1) note(660, 0.4, "sine", 0.05, 1100);
  }

  function showResults(rank, stars, reward, isBest) {
    el("result-modal").classList.remove("hidden");
    const first = rank === 1;
    el("result-kicker").textContent = first
      ? "NIGHT TOUR · FIRST PLACE"
      : rank <= 3
        ? "NIGHT TOUR · PODIUM FINISH"
        : "NIGHT TOUR · ROUTE COMPLETE";
    el("result-stamp").textContent = first ? "✦" : rank <= 3 ? "◈" : "⌁";
    el("result-title").textContent = first
      ? ["YOU FOUND THE LINE.", "THE CITY IS YOURS.", "WHAT A LAST CORNER."][
          game.route % 3
        ]
      : rank <= 3
        ? "A LOVELY RUN HOME."
        : "THE ROAD KNOWS YOUR NAME.";
    el("result-copy").textContent = isBest
      ? "New personal best. The old ghost is somewhere behind you now."
      : "The route is in the log. Take what you learned into the next night.";
    el("result-stats").innerHTML =
      `<span>TIME <b>${formatLap(game.elapsed)}</b></span><span>STYLE <b>${Math.floor(game.score).toLocaleString()}</b></span><span>SHARDS <b>✧ ${reward}</b></span>`;
    el("medal-row").innerHTML = [0, 1, 2]
      .map((i) => `<span class="${i < stars ? "earned" : ""}">★</span>`)
      .join("");
    el("next-route").textContent =
      game.route < 60 ? "NEXT ROUTE ↗" : "TOUR COMPLETE ✦";
    el("next-route").onclick = () => {
      closeModal("result-modal");
      if (game.route < 60) startRace(game.route + 1);
      else setScreen("map");
    };
  }

  function unlockCars() {
    for (const car of carModels)
      if (
        game.save.highestRoute >= car.unlock &&
        !game.save.unlockedCars.includes(car.id)
      ) {
        game.save.unlockedCars.push(car.id);
        callout(`NEW GARAGE ARRIVAL · ${car.name.toUpperCase()}`);
      }
  }

  function checkBadges() {
    const tests = [
      ["first-night", game.save.highestRoute >= 1],
      ["clean-corner", game.player.collisions === 0 && game.player.clean],
      ["long-drift", game.drift >= 800],
      ["collector", game.save.credits >= 100],
      ["half-tour", game.save.highestRoute >= 30],
      ["tour-complete", game.save.highestRoute >= 60],
    ];
    for (const [name, done] of tests)
      if (done && !game.save.achievements.includes(name))
        game.save.achievements.push(name);
  }

  function renderMap() {
    const unlockedDistrict = Math.min(
      5,
      Math.floor((game.save.unlockedRoute - 1) / 10),
    );
    const tabs = el("district-tabs");
    tabs.replaceChildren();
    districts.forEach((district, index) => {
      const button = document.createElement("button");
      button.className =
        "district-tab" +
        (index === game.district ? " selected" : "") +
        (index > unlockedDistrict ? " locked" : "");
      button.disabled = index > unlockedDistrict;
      const count = Math.min(
        10,
        Math.max(0, game.save.highestRoute - index * 10),
      );
      button.innerHTML = `<b>${String(index + 1).padStart(2, "0")} · ${district.short}</b>${count} / 10 ROUTES`;
      button.addEventListener("click", () => {
        game.district = index;
        renderMap();
      });
      tabs.append(button);
    });
    const grid = el("route-grid");
    grid.replaceChildren();
    routes
      .filter((route) => route.district === game.district)
      .forEach((route) => {
        const button = document.createElement("button");
        const stars = game.save.routeStars[route.id] || 0;
        button.className =
          "route-card" +
          (route.id <= game.save.highestRoute ? " completed" : "") +
          (route.id === game.save.unlockedRoute ? " current" : "") +
          (route.id <= game.save.unlockedRoute ? " available" : "");
        button.disabled = route.id > game.save.unlockedRoute;
        button.innerHTML = `${String(route.id).padStart(2, "0")}${route.boss ? "<small>✦ FINAL</small>" : stars ? `<small>${"★".repeat(stars)}</small>` : ""}`;
        button.title = `${route.name} · ${route.weather}`;
        button.addEventListener("click", () => startRace(route.id));
        grid.append(button);
      });
    el("map-best").textContent =
      `PERSONAL BEST ${game.save.bestTime ? formatLap(game.save.bestTime) : "--:--.---"}`;
  }

  function renderTuning() {
    el("tuning-credits").textContent = game.save.credits;
    const car = currentCar();
    el("tune-model-class").textContent = car.type;
    el("tune-model-name").textContent = car.name.toUpperCase();
    el("tune-model-copy").textContent = car.copy;
    drawCarPreview(ui.tune, car, false);
    const select = el("car-select");
    select.replaceChildren();
    carModels.forEach((model) => {
      const button = document.createElement("button");
      const unlocked = game.save.unlockedCars.includes(model.id);
      button.className = game.save.car === model.id ? "selected" : "";
      button.disabled = !unlocked;
      button.textContent = unlocked
        ? model.name.toUpperCase()
        : `ROUTE ${model.unlock}`;
      button.addEventListener("click", () => {
        game.save.car = model.id;
        save(true);
        renderTuning();
      });
      select.append(button);
    });
    const list = el("upgrade-list");
    list.replaceChildren();
    for (const spec of upgradeSpecs) {
      const level = game.save.upgrades[spec.key];
      const cost = Math.floor(spec.base * 1.48 ** level);
      const card = document.createElement("div");
      card.className = "upgrade-item";
      card.innerHTML = `<span>${spec.icon}</span><div><b>${spec.name} · ${level}/${spec.cap}</b><p>${spec.text}</p></div><button ${level >= spec.cap || game.save.credits < cost ? "disabled" : ""}>${level >= spec.cap ? "MAX" : `✧ ${cost}`}</button>`;
      card
        .querySelector("button")
        .addEventListener("click", () => buyUpgrade(spec, cost));
      list.append(card);
    }
    const paints = el("paint-swatches");
    paints.replaceChildren();
    paintColors.forEach((color, index) => {
      const button = document.createElement("button");
      button.className =
        "paint-swatch" + (game.save.paint === index ? " selected" : "");
      button.style.background = color;
      button.title = `Night paint ${index + 1}`;
      button.addEventListener("click", () => {
        game.save.paint = index;
        save(true);
        renderTuning();
      });
      paints.append(button);
    });
  }

  function buyUpgrade(spec, cost) {
    if (game.save.credits < cost || game.save.upgrades[spec.key] >= spec.cap)
      return;
    game.save.credits -= cost;
    game.save.upgrades[spec.key] += 1;
    save(true);
    renderTuning();
    note(700, 0.16, "triangle", 0.035, 1120);
  }

  function drawCarPreview(canvas, car, hero) {
    if (!canvas?.clientWidth || !canvas?.clientHeight) return;
    const ratio = Math.min(devicePixelRatio || 1, 2);
    canvas.width = Math.round(canvas.clientWidth * ratio);
    canvas.height = Math.round(canvas.clientHeight * ratio);
    const ctx = canvas.getContext("2d");
    ctx.setTransform(ratio, 0, 0, ratio, 0, 0);
    const w = canvas.clientWidth,
      h = canvas.clientHeight;
    ctx.clearRect(0, 0, w, h);
    const glow = ctx.createRadialGradient(
      w * 0.51,
      h * 0.57,
      5,
      w * 0.51,
      h * 0.57,
      w * 0.47,
    );
    glow.addColorStop(0, `${paintColors[game.save.paint]}25`);
    glow.addColorStop(1, "#0000");
    ctx.fillStyle = glow;
    ctx.fillRect(0, 0, w, h);
    for (let i = 0; i < 62; i++) {
      const x = (((i * 73 + 17) % 997) / 997) * w,
        y = (((i * 131 + 71) % 991) / 991) * h;
      ctx.globalAlpha = 0.22 + (Math.sin(game.time * 2 + i) + 1) * 0.18;
      ctx.fillStyle = i % 7 ? "#e8d9eb" : car.color;
      ctx.fillRect(x, y, i % 9 === 0 ? 2 : 1, i % 9 === 0 ? 2 : 1);
    }
    ctx.globalAlpha = 1;
    const color = paintColors[game.save.paint] || car.color;
    drawCar(
      ctx,
      w * 0.52,
      h * (hero ? 0.56 : 0.53),
      Math.min(w, h) * (hero ? 0.0033 : 0.004),
      car,
      color,
      game.time,
      0,
      false,
      true,
    );
  }

  function drawCar(
    ctx,
    x,
    y,
    scale,
    car,
    color,
    time,
    steer = 0,
    boost = false,
    showcase = false,
  ) {
    ctx.save();
    ctx.translate(x, y);
    ctx.rotate(steer * 0.08);
    ctx.scale(scale, scale);
    const flicker = 0.86 + Math.sin(time * 34) * 0.1;
    ctx.shadowColor = color;
    ctx.shadowBlur = showcase ? 26 : 14;
    ctx.fillStyle = boost ? "#82e8e8" : "#ff776f";
    ctx.globalAlpha = 0.72 * flicker;
    ctx.beginPath();
    ctx.moveTo(-23, -2);
    ctx.lineTo(-38 - (boost ? 18 : 8) * flicker, -9);
    ctx.lineTo(-31, 0);
    ctx.lineTo(-38 - (boost ? 18 : 8) * flicker, 9);
    ctx.lineTo(-23, 2);
    ctx.fill();
    ctx.globalAlpha = 1;
    const body = color;
    const shadow = "#241e2c";
    ctx.fillStyle = shadow;
    rounded(ctx, -38, -28, 75, 56, 18);
    ctx.fill();
    ctx.fillStyle = body;
    ctx.strokeStyle = "#fff6";
    ctx.lineWidth = 1.4;
    ctx.beginPath();
    ctx.moveTo(39, 0);
    ctx.lineTo(24, -16);
    ctx.lineTo(3, -22);
    ctx.lineTo(-16, -25);
    ctx.lineTo(-31, -17);
    ctx.lineTo(-36, -8);
    ctx.lineTo(-36, 8);
    ctx.lineTo(-31, 17);
    ctx.lineTo(-16, 25);
    ctx.lineTo(3, 22);
    ctx.lineTo(24, 16);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    ctx.fillStyle = "#171a25";
    ctx.beginPath();
    ctx.moveTo(22, -12);
    ctx.lineTo(5, -16);
    ctx.lineTo(-9, -15);
    ctx.lineTo(-17, -8);
    ctx.lineTo(11, -7);
    ctx.closePath();
    ctx.fill();
    ctx.beginPath();
    ctx.moveTo(22, 12);
    ctx.lineTo(5, 16);
    ctx.lineTo(-9, 15);
    ctx.lineTo(-17, 8);
    ctx.lineTo(11, 7);
    ctx.closePath();
    ctx.fill();
    ctx.fillStyle = car.trim;
    ctx.globalAlpha = 0.8;
    ctx.beginPath();
    ctx.moveTo(12, -3);
    ctx.lineTo(34, 0);
    ctx.lineTo(12, 3);
    ctx.closePath();
    ctx.fill();
    ctx.globalAlpha = 1;
    ctx.fillStyle = "#fff2dc";
    ctx.shadowColor = "#fff0bd";
    ctx.shadowBlur = 8;
    for (const side of [-1, 1]) {
      rounded(ctx, 30, side * 14 - 3, 5, 6, 2);
      ctx.fill();
    }
    ctx.shadowBlur = 0;
    ctx.fillStyle = "#fb6e83";
    for (const side of [-1, 1]) {
      rounded(ctx, -33, side * 14 - 4, 5, 8, 2);
      ctx.fill();
    }
    ctx.fillStyle = "#25232d";
    for (const side of [-1, 1]) {
      rounded(ctx, -16, side * 25 - 6, 18, 12, 4);
      ctx.fill();
      rounded(ctx, 15, side * 24 - 6, 16, 12, 4);
      ctx.fill();
    }
    ctx.fillStyle = "#81909c";
    for (const side of [-1, 1]) {
      ctx.beginPath();
      ctx.arc(-7, side * 25, 3, 0, TAU);
      ctx.arc(22, side * 24, 3, 0, TAU);
      ctx.fill();
    }
    ctx.strokeStyle = `${car.trim}99`;
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(-12, -20);
    ctx.lineTo(-12, 20);
    ctx.moveTo(4, -15);
    ctx.lineTo(4, 15);
    ctx.stroke();
    ctx.fillStyle = "#ffffff88";
    rounded(ctx, 0, -2, 18, 4, 2);
    ctx.fill();
    ctx.restore();
  }

  function rounded(ctx, x, y, w, h, r) {
    ctx.beginPath();
    ctx.roundRect(x, y, w, h, r);
  }

  function drawTrack() {
    const ctx = game.ctx;
    if (!ctx || !game.routeInfo) return;
    const w = game.width,
      h = game.height,
      district = districtFor();
    ctx.save();
    if (game.shake)
      ctx.translate(
        rand(-game.shake, game.shake),
        rand(-game.shake, game.shake),
      );
    const sky = ctx.createLinearGradient(0, 0, 0, h * 0.68);
    sky.addColorStop(0, district.sky[0]);
    sky.addColorStop(0.54, district.sky[1]);
    sky.addColorStop(1, district.sky[2]);
    ctx.fillStyle = sky;
    ctx.fillRect(0, 0, w, h);
    drawSkyline(ctx, w, h, district);
    const horizon = h * 0.35;
    const rows = 34;
    let previous = null;
    for (let i = 0; i <= rows; i++) {
      const perspective = i / rows;
      const y = horizon + perspective * perspective * (h - horizon);
      const worldAhead = (1 - perspective) * 1400;
      const center =
        w * 0.5 +
        (roadCenter(game.progress + worldAhead) - roadCenter(game.progress)) *
          perspective *
          0.86 -
        game.player?.offset * w * 0.17 * (1 - perspective);
      const roadHalf = w * (0.045 + perspective * 0.49);
      const edgeWidth = 3 + perspective * 13;
      const strip = Math.floor((game.progress + worldAhead) / 54);
      if (previous) {
        const { y: py, center: pc, half: ph, p: pp } = previous;
        ctx.fillStyle = strip % 2 ? "#17261f" : "#121e1a";
        ctx.fillRect(0, py, w, y - py + 1);
        ctx.fillStyle = district.road;
        ctx.beginPath();
        ctx.moveTo(pc - ph, py);
        ctx.lineTo(center - roadHalf, y);
        ctx.lineTo(center + roadHalf, y);
        ctx.lineTo(pc + ph, py);
        ctx.closePath();
        ctx.fill();
        const edgeColor = strip % 2 ? "#f4a6c6" : "#e7d7cb";
        ctx.fillStyle = edgeColor;
        ctx.beginPath();
        ctx.moveTo(pc - ph - edgeWidth, py);
        ctx.lineTo(center - roadHalf - edgeWidth, y);
        ctx.lineTo(center - roadHalf, y);
        ctx.lineTo(pc - ph, py);
        ctx.closePath();
        ctx.fill();
        ctx.beginPath();
        ctx.moveTo(pc + ph, py);
        ctx.lineTo(center + roadHalf, y);
        ctx.lineTo(center + roadHalf + edgeWidth, y);
        ctx.lineTo(pc + ph + edgeWidth, py);
        ctx.closePath();
        ctx.fill();
        if (strip % 3 === 0) {
          ctx.fillStyle = `${district.roadLine}${Math.round(70 + pp * 130).toString(16)}`;
          const dash = Math.max(1, pp * 8);
          ctx.fillRect(center - dash / 2, py, dash, y - py + 1);
        }
        drawRoadMarkers(
          ctx,
          pc,
          ph,
          py,
          center,
          roadHalf,
          y,
          pp,
          strip,
          district,
        );
      }
      previous = { y, center, half: roadHalf, p: perspective };
    }
    drawWorldObjects(ctx, horizon, district);
    drawRivals(ctx, horizon);
    drawGhostCar(ctx, w, h);
    drawPlayerCar(ctx, w, h);
    drawRaceParticles(ctx);
    if (game.screenFlash > 0) {
      ctx.fillStyle = `rgba(255,255,235,${game.screenFlash * 0.24})`;
      ctx.fillRect(0, 0, w, h);
    }
    ctx.restore();
  }

  function drawSkyline(ctx, w, h, district) {
    const horizon = h * 0.36;
    for (let layer = 0; layer < 3; layer++) {
      const base = horizon + layer * h * 0.06;
      const count = 26;
      for (let i = 0; i < count; i++) {
        const seed = (i * 71 + game.routeInfo.seed * (layer + 1)) % 997;
        const x =
          (((seed / 997) * w + game.progress * (0.012 + layer * 0.007)) %
            (w + 100)) -
          50;
        const buildingW = w * (0.018 + ((i * 13) % 7) * 0.008);
        const buildingH = h * (0.07 + ((i * 23 + layer * 17) % 11) * 0.013);
        ctx.fillStyle =
          layer === 0 ? "#171923" : layer === 1 ? "#211d2a" : "#2b2030";
        ctx.fillRect(x, base - buildingH, buildingW, buildingH + h * 0.07);
        if (i % 2 === 0) {
          ctx.fillStyle = i % 3 ? `${district.color}55` : "#ffda9166";
          for (let row = 0; row < 3; row++)
            for (let col = 0; col < 2; col++) {
              if ((i + row + col) % 3)
                ctx.fillRect(
                  x + 4 + col * 7,
                  base - buildingH + 8 + row * 10,
                  2,
                  3,
                );
            }
        }
      }
    }
    const moonX = w * 0.77,
      moonY = h * 0.14,
      moonR = Math.min(w, h) * 0.055;
    const moon = ctx.createRadialGradient(
      moonX,
      moonY,
      1,
      moonX,
      moonY,
      moonR * 2.4,
    );
    moon.addColorStop(0, `${district.color}55`);
    moon.addColorStop(1, "#0000");
    ctx.fillStyle = moon;
    ctx.beginPath();
    ctx.arc(moonX, moonY, moonR * 2.4, 0, TAU);
    ctx.fill();
    ctx.fillStyle = "#ffe9d4";
    ctx.globalAlpha = 0.75;
    ctx.beginPath();
    ctx.arc(moonX, moonY, moonR * 0.52, 0, TAU);
    ctx.fill();
    ctx.globalAlpha = 1;
  }

  function drawRoadMarkers(
    ctx,
    pc,
    ph,
    py,
    center,
    half,
    y,
    p,
    strip,
    district,
  ) {
    if (strip % 5 !== 0) return;
    const size = 2 + p * 14;
    for (const side of [-1, 1]) {
      const x = center + side * (half + size * 1.6);
      ctx.fillStyle = `${district.color}${Math.round(p * 140 + 30).toString(16)}`;
      ctx.shadowColor = district.color;
      ctx.shadowBlur = p * 10;
      if (strip % 10 === 0) {
        ctx.fillRect(x - size * 0.45, y - size * 4, size * 0.9, size * 4);
        ctx.fillStyle = "#ffe9c0";
        ctx.fillRect(x - size * 0.25, y - size * 3.6, size * 0.5, size * 0.45);
      } else {
        ctx.beginPath();
        ctx.arc(x, y - size * 0.9, size * 0.5, 0, TAU);
        ctx.fill();
      }
      ctx.shadowBlur = 0;
    }
  }

  function drawWorldObjects(ctx, horizon, district) {
    for (const traffic of game.traffic) {
      const depth = 1 - clamp(traffic.ahead / 1400, 0, 1);
      if (depth < 0.08 || depth > 1.08) continue;
      const y = horizon + depth * depth * (game.height * 0.72);
      const roadHalf = game.width * (0.045 + depth * 0.49);
      const center =
        game.width * 0.5 +
        (roadCenter(game.progress + traffic.ahead) -
          roadCenter(game.progress)) *
          depth *
          0.86;
      const x = center + traffic.lane * roadHalf;
      const scale = 0.18 + depth * 1.05;
      if (traffic.kind === "shard" || traffic.kind === "boost") {
        const bob = Math.sin(traffic.phase) * 4 * depth;
        ctx.save();
        ctx.translate(x, y - 14 * depth + bob);
        ctx.rotate(game.time * 0.8);
        const color = traffic.kind === "shard" ? "#ffd074" : "#7cead6";
        ctx.shadowColor = color;
        ctx.shadowBlur = 14 * depth;
        ctx.fillStyle = `${color}55`;
        ctx.strokeStyle = color;
        ctx.lineWidth = Math.max(1, depth * 2);
        ctx.beginPath();
        ctx.moveTo(0, -11 * scale);
        ctx.lineTo(8 * scale, 0);
        ctx.lineTo(0, 11 * scale);
        ctx.lineTo(-8 * scale, 0);
        ctx.closePath();
        ctx.fill();
        ctx.stroke();
        ctx.restore();
      } else if (traffic.kind === "cone" || traffic.kind === "slick") {
        ctx.save();
        ctx.translate(x, y);
        ctx.scale(scale, scale);
        ctx.fillStyle = traffic.kind === "cone" ? "#ffae72" : "#729dd9";
        ctx.shadowColor = ctx.fillStyle;
        ctx.shadowBlur = 6;
        if (traffic.kind === "cone") {
          ctx.beginPath();
          ctx.moveTo(0, -18);
          ctx.lineTo(11, 12);
          ctx.lineTo(-11, 12);
          ctx.closePath();
          ctx.fill();
          ctx.fillStyle = "#fff0ce";
          ctx.fillRect(-6, 2, 12, 3);
        } else {
          ctx.globalAlpha = 0.55;
          ctx.beginPath();
          ctx.ellipse(0, 0, 31, 12, 0, 0, TAU);
          ctx.fill();
        }
        ctx.restore();
      } else {
        drawCar(
          ctx,
          x,
          y,
          scale * 0.54,
          { ...currentCar(), color: traffic.color, trim: "#f7ecdb" },
          traffic.color,
          traffic.phase,
          Math.sin(traffic.phase) * 0.06,
          false,
          false,
        );
      }
    }
  }

  function drawRivals(ctx, horizon) {
    for (const rival of game.rivalCars) {
      const ahead = rival.progress - game.progress;
      if (ahead < 28 || ahead > 1050) continue;
      const depth = 1 - ahead / 1200;
      const y = horizon + depth * depth * game.height * 0.72;
      const roadHalf = game.width * (0.045 + depth * 0.49);
      const center =
        game.width * 0.5 +
        (roadCenter(game.progress + ahead) - roadCenter(game.progress)) *
          depth *
          0.86;
      const x = center + rival.lane * roadHalf;
      drawCar(
        ctx,
        x,
        y,
        (0.1 + depth) * 0.48,
        { ...currentCar(), color: rival.color, trim: "#fff3d6" },
        rival.color,
        game.time + rival.phase,
        0,
        false,
        false,
      );
    }
  }

  function ghostAt(time) {
    const samples = game.currentGhost;
    if (!samples || samples.length < 2) return null;
    let low = 0;
    let high = samples.length - 1;
    while (low < high) {
      const middle = Math.floor((low + high) / 2);
      if (samples[middle].time < time) low = middle + 1;
      else high = middle;
    }
    const after = samples[low];
    const before = samples[Math.max(0, low - 1)];
    const span = Math.max(0.001, after.time - before.time);
    const blend = clamp((time - before.time) / span, 0, 1);
    return {
      offset: lerp(before.offset, after.offset, blend),
      progress: lerp(before.progress, after.progress, blend),
      boost: after.boost,
    };
  }

  function drawGhostCar(ctx, w, h) {
    const ghost = ghostAt(game.elapsed);
    if (!ghost || game.state !== "racing") return;
    const progressGap = ghost.progress - game.progress;
    const x = w * 0.5 + ghost.offset * w * 0.535;
    const y = h * 0.77 - clamp(progressGap / 1100, -0.24, 0.24) * h;
    ctx.save();
    ctx.globalAlpha = 0.3;
    drawCar(ctx, x, y, w * 0.0011 * currentCar().width, currentCar(), "#9cfff1", game.time, 0, ghost.boost, false);
    ctx.restore();
  }

  function drawPlayerCar(ctx, w, h) {
    if (!game.player) return;
    const roadHalf = w * 0.535;
    const x = w * 0.5 + game.player.offset * roadHalf;
    const y = h * 0.77;
    const car = { ...currentCar(), color: game.player.paint };
    ctx.save();
    if (game.player.invincible > 0 && Math.floor(game.time * 22) % 2)
      ctx.globalAlpha = 0.6;
    drawCar(
      ctx,
      x,
      y,
      w * 0.0011 * currentCar().width,
      car,
      game.player.paint,
      game.player.driftAngle,
      game.boosting,
      false,
    );
    if (game.player.offroad > 0.1) {
      ctx.globalAlpha = 0.12 + game.player.offroad * 0.08;
      ctx.fillStyle = "#d7b690";
      ctx.beginPath();
      ctx.ellipse(x, y + 26, 68, 18, 0, 0, TAU);
      ctx.fill();
    }
    ctx.restore();
  }

  function drawRaceParticles(ctx) {
    for (const particle of game.particles) {
      ctx.globalAlpha = clamp(particle.life / 0.8, 0, 1);
      ctx.fillStyle = particle.color;
      ctx.shadowColor = particle.color;
      ctx.shadowBlur = 7;
      ctx.beginPath();
      ctx.arc(particle.x, particle.y, particle.radius, 0, TAU);
      ctx.fill();
    }
    ctx.globalAlpha = 1;
    ctx.shadowBlur = 0;
  }

  function frame(now) {
    const dt = game.last ? Math.min(0.05, (now - game.last) / 1000) : 0;
    game.last = now;
    game.time += dt;
    if (
      game.screen === "race" &&
      game.state !== "paused" &&
      game.state !== "result"
    )
      updateRace(dt);
    if (game.screen === "race") drawTrack();
    if (game.screen === "home") drawCarPreview(ui.display, currentCar(), true);
    if (game.screen === "tuning") drawCarPreview(ui.tune, currentCar(), false);
    requestAnimationFrame(frame);
  }

  function drawCarPreviewPlaceholder() {}

  function checkpointPending(clear = false) {
    if (clear || game.state !== "racing") {
      game.save.pending = null;
      return;
    }
    game.save.pending = {
      route: game.route,
      progress: game.progress,
      elapsed: game.elapsed,
      boost: game.boost,
      offset: game.player.offset,
      speed: game.player.speed,
    };
  }

  function buy(spec, cost) {
    const current = game.save.upgrades[spec.key];
    if (current >= spec.cap || game.save.credits < cost) return;
    game.save.credits -= cost;
    game.save.upgrades[spec.key] = current + 1;
    save(true);
    renderTuning();
    note(620, 0.15, "triangle", 0.03, 980);
  }

  function closeModal(name) {
    el(name).classList.add("hidden");
  }

  function finishForfeit() {
    checkpointPending(true);
    game.state = "idle";
    closeModal("pause-modal");
    setScreen("home");
    save(true);
  }

  function togglePause() {
    if (game.state === "paused") {
      game.state = "racing";
      closeModal("pause-modal");
      game.last = performance.now();
      return;
    }
    if (game.state !== "racing" && game.state !== "countdown") return;
    game.state = "paused";
    checkpointPending();
    save(true);
    el("pause-modal").classList.remove("hidden");
  }

  function bind() {
    el("race-button").addEventListener("click", resumeRun);
    el("routes-button").addEventListener("click", () => setScreen("map"));
    el("tour-map-button").addEventListener("click", () => setScreen("map"));
    el("garage-button").addEventListener("click", () => setScreen("tuning"));
    el("race-home").addEventListener("click", () => {
      checkpointPending();
      save(true);
      setScreen("home");
    });
    el("map-home").addEventListener("click", () => setScreen("home"));
    el("tuning-home").addEventListener("click", () => setScreen("home"));
    el("pause-button").addEventListener("click", togglePause);
    el("resume-race").addEventListener("click", togglePause);
    el("quit-race").addEventListener("click", finishForfeit);
    el("result-garage").addEventListener("click", () => {
      closeModal("result-modal");
      setScreen("home");
    });
    el("map-next").addEventListener("click", () =>
      startRace(game.save.unlockedRoute),
    );
    el("sound-toggle").addEventListener("click", () => {
      game.save.sound = !game.save.sound;
      el("sound-toggle").textContent = game.save.sound ? "◖))" : "◖×";
      save(true);
      if (game.save.sound) note(500, 0.1);
    });
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
      if (event.code === "Escape" || event.code === "KeyP") togglePause();
      if (event.code === "ShiftLeft" || event.code === "ShiftRight")
        startAudio();
    });
    document.addEventListener("keyup", (event) => game.keys.delete(event.code));
    document.querySelectorAll("[data-steer]").forEach((button) => {
      const direction = button.dataset.steer;
      button.addEventListener("pointerdown", (event) => {
        event.preventDefault();
        game.touch[direction] = true;
      });
      ["pointerup", "pointercancel", "pointerleave"].forEach((type) =>
        button.addEventListener(type, () => {
          game.touch[direction] = false;
        }),
      );
    });
    document.querySelectorAll("[data-pedal]").forEach((button) => {
      const name = button.dataset.pedal;
      button.addEventListener("pointerdown", (event) => {
        event.preventDefault();
        game.touch[name] = true;
        game.brakeHeld = name === "brake";
        game.driftHeld = name === "brake";
        startAudio();
      });
      ["pointerup", "pointercancel", "pointerleave"].forEach((type) =>
        button.addEventListener(type, () => {
          game.touch[name] = false;
          game.brakeHeld = false;
          game.driftHeld = false;
        }),
      );
    });
    el("track-canvas").addEventListener("pointerdown", () => startAudio());
    el("race-boost").addEventListener("pointerdown", (event) => {
      event.preventDefault();
      game.touch.boost = true;
      startAudio();
    });
    ["pointerup", "pointercancel", "pointerleave"].forEach((type) =>
      el("race-boost").addEventListener(type, () => (game.touch.boost = false)),
    );
    window.addEventListener("resize", () => {
      resizeTrack();
      drawCarPreview(ui.display, currentCar(), true);
      drawCarPreview(ui.tune, currentCar(), false);
    });
    window.addEventListener("beforeunload", () => {
      checkpointPending();
      save(true);
    });
    document.addEventListener("visibilitychange", () => {
      if (
        document.hidden &&
        (game.state === "racing" || game.state === "countdown")
      )
        togglePause();
    });
  }

  function init() {
    bind();
    resizeTrack();
    renderHome();
    requestAnimationFrame(frame);
  }

  init();
})();
