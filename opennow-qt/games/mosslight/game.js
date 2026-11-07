(() => {
  "use strict";
  const SAVE_KEY = "opennow.mosslight.v1";
  const SIZE = 8;
  const TYPES = ["moon", "moss", "amber", "bloom", "dew"];
  const SYMBOL = {
    moon: "✧",
    moss: "❋",
    amber: "✿",
    bloom: "❀",
    dew: "◇",
    wild: "☼",
  };
  const NAMES = {
    moon: "moon flower",
    moss: "moss sprig",
    amber: "amber seed",
    bloom: "night bloom",
    dew: "dew drop",
  };
  const COLORS = {
    moon: "#b7c7ff",
    moss: "#a2e0a5",
    amber: "#f1c67b",
    bloom: "#ff9bca",
    dew: "#82ded8",
    wild: "#fff0ab",
  };
  const gardens = [
    {
      name: "The First Patch",
      short: "FIRST PATCH",
      color: "#a6de9f",
      icon: "☾",
      friend: "Moss the Mouse",
      place: "A window in the leaves",
      line: "I saved the last little lantern for you. The roots have been waiting to see it.",
      plants: ["moss", "moon"],
      scene: "The first patch is a quiet pocket beneath the old moon tree.",
    },
    {
      name: "Bluebell Bank",
      short: "BLUEBELL BANK",
      color: "#9dbdff",
      icon: "☁",
      friend: "Pip the Moth",
      place: "A blue hour breeze",
      line: "The flowers turn their faces toward wherever the kindest light is.",
      plants: ["moon", "dew"],
      scene: "A sloping bank where every raindrop catches a small blue sky.",
    },
    {
      name: "Amber Hollow",
      short: "AMBER HOLLOW",
      color: "#ffce81",
      icon: "⌂",
      friend: "Old Wren",
      place: "The warm little pocket",
      line: "Autumn came early. I kept the last warm colors for your path.",
      plants: ["amber", "bloom"],
      scene: "An amber hollow tucked between sleepy roots and a stone wall.",
    },
    {
      name: "Fernlight Bridge",
      short: "FERNLIGHT",
      color: "#8ce0ca",
      icon: "⌁",
      friend: "Juniper the Frog",
      place: "Across the soft stream",
      line: "If we listen together, the water remembers the road home.",
      plants: ["moss", "dew"],
      scene: "A little bridge where the soft stream keeps the time.",
    },
    {
      name: "Cloud Orchard",
      short: "CLOUD ORCHARD",
      color: "#d5a9ff",
      icon: "☁",
      friend: "Noon the Cloud",
      place: "A garden above the clouds",
      line: "There is room up here for every odd, bright thing that grows.",
      plants: ["bloom", "moon"],
      scene: "A drifting orchard, with stars caught in the leaves like fruit.",
    },
    {
      name: "The Far Lantern",
      short: "FAR LANTERN",
      color: "#ffe49b",
      icon: "✦",
      friend: "The Old Moon",
      place: "Home, seen from here",
      line: "Look how far your gentle little garden light has travelled.",
      plants: ["amber", "moss", "bloom"],
      scene:
        "The last light at the edge of the garden, still warm enough to share.",
    },
  ];
  const levelTitles = [
    "A Soft Beginning",
    "The First Dew",
    "Three Little Lights",
    "A Root Unknotted",
    "Moss Finds a Window",
    "A Moon for Later",
    "Wren's Warm Stone",
    "Bluebells at Rest",
    "A Path of Petals",
    "The Patch Takes Root",
  ];
  const decorItems = [
    {
      id: "lantern",
      name: "Pocket lantern",
      icon: "🏮",
      cost: 10,
      copy: "A soft amber dot when the sky grows quiet.",
    },
    {
      id: "stone",
      name: "Wishing stone",
      icon: "◌",
      cost: 14,
      copy: "A smooth place to sit between little plans.",
    },
    {
      id: "mushroom",
      name: "Moon mushroom",
      icon: "🍄",
      cost: 16,
      copy: "A tiny roof for a tiny visitor.",
    },
    {
      id: "birdbath",
      name: "Dew bowl",
      icon: "◉",
      cost: 18,
      copy: "A shallow pool that remembers the stars.",
    },
    {
      id: "windchime",
      name: "Fern chime",
      icon: "⌁",
      cost: 22,
      copy: "A little song made of patient air.",
    },
    {
      id: "arch",
      name: "Willow arch",
      icon: "⌒",
      cost: 26,
      copy: "A doorway for whoever needs a way through.",
    },
  ];
  const plantItems = [
    {
      type: "moon",
      name: "Moon flower",
      icon: "✧",
      color: "#b7c7ff",
      caption: "A pale, patient flower.",
    },
    {
      type: "moss",
      name: "Pocket moss",
      icon: "❋",
      color: "#a2e0a5",
      caption: "A soft place for small feet.",
    },
    {
      type: "amber",
      name: "Amber seed",
      icon: "✿",
      color: "#f1c67b",
      caption: "Keeps a little warmth inside.",
    },
    {
      type: "bloom",
      name: "Night bloom",
      icon: "❀",
      color: "#ff9bca",
      caption: "Opens only when you slow down.",
    },
    {
      type: "dew",
      name: "Dew sprig",
      icon: "◇",
      color: "#82ded8",
      caption: "Holds the morning in one leaf.",
    },
  ];
  const storyLines = [
    "We thought the path was gone. Turns out it was only waiting for a kinder step.",
    "I found a blue petal near the old gate. It looked like a very small map.",
    "The roots are not stuck, exactly. They just like to know where they're going.",
    "I heard the lanterns humming. I think they remember the first time you came.",
    "Everything looks brighter from a place you've taken time to care for.",
    "The little stream doesn't mind if we stay here for another minute.",
    "I left a seed beneath the warm stone. It said it would think about growing.",
    "A moth came by and asked if the light was always this soft. It is now.",
    "The garden is not finished. That's the nice part.",
    "When the moon comes back around, it will know where to find us.",
  ];
  const dailyTasks = [
    {
      title: "The Dew at Dusk",
      copy: "Complete today's unique board for 12 dewdrops and a trowel.",
    },
    {
      title: "Little Cascade",
      copy: "Complete today's unique board for 12 dewdrops and a trowel.",
    },
    {
      title: "Root and Bloom",
      copy: "Complete today's unique board for 12 dewdrops and a trowel.",
    },
    {
      title: "The Soft Touch",
      copy: "Complete today's unique board for 12 dewdrops and a trowel.",
    },
    {
      title: "A Bright Cluster",
      copy: "Complete today's unique board for 12 dewdrops and a trowel.",
    },
    {
      title: "Moon Flower Morning",
      copy: "Complete today's unique board for 12 dewdrops and a trowel.",
    },
    {
      title: "Moss at the Gate",
      copy: "Complete today's unique board for 12 dewdrops and a trowel.",
    },
  ];
  const freshSave = () => ({
    version: 1,
    level: 1,
    highestCleared: 0,
    dew: 18,
    plantsWoken: 0,
    bestCombo: 0,
    gardenGlow: 0,
    levels: {},
    seeds: { moon: 2, moss: 2, amber: 1, bloom: 1, dew: 1 },
    planted: [],
    decorations: [],
    selectedDecor: "",
    boosters: { trowel: 2, dew: 1, lantern: 1 },
    streak: { day: "", count: 0, last: "" },
    daily: { date: "", done: false, ritual: 0 },
    currentBoard: null,
    achievements: [],
    sound: true,
    movesUsed: 0,
    totalMatches: 0,
  });
  const game = {
    save: loadSave(),
    screen: "home",
    state: "idle",
    level: 1,
    dailyMode: false,
    board: [],
    goals: null,
    moves: 0,
    score: 0,
    selected: null,
    busy: false,
    usePower: "",
    powerType: "",
    combo: 0,
    bestCascade: 0,
    matchesThisMove: 0,
    movesSinceSave: 0,
    last: 0,
    animClock: 0,
    pointerStart: null,
    keyboardCell: { r: 0, c: 0 },
    dailySeed: 0,
    audio: null,
    chapterIndex: 0,
    lastSave: 0,
    currentLevelData: null,
    effects: [],
    boardRows: [],
    resultStars: 0,
    resultRewards: 0,
    visitCount: 0,
  };

  function loadSave() {
    try {
      const data = JSON.parse(localStorage.getItem(SAVE_KEY) || "null");
      if (!data || data.version !== 1) return freshSave();
      const base = freshSave();
      return {
        ...base,
        ...data,
        levels: data.levels || {},
        seeds: { ...base.seeds, ...(data.seeds || {}) },
        boosters: { ...base.boosters, ...(data.boosters || {}) },
        planted: Array.isArray(data.planted) ? data.planted : [],
        decorations: Array.isArray(data.decorations) ? data.decorations : [],
        achievements: Array.isArray(data.achievements) ? data.achievements : [],
        streak: { ...base.streak, ...(data.streak || {}) },
        daily: { ...base.daily, ...(data.daily || {}) },
      };
    } catch (error) {
      console.info("A fresh little garden is ready.", error);
      return freshSave();
    }
  }

  function save(force = false) {
    if (!force && performance.now() - game.lastSave < 450) return;
    game.lastSave = performance.now();
    if (game.state === "playing" && !game.dailyMode) {
      game.save.currentBoard = {
        level: game.level,
        board: game.board,
        moves: game.moves,
        score: game.score,
        goals: game.goals,
        combo: game.combo,
      };
    }
    try {
      localStorage.setItem(SAVE_KEY, JSON.stringify(game.save));
      id("save-label").textContent = "GARDEN AUTOSAVED";
      setTimeout(() => {
        if (id("save-label")) id("save-label").textContent = "GARDEN AUTOSAVED";
      }, 900);
    } catch (_) {
      id("save-label").textContent = "SESSION ONLY";
    }
  }

  function safe(value) {
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
  function dayStamp(date = new Date()) {
    return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, "0")}-${String(date.getDate()).padStart(2, "0")}`;
  }
  function randomType() {
    return TYPES[Math.floor(Math.random() * TYPES.length)];
  }
  function makeCell(type = randomType()) {
    return {
      type,
      special: "",
      root: 0,
      selected: false,
      match: false,
      key: `${Math.random().toString(36).slice(2)}-${Date.now()}`,
    };
  }

  function levelData(level, daily = false) {
    const n = daily
      ? (Number(String(dayStamp()).replace(/-/g, "")) % 60) + 1
      : clamp(level, 1, 60);
    const chapterIndex = Math.floor((n - 1) / 10);
    const local = (n - 1) % 10;
    const chapter = gardens[chapterIndex];
    const goalType =
      chapter.plants[(n + local) % chapter.plants.length] || "moon";
    const goalCount = daily
      ? 12
      : 9 + Math.floor(local * 1.25) + chapterIndex * 2;
    const rootCount = daily
      ? 5
      : local >= 2
        ? Math.min(14, 3 + Math.floor(local * 0.8) + chapterIndex)
        : 0;
    const moves = daily
      ? 16
      : Math.max(13, 20 - Math.floor(local / 3) - Math.floor(chapterIndex / 2));
    const title =
      local < levelTitles.length
        ? levelTitles[local]
        : `${["A Small Clearing", "The Patient Path", "Petals at Moonrise", "Warmth in the Roots", "Somewhere to Rest"][local % 5]} ${chapterIndex + 1}`;
    return {
      level: n,
      chapterIndex,
      local,
      chapter,
      goalType,
      goalCount,
      rootCount,
      moves,
      title,
      daily,
      seed: daily
        ? Number(String(dayStamp()).replace(/-/g, ""))
        : n * 331 + chapterIndex * 91,
      targetScore: goalCount * 120 + rootCount * 90,
      story: storyLines[(n + chapterIndex * 2) % storyLines.length],
    };
  }

  function setScreen(name) {
    game.screen = name;
    for (const [key, view] of Object.entries({
      home: id("home-view"),
      puzzle: id("puzzle-view"),
      trail: id("trail-view"),
      patch: id("patch-view"),
      journal: id("journal-view"),
    }))
      view.classList.toggle("hidden", name !== key);
    if (name === "home") renderHome();
    if (name === "trail") renderTrail();
    if (name === "patch") renderPatch();
    if (name === "journal") renderJournal();
  }

  function renderHome() {
    id("dew-count").textContent = game.save.dew;
    id("trail-dew").textContent = game.save.dew;
    id("patch-dew").textContent = game.save.dew;
    id("garden-level").textContent = String(
      Math.max(1, game.save.level),
    ).padStart(2, "0");
    id("plants-count").textContent = String(game.save.plantsWoken).padStart(
      2,
      "0",
    );
    id("best-combo").textContent = `×${game.save.bestCombo}`;
    const current = levelData(game.save.level);
    id("chapter-name").textContent = current.chapter.short;
    id("chapter-caption").textContent = current.chapter.scene;
    drawHomeGarden();
    updateDailyCard();
    id("play-button").textContent = game.save.currentBoard
      ? "RETURN TO YOUR BOARD ↗"
      : "CONTINUE THE GARDEN ↗";
  }

  function drawHomeGarden() {
    const bed = id("flower-bed");
    bed.replaceChildren();
    const planted = game.save.planted.slice(-9);
    const defaults = planted.length
      ? planted
      : ["moon", "moss", "amber", "bloom", "dew"];
    defaults.forEach((type, index) => {
      const flower = document.createElement("span");
      flower.className = `home-flower home-flower-${index % 5}`;
      flower.textContent = SYMBOL[type] || "✿";
      flower.style.color = COLORS[type] || COLORS.moss;
      flower.style.animationDelay = `${index * 0.24}s`;
      bed.append(flower);
    });
  }

  function updateDailyCard() {
    const today = dayStamp();
    const dateNum = Number(today.replace(/-/g, ""));
    const ritual = dateNum % dailyTasks.length;
    game.save.daily.ritual = ritual;
    const task = dailyTasks[ritual];
    id("daily-title").textContent = task.title.toUpperCase();
    id("daily-copy").textContent = task.copy;
    const completed = game.save.daily.date === today && game.save.daily.done;
    id("daily-progress").textContent = completed ? "TENDED ✓" : "READY";
    id("daily-button").textContent = completed
      ? "VISIT THE PATCH →"
      : "TRY TODAY'S BOARD →";
  }

  function startLevel(level = game.save.level, options = {}) {
    game.level = clamp(level, 1, 60);
    game.dailyMode = Boolean(options.daily);
    game.currentLevelData = levelData(game.level, game.dailyMode);
    game.state = "playing";
    game.busy = false;
    game.selected = null;
    game.usePower = "";
    game.powerType = "";
    game.combo = 0;
    game.bestCascade = 0;
    game.score = 0;
    game.matchesThisMove = 0;
    game.effects = [];
    const data = game.currentLevelData;
    if (!game.dailyMode && game.save.currentBoard?.level === game.level) {
      game.board = cloneBoard(game.save.currentBoard.board);
      game.moves = game.save.currentBoard.moves;
      game.score = game.save.currentBoard.score || 0;
      game.goals = {
        ...data,
        ...(game.save.currentBoard.goals || {}),
        collected: game.save.currentBoard.goals?.collected || 0,
        rootsCleared: game.save.currentBoard.goals?.rootsCleared || 0,
      };
    } else {
      game.moves = data.moves;
      game.goals = { ...data, collected: 0, rootsCleared: 0 };
      game.board = createBoard(data);
    }
    game.chapterIndex = data.chapterIndex;
    updateLevelHeader();
    renderBoard();
    updatePuzzleHud();
    id("board-status").textContent = game.dailyMode
      ? "DAILY RITUAL · THE PIECES WILL WAIT"
      : "MATCH THREE OR MORE · EVERY MOVE COUNTS";
    id("booster-hint").textContent = "Pick a piece to tend the garden.";
    setScreen("puzzle");
    save(true);
  }

  function cloneBoard(board) {
    if (!Array.isArray(board) || board.length !== SIZE)
      return createBoard(levelData(game.level));
    return board.map((row) =>
      row.map((cell) =>
        cell
          ? { ...cell, key: `${cell.key || "save"}-${Math.random()}` }
          : makeCell(),
      ),
    );
  }

  function createBoard(data) {
    let board = Array.from({ length: SIZE }, () => Array(SIZE).fill(null));
    for (let row = 0; row < SIZE; row++)
      for (let col = 0; col < SIZE; col++) {
        let type;
        let attempts = 0;
        do {
          type = randomType();
          attempts++;
        } while (attempts < 30 && wouldMatch(board, row, col, type));
        board[row][col] = makeCell(type);
      }
    let roots = data.rootCount;
    while (roots > 0) {
      const row = 1 + Math.floor(Math.random() * (SIZE - 2));
      const col = Math.floor(Math.random() * SIZE);
      const cell = board[row][col];
      if (!cell.root) {
        cell.root = 1;
        roots--;
      }
    }
    return board;
  }

  function wouldMatch(board, row, col, type) {
    if (
      col >= 2 &&
      board[row][col - 1]?.type === type &&
      board[row][col - 2]?.type === type
    )
      return true;
    if (
      row >= 2 &&
      board[row - 1][col]?.type === type &&
      board[row - 2][col]?.type === type
    )
      return true;
    return false;
  }

  function updateLevelHeader() {
    const data = game.currentLevelData;
    id("level-kicker").textContent =
      `${data.daily ? "DAILY RITUAL" : `PATCH ${String(data.chapterIndex + 1).padStart(2, "0")}`} · ${data.chapter.short}`;
    id("level-name").textContent = data.daily
      ? "A BOARD FOR TODAY"
      : data.title.toUpperCase();
    id("level-count").textContent = data.daily
      ? "DAILY · NO RUSH"
      : `LEVEL ${String(data.level).padStart(2, "0")} / 60`;
    id("story-icon").textContent = data.chapter.icon;
    id("story-speaker").textContent = data.chapter.friend.toUpperCase();
    id("story-title").textContent = data.chapter.place + ".";
    id("story-copy").textContent = `“${data.story}”`;
    id("story-goal-text").textContent =
      `${data.goalCount} ${NAMES[data.goalType]}${data.rootCount ? ` · ${data.rootCount} roots` : ""}`;
    id("streak-text").textContent =
      `${game.save.streak.count} ${game.save.streak.count === 1 ? "DAY" : "DAYS"}`;
    id("trowel-count").textContent = game.save.boosters.trowel;
    id("dew-booster-count").textContent = game.save.boosters.dew;
    id("lantern-count").textContent = game.save.boosters.lantern;
    const goals = id("goal-items");
    goals.replaceChildren();
    const flowerGoal = document.createElement("span");
    flowerGoal.className = "goal-chip";
    flowerGoal.innerHTML = `<i style="color:${COLORS[data.goalType]}">${SYMBOL[data.goalType]}</i><b id="goal-flower-count">0/${data.goalCount}</b>`;
    goals.append(flowerGoal);
    if (data.rootCount > 0) {
      const root = document.createElement("span");
      root.className = "goal-chip";
      root.innerHTML = `<i class="root-icon">⌁</i><b id="goal-root-count">0/${data.rootCount}</b>`;
      goals.append(root);
    }
  }

  function renderBoard() {
    const board = id("board");
    board.replaceChildren();
    board.setAttribute("aria-rowcount", SIZE);
    board.setAttribute("aria-colcount", SIZE);
    for (let row = 0; row < SIZE; row++) {
      for (let col = 0; col < SIZE; col++) {
        const cell = game.board[row][col];
        const button = document.createElement("button");
        button.type = "button";
        button.className =
          `tile tile-${cell.type}` +
          (cell.root ? " has-root" : "") +
          (cell.special ? ` special-${cell.special}` : "") +
          (game.selected?.row === row && game.selected?.col === col
            ? " selected"
            : "");
        button.dataset.row = row;
        button.dataset.col = col;
        button.setAttribute("role", "gridcell");
        button.setAttribute(
          "aria-label",
          `${NAMES[cell.type]}, row ${row + 1}, column ${col + 1}${cell.root ? ", tangled root" : ""}${cell.special ? `, ${cell.special} special` : ""}`,
        );
        button.innerHTML = `<span class="tile-root">${cell.root ? "⌁" : ""}</span><span class="tile-mark">${cell.special === "wild" ? SYMBOL.wild : SYMBOL[cell.type]}</span><span class="tile-glint"></span>`;
        button.addEventListener("click", () => chooseCell(row, col));
        button.addEventListener("pointerdown", (event) => {
          game.pointerStart = { x: event.clientX, y: event.clientY, row, col };
        });
        button.addEventListener("pointerup", (event) =>
          handleSwipe(event, row, col),
        );
        button.addEventListener("keydown", (event) =>
          handleBoardKey(event, row, col),
        );
        board.append(button);
      }
    }
  }

  function handleSwipe(event, row, col) {
    if (!game.pointerStart || game.busy) return;
    const dx = event.clientX - game.pointerStart.x;
    const dy = event.clientY - game.pointerStart.y;
    if (Math.abs(dx) + Math.abs(dy) > 16) {
      const targetRow = row + (Math.abs(dy) > Math.abs(dx) ? Math.sign(dy) : 0);
      const targetCol =
        col + (Math.abs(dx) >= Math.abs(dy) ? Math.sign(dx) : 0);
      if (validPosition(targetRow, targetCol))
        swapTiles(row, col, targetRow, targetCol);
    }
    game.pointerStart = null;
  }

  function handleBoardKey(event, row, col) {
    const directions = {
      ArrowUp: [-1, 0],
      ArrowDown: [1, 0],
      ArrowLeft: [0, -1],
      ArrowRight: [0, 1],
      w: [-1, 0],
      s: [1, 0],
      a: [0, -1],
      d: [0, 1],
    };
    const delta = directions[event.key] || directions[event.key.toLowerCase()];
    if (delta) {
      event.preventDefault();
      const nr = clamp(row + delta[0], 0, SIZE - 1),
        nc = clamp(col + delta[1], 0, SIZE - 1);
      game.keyboardCell = { r: nr, c: nc };
      id("board")
        .querySelector(`[data-row="${nr}"][data-col="${nc}"]`)
        ?.focus();
    } else if (event.key === "Enter" || event.key === " ") {
      event.preventDefault();
      chooseCell(row, col);
    }
  }

  function validPosition(row, col) {
    return row >= 0 && row < SIZE && col >= 0 && col < SIZE;
  }

  function chooseCell(row, col) {
    if (game.busy || game.state !== "playing") return;
    if (game.usePower === "trowel") {
      useTrowel(row, col);
      return;
    }
    if (game.usePower === "lantern") {
      useLantern(game.board[row][col].type);
      return;
    }
    if (!game.selected) {
      game.selected = { row, col };
      renderBoard();
      id("board")
        .querySelector(`[data-row="${row}"][data-col="${col}"]`)
        ?.focus();
      return;
    }
    const first = game.selected;
    if (first.row === row && first.col === col) {
      game.selected = null;
      renderBoard();
      return;
    }
    if (Math.abs(first.row - row) + Math.abs(first.col - col) === 1)
      swapTiles(first.row, first.col, row, col);
    else {
      game.selected = { row, col };
      renderBoard();
    }
  }

  function swapBoardCells(a, b) {
    const temporary = game.board[a.row][a.col];
    game.board[a.row][a.col] = game.board[b.row][b.col];
    game.board[b.row][b.col] = temporary;
  }

  async function swapTiles(rowA, colA, rowB, colB) {
    if (game.busy || game.moves <= 0 || !validPosition(rowB, colB)) return;
    game.busy = true;
    game.selected = null;
    const a = { row: rowA, col: colA },
      b = { row: rowB, col: colB };
    swapBoardCells(a, b);
    renderBoard();
    await wait(105);
    const specialA = game.board[rowA][colA]?.special;
    const specialB = game.board[rowB][colB]?.special;
    let matches = findMatches();
    const specialMatch = specialA || specialB;
    if (!matches.length && !specialMatch) {
      swapBoardCells(a, b);
      game.busy = false;
      renderBoard();
      id("board-status").textContent =
        "THAT SWAP DIDN'T BLOOM · TRY ANOTHER WAY";
      tone(180, 0.08, "sine", 0.016);
      return;
    }
    game.moves -= 1;
    game.save.movesUsed += 1;
    game.matchesThisMove = 0;
    game.combo = 0;
    if (specialMatch) {
      const trigger = specialA ? a : b;
      await triggerSpecial(trigger.row, trigger.col, specialA || specialB);
      matches = findMatches();
    }
    await resolveMatches(matches);
    game.busy = false;
    game.save.totalMatches += game.matchesThisMove;
    updatePuzzleHud();
    save(true);
    if (checkWin()) {
      winLevel();
      return;
    }
    if (game.moves <= 0) {
      loseLevel();
      return;
    }
    if (!hasPossibleMove()) {
      shuffleBoard();
    }
    id("board-status").textContent =
      game.combo >= 3
        ? `A CASCADE OF ${game.combo} · LOVELY`
        : game.dailyMode
          ? "TODAY'S LITTLE RITUAL · STILL GROWING"
          : "MATCH THREE OR MORE · EVERY MOVE COUNTS";
  }

  function findMatches() {
    const cells = new Map();
    const addRun = (run, direction) => {
      if (run.length < 3) return;
      for (const point of run) {
        const key = `${point.row}:${point.col}`;
        const existing = cells.get(key) || { ...point, directions: new Set() };
        existing.directions.add(direction);
        cells.set(key, existing);
      }
    };
    for (let row = 0; row < SIZE; row++) {
      let run = [];
      for (let col = 0; col <= SIZE; col++) {
        const cell = col < SIZE ? game.board[row][col] : null;
        const previous = run.length
          ? game.board[row][run[run.length - 1].col]
          : null;
        if (
          cell &&
          !cell.special?.startsWith("locked") &&
          (!run.length ||
            cell.type === previous.type ||
            cell.type === "wild" ||
            previous.type === "wild")
        )
          run.push({ row, col });
        else {
          addRun(run, "row");
          run = cell ? [{ row, col }] : [];
        }
      }
    }
    for (let col = 0; col < SIZE; col++) {
      let run = [];
      for (let row = 0; row <= SIZE; row++) {
        const cell = row < SIZE ? game.board[row][col] : null;
        const previous = run.length
          ? game.board[run[run.length - 1].row][col]
          : null;
        if (
          cell &&
          (!run.length ||
            cell.type === previous.type ||
            cell.type === "wild" ||
            previous.type === "wild")
        )
          run.push({ row, col });
        else {
          addRun(run, "col");
          run = cell ? [{ row, col }] : [];
        }
      }
    }
    return Array.from(cells.values());
  }

  async function resolveMatches(matches) {
    let cascade = 0;
    while (matches.length && cascade < 14) {
      cascade += 1;
      game.combo += 1;
      game.bestCascade = Math.max(game.bestCascade, game.combo);
      game.save.bestCombo = Math.max(game.save.bestCombo, game.combo);
      const specialPlan = planSpecials(matches);
      const clearSet = new Set(
        matches.map((cell) => `${cell.row}:${cell.col}`),
      );
      const specialKeep = new Map();
      for (const special of specialPlan) {
        clearSet.delete(`${special.row}:${special.col}`);
        specialKeep.set(`${special.row}:${special.col}`, special.kind);
      }
      const cells = Array.from(clearSet).map((key) =>
        key.split(":").map(Number),
      );
      game.matchesThisMove += cells.length;
      game.score += cells.length * 70 * Math.min(6, game.combo);
      for (const [row, col] of cells) {
        const cell = game.board[row][col];
        if (!cell) continue;
        if (cell.type === game.goals.goalType || cell.type === "wild")
          game.goals.collected += 1;
        if (cell.root) {
          game.goals.rootsCleared += 1;
          cell.root = 0;
        }
        for (const [dr, dc] of [
          [-1, 0],
          [1, 0],
          [0, -1],
          [0, 1],
        ]) {
          const nr = row + dr,
            nc = col + dc;
          if (validPosition(nr, nc) && game.board[nr][nc]?.root) {
            game.board[nr][nc].root -= 1;
            game.goals.rootsCleared += 1;
          }
        }
        addEffect(row, col, cell.type);
        game.board[row][col] = null;
      }
      for (const [key, kind] of specialKeep) {
        const [row, col] = key.split(":").map(Number);
        if (game.board[row][col]) game.board[row][col].special = kind;
      }
      updatePuzzleHud();
      renderBoard();
      tone(
        290 + Math.min(6, game.combo) * 82,
        0.1,
        "sine",
        0.024,
        760 + game.combo * 55,
      );
      await wait(Math.max(90, 190 - game.combo * 12));
      collapseColumns();
      renderBoard();
      await wait(145);
      matches = findMatches();
      if (specialPlan.length) {
        for (const special of specialPlan)
          if (game.board[special.row][special.col]?.special === "line")
            game.board[special.row][special.col].special = "";
      }
    }
    if (game.combo > 1) {
      const bonus = game.combo * 55 + Math.max(0, game.combo - 3) * 90;
      game.score += bonus;
      const label = [
        "A soft ripple",
        "A lovely cascade",
        "The garden is glowing",
        "Oh, what a bloom",
        "The moon saw that",
      ][Math.min(game.combo - 1, 4)];
      id("combo-label").textContent = `${label.toUpperCase()} · +${bonus}`;
      id("booster-hint").textContent =
        `Cascade ×${game.combo} · ${bonus} extra garden glow`;
    } else id("combo-label").textContent = "A QUIET START";
    game.save.gardenGlow += game.score;
    updatePuzzleHud();
  }

  function planSpecials(matches) {
    const groups = matches;
    if (groups.length < 4) return [];
    const rowRuns = new Map(),
      colRuns = new Map();
    for (const cell of groups) {
      if (cell.directions.has("row"))
        rowRuns.set(cell.row, (rowRuns.get(cell.row) || 0) + 1);
      if (cell.directions.has("col"))
        colRuns.set(cell.col, (colRuns.get(cell.col) || 0) + 1);
    }
    const intersection = groups.find((cell) => cell.directions.size > 1);
    const candidate = intersection || groups[Math.floor(groups.length / 2)];
    if (groups.length >= 5)
      return [{ row: candidate.row, col: candidate.col, kind: "wild" }];
    return [{ row: candidate.row, col: candidate.col, kind: "line" }];
  }

  function collapseColumns() {
    for (let col = 0; col < SIZE; col++) {
      const remaining = [];
      for (let row = SIZE - 1; row >= 0; row--)
        if (game.board[row][col]) remaining.push(game.board[row][col]);
      let index = 0;
      for (let row = SIZE - 1; row >= 0; row--)
        game.board[row][col] =
          index < remaining.length
            ? remaining[index++]
            : makeCell(randomType());
    }
  }

  async function triggerSpecial(row, col, kind) {
    const cell = game.board[row][col];
    if (!cell) return;
    const affected = [];
    if (kind === "wild") {
      const targetType = game.board[row][col].type;
      for (let r = 0; r < SIZE; r++)
        for (let c = 0; c < SIZE; c++)
          if (game.board[r][c]?.type === targetType) affected.push([r, c]);
      cell.type = "wild";
    } else if (kind === "line") {
      for (let c = 0; c < SIZE; c++) affected.push([row, c]);
      for (let r = 0; r < SIZE; r++) affected.push([r, col]);
    } else if (kind === "burst") {
      for (let r = Math.max(0, row - 1); r <= Math.min(SIZE - 1, row + 1); r++)
        for (
          let c = Math.max(0, col - 1);
          c <= Math.min(SIZE - 1, col + 1);
          c++
        )
          affected.push([r, c]);
    }
    for (const [r, c] of affected)
      if (game.board[r][c]) {
        const tile = game.board[r][c];
        if (tile.type === game.goals.goalType || tile.type === "wild")
          game.goals.collected += 1;
        if (tile.root) {
          game.goals.rootsCleared += tile.root;
          tile.root = 0;
        }
        game.board[r][c] = null;
        addEffect(r, c, tile.type);
      }
    game.score += affected.length * 45;
    game.matchesThisMove += affected.length;
    await wait(130);
    collapseColumns();
    renderBoard();
  }

  function useTrowel(row, col) {
    if (game.busy || game.save.boosters.trowel <= 0 || game.moves <= 0) {
      game.usePower = "";
      return;
    }
    game.busy = true;
    game.save.boosters.trowel -= 1;
    game.usePower = "";
    const cell = game.board[row][col];
    if (cell.type === game.goals.goalType || cell.type === "wild")
      game.goals.collected += 1;
    if (cell.root) {
      game.goals.rootsCleared += cell.root;
      cell.root = 0;
    }
    game.board[row][col] = null;
    game.moves -= 1;
    game.score += 60;
    collapseColumns();
    renderBoard();
    updatePuzzleHud();
    save(true);
    window.setTimeout(async () => {
      const matches = findMatches();
      if (matches.length) await resolveMatches(matches);
      game.busy = false;
      updatePuzzleHud();
      if (checkWin()) winLevel();
      else if (game.moves <= 0) loseLevel();
    }, 180);
  }

  async function useLantern(type) {
    if (game.busy || game.save.boosters.lantern <= 0 || game.moves <= 0) {
      game.usePower = "";
      return;
    }
    game.busy = true;
    game.save.boosters.lantern -= 1;
    game.usePower = "";
    let count = 0;
    for (let row = 0; row < SIZE; row++)
      for (let col = 0; col < SIZE; col++) {
        const cell = game.board[row][col];
        if (cell?.type !== type) continue;
        count += 1;
        if (cell.type === game.goals.goalType) game.goals.collected += 1;
        if (cell.root) {
          game.goals.rootsCleared += cell.root;
          cell.root = 0;
        }
        game.board[row][col] = null;
        addEffect(row, col, type);
      }
    game.moves -= 1;
    game.score += count * 45;
    game.matchesThisMove = count;
    await wait(180);
    collapseColumns();
    renderBoard();
    updatePuzzleHud();
    save(true);
    const matches = findMatches();
    if (matches.length) await resolveMatches(matches);
    game.busy = false;
    updatePuzzleHud();
    if (checkWin()) winLevel();
    else if (game.moves <= 0) loseLevel();
  }

  function useExtraMove() {
    if (game.busy || game.save.boosters.dew <= 0 || game.state !== "playing")
      return;
    game.save.boosters.dew -= 1;
    game.moves += 3;
    game.usePower = "";
    id("booster-hint").textContent =
      "Three extra moves. The garden says thank you.";
    id("board-status").textContent = "DEW IS ON YOUR SIDE · THREE MOVES ADDED";
    tone(590, 0.2, "sine", 0.035, 990);
    updatePuzzleHud();
    save(true);
  }

  function checkWin() {
    return (
      game.goals.collected >= game.goals.goalCount &&
      game.goals.rootsCleared >= game.goals.rootCount
    );
  }

  function winLevel() {
    if (game.state !== "playing") return;
    game.state = "result";
    game.busy = true;
    const stars = game.moves >= 6 ? 3 : game.moves >= 3 ? 2 : 1;
    const oldStars = game.save.levels[game.level]?.stars || 0;
    const rewards =
      7 +
      stars * 3 +
      Math.max(0, game.moves) +
      game.currentLevelData.chapterIndex * 2;
    game.save.dew += rewards;
    game.save.levels[game.level] = {
      stars: Math.max(oldStars, stars),
      score: Math.max(game.score, game.save.levels[game.level]?.score || 0),
      collected: game.goals.collected,
      roots: game.goals.rootsCleared,
    };
    game.save.highestCleared = Math.max(game.save.highestCleared, game.level);
    game.save.level = Math.min(60, Math.max(game.save.level, game.level + 1));
    game.save.plantsWoken += 1 + (stars === 3 ? 1 : 0);
    const seedType = game.currentLevelData.goalType;
    game.save.seeds[seedType] =
      (game.save.seeds[seedType] || 0) + 1 + Math.floor(stars / 2);
    game.save.currentBoard = null;
    updateStreak();
    updateDailyOnWin();
    awardAchievements(stars);
    save(true);
    showResult(true, stars, rewards);
  }

  function loseLevel() {
    if (game.state !== "playing") return;
    game.state = "result";
    game.busy = true;
    const consolation = Math.max(1, Math.floor(game.goals.collected / 8));
    game.save.dew += consolation;
    game.save.currentBoard = null;
    save(true);
    showResult(false, 0, consolation);
  }

  function updateStreak() {
    const today = dayStamp();
    const last = game.save.streak.last;
    if (last === today) return;
    const yesterday = dayStamp(new Date(Date.now() - 86400000));
    game.save.streak.count =
      last === yesterday ? game.save.streak.count + 1 : 1;
    game.save.streak.last = today;
    game.save.streak.day = today;
  }

  function updateDailyOnWin() {
    if (!game.dailyMode) return;
    const today = dayStamp();
    if (game.save.daily.date !== today || !game.save.daily.done) {
      game.save.daily.date = today;
      game.save.daily.done = true;
      game.save.dew += 12;
      game.save.boosters.trowel += 1;
    }
  }

  function awardAchievements(stars) {
    const checks = [
      ["first-light", game.save.highestCleared >= 1],
      ["little-streak", game.save.streak.count >= 3],
      ["roots-and-wings", game.goals.rootsCleared >= 6],
      ["three-suns", stars >= 3],
      ["halfway-patch", game.save.highestCleared >= 30],
      ["moon-gardener", game.save.highestCleared >= 60],
      ["friend-of-moss", game.save.plantsWoken >= 25],
    ];
    for (const [key, ok] of checks)
      if (ok && !game.save.achievements.includes(key))
        game.save.achievements.push(key);
  }

  function showResult(won, stars, rewards) {
    id("result-modal").classList.remove("hidden");
    id("result-kicker").textContent = won
      ? `${game.currentLevelData.chapter.name.toUpperCase()} · PATCH SETTLED`
      : "THE BOARD CAN WAIT";
    id("result-flower").textContent = won ? "✿" : "☾";
    id("result-title").textContent = won
      ? [
          "THE GARDEN WOKE UP.",
          "A LITTLE MORE LIGHT.",
          "EVERY ROOT FOUND HOME.",
        ][game.level % 3]
      : "THAT WAS A GOOD TRY.";
    id("result-copy").textContent = won
      ? `“${game.currentLevelData.story}”`
      : "Nothing here is lost. Take a breath, change one thing, and try again when you like.";
    id("result-rewards").innerHTML =
      `<span>✧ ${rewards} DEWDROPS</span><span>${game.goals.collected} / ${game.goals.goalCount} ${NAMES[game.goals.goalType].toUpperCase()}</span><span>${game.moves} MOVES LEFT</span>`;
    id("result-stars").innerHTML = [0, 1, 2]
      .map((i) => `<span class="${i < stars ? "earned" : ""}">★</span>`)
      .join("");
    id("next-level").textContent =
      won && game.level < 60
        ? "FOLLOW THE NEXT GLOW ↗"
        : won
          ? "THE TRAIL IS YOURS ✦"
          : "TRY THIS PATCH AGAIN ↗";
    id("next-level").onclick = () => {
      closeModal("result-modal");
      if (!won) startLevel(game.level);
      else if (game.dailyMode) setScreen("home");
      else if (game.level >= 60) setScreen("trail");
      else startLevel(game.level + 1);
    };
  }

  function updatePuzzleHud() {
    if (!game.goals) return;
    id("moves-left").textContent = game.moves;
    id("score-value").textContent = String(game.score).padStart(5, "0");
    id("goal-flower-count").textContent =
      `${Math.min(game.goals.collected, game.goals.goalCount)}/${game.goals.goalCount}`;
    const rootText = id("goal-root-count");
    if (rootText)
      rootText.textContent = `${Math.min(game.goals.rootsCleared, game.goals.rootCount)}/${game.goals.rootCount}`;
    id("trowel-count").textContent = game.save.boosters.trowel;
    id("dew-booster-count").textContent = game.save.boosters.dew;
    id("lantern-count").textContent = game.save.boosters.lantern;
    document.querySelectorAll(".booster").forEach((button) => {
      const type = button.dataset.booster;
      const remaining =
        type === "trowel"
          ? game.save.boosters.trowel
          : type === "dew"
            ? game.save.boosters.dew
            : game.save.boosters.lantern;
      button.classList.toggle("armed", game.usePower === type);
      button.disabled =
        game.busy ||
        remaining <= 0 ||
        game.moves <= 0 ||
        game.state !== "playing";
    });
    const completeFlower = game.goals.collected >= game.goals.goalCount;
    const completeRoots = game.goals.rootsCleared >= game.goals.rootCount;
    id("goal-flower-count").classList.toggle("complete", completeFlower);
    if (rootText) rootText.classList.toggle("complete", completeRoots);
  }

  function addEffect(row, col, type) {
    game.effects.push({
      row,
      col,
      type,
      life: 0.56,
      phase: Math.random() * Math.PI * 2,
    });
    if (game.effects.length > 80) game.effects.shift();
  }

  function updateEffects(dt) {
    for (const effect of game.effects) {
      effect.life -= dt;
      effect.phase += dt * 6;
    }
    game.effects = game.effects.filter((effect) => effect.life > 0);
  }

  function hasPossibleMove() {
    for (let row = 0; row < SIZE; row++)
      for (let col = 0; col < SIZE; col++) {
        for (const [dr, dc] of [
          [0, 1],
          [1, 0],
        ]) {
          const nr = row + dr,
            nc = col + dc;
          if (!validPosition(nr, nc)) continue;
          swapBoardCells({ row, col }, { row: nr, col: nc });
          const possible = findMatches().length > 0;
          swapBoardCells({ row, col }, { row: nr, col: nc });
          if (possible) return true;
        }
      }
    return false;
  }

  function shuffleBoard() {
    const pieces = game.board.flat().map((cell) => ({
      type: cell.type,
      root: cell.root,
      special: cell.special,
    }));
    let attempts = 0;
    do {
      for (let i = pieces.length - 1; i > 0; i--) {
        const j = Math.floor(Math.random() * (i + 1));
        [pieces[i], pieces[j]] = [pieces[j], pieces[i]];
      }
      game.board = Array.from({ length: SIZE }, (_, row) =>
        Array.from({ length: SIZE }, (_, col) => ({
          ...pieces[row * SIZE + col],
          key: `${Math.random()}`,
        })),
      );
      attempts++;
    } while ((findMatches().length || !hasPossibleMove()) && attempts < 80);
    game.busy = false;
    renderBoard();
    id("board-status").textContent =
      "THE PIECES TOOK A BREATH · NEW PATHS FOUND";
  }

  function wait(milliseconds) {
    return new Promise((resolve) => setTimeout(resolve, milliseconds));
  }

  function renderTrail() {
    id("trail-dew").textContent = game.save.dew;
    const unlockedChapter = Math.min(5, Math.floor((game.save.level - 1) / 10));
    const tabs = id("garden-tabs");
    tabs.replaceChildren();
    gardens.forEach((garden, index) => {
      const button = document.createElement("button");
      button.className =
        "garden-tab" +
        (game.chapterIndex === index ? " selected" : "") +
        (index > unlockedChapter ? " locked" : "");
      button.disabled = index > unlockedChapter;
      button.innerHTML = `<b>${String(index + 1).padStart(2, "0")} · ${safe(garden.short)}</b>${Math.min(10, Math.max(0, game.save.highestCleared - index * 10))}/10 PATCHES`;
      button.addEventListener("click", () => {
        game.chapterIndex = index;
        renderTrail();
      });
      tabs.append(button);
    });
    const grid = id("level-grid");
    grid.replaceChildren();
    for (
      let level = game.chapterIndex * 10 + 1;
      level <= game.chapterIndex * 10 + 10;
      level++
    ) {
      const stars = game.save.levels[level]?.stars || 0;
      const button = document.createElement("button");
      button.className =
        "level-button" +
        (level <= game.save.highestCleared ? " cleared" : "") +
        (level === game.save.level ? " current" : "");
      button.disabled = level > game.save.level;
      button.innerHTML = `${String(level).padStart(2, "0")}${stars ? `<small>${"★".repeat(stars)}</small>` : ""}`;
      button.title = levelData(level).title;
      button.addEventListener("click", () => startLevel(level));
      grid.append(button);
    }
  }

  function renderPatch() {
    id("patch-dew").textContent = game.save.dew;
    const chapter =
      gardens[Math.min(5, Math.floor((game.save.level - 1) / 10))];
    id("patch-title").textContent = `THE ${chapter.name.toUpperCase()}`;
    id("patch-caption").textContent = chapter.scene;
    const progress = Math.min(
      100,
      Math.round((game.save.plantsWoken / 40) * 100),
    );
    id("patch-progress-label").textContent =
      `${game.save.plantsWoken} PLANTS WOKEN`;
    id("patch-progress-fill").style.width = `${progress}%`;
    renderDecor();
    renderSeeds();
  }

  function renderDecor() {
    const layer = id("decor-layer");
    layer.replaceChildren();
    const placements = game.save.decorations;
    placements.forEach((item, index) => {
      const decor =
        decorItems.find((entry) => entry.id === item.id) || decorItems[0];
      const span = document.createElement("span");
      span.className = `placed-decor decor-${index % 6}`;
      span.textContent = decor.icon;
      span.title = decor.name;
      layer.append(span);
    });
    game.save.planted.slice(-12).forEach((type, index) => {
      const flower = document.createElement("span");
      flower.className = `patch-flower patch-flower-${index % 7}`;
      flower.textContent = SYMBOL[type];
      flower.style.color = COLORS[type];
      flower.title = NAMES[type];
      layer.append(flower);
    });
  }

  function renderSeeds() {
    const list = id("seed-list");
    list.replaceChildren();
    for (const plant of plantItems) {
      const count = game.save.seeds[plant.type] || 0;
      const card = document.createElement("button");
      card.className = "seed-card";
      card.disabled = count <= 0;
      card.innerHTML = `<i style="color:${plant.color}">${plant.icon}</i><b>${plant.name}</b><small>${plant.caption}</small><span>${count} IN POCKET</span>`;
      card.addEventListener("click", () => plantSeed(plant.type));
      list.append(card);
    }
    const decorList = id("decor-list");
    decorList.replaceChildren();
    for (const decor of decorItems) {
      const owned = game.save.decorations.some((item) => item.id === decor.id);
      const button = document.createElement("button");
      button.className = "decor-buy";
      button.disabled = owned || game.save.dew < decor.cost;
      button.innerHTML = `<i>${decor.icon}</i><span>${decor.name}</span><b>${owned ? "PLACED" : `✧ ${decor.cost}`}</b>`;
      button.title = decor.copy;
      button.addEventListener("click", () => buyDecor(decor));
      decorList.append(button);
    }
  }

  function plantSeed(type) {
    if ((game.save.seeds[type] || 0) <= 0) return;
    game.save.seeds[type] -= 1;
    game.save.planted.push(type);
    game.save.planted = game.save.planted.slice(-24);
    save(true);
    renderPatch();
    tone(700, 0.18, "sine", 0.03, 1100);
  }

  function buyDecor(decor) {
    if (
      game.save.dew < decor.cost ||
      game.save.decorations.some((item) => item.id === decor.id)
    )
      return;
    game.save.dew -= decor.cost;
    game.save.decorations.push({ id: decor.id, placedAt: Date.now() });
    save(true);
    renderPatch();
    tone(520, 0.2, "triangle", 0.035, 900);
  }

  function renderJournal() {
    const pages = id("journal-pages");
    pages.replaceChildren();
    const memories = [];
    for (let level = 1; level <= game.save.highestCleared; level++) {
      const data = levelData(level);
      memories.push({ data, result: game.save.levels[level] });
    }
    if (!memories.length) memories.push({ data: levelData(1), result: null });
    memories.reverse().forEach(({ data, result }) => {
      const article = document.createElement("article");
      article.className = "journal-entry";
      article.innerHTML = `<div class="journal-icon" style="color:${data.chapter.color}">${data.chapter.icon}</div><div><small>${data.chapter.short} · ${String(data.level).padStart(2, "0")}</small><h3>${safe(data.title)}</h3><p>“${safe(data.story)}”</p><span>${result ? `${"★".repeat(result.stars)}${"☆".repeat(3 - result.stars)} · ${result.score} garden glow` : "A story still waiting to be written."}</span></div>`;
      pages.append(article);
    });
  }

  function updateDaily() {
    updateDailyCard();
  }

  function drawGardenBackground() {
    const art = id("home-view");
    art.style.setProperty(
      "--garden-color",
      gardens[Math.min(5, Math.floor((game.save.level - 1) / 10))].color,
    );
  }

  function startDaily() {
    const today = dayStamp();
    if (game.save.daily.date === today && game.save.daily.done) {
      setScreen("patch");
      return;
    }
    id("daily-modal").classList.add("hidden");
    startLevel(game.save.level, { daily: true });
  }

  function leaveBoard() {
    save(true);
    closeModal("pause-modal");
    game.state = "idle";
    game.busy = false;
    setScreen("home");
  }

  function togglePause() {
    if (game.screen !== "puzzle" || game.state !== "playing") return;
    game.busy = true;
    save(true);
    id("pause-modal").classList.remove("hidden");
  }

  function resume() {
    id("pause-modal").classList.add("hidden");
    game.busy = false;
  }

  function bind() {
    id("play-button").addEventListener("click", () => {
      if (game.save.currentBoard) startLevel(game.save.currentBoard.level);
      else startLevel(game.save.level);
    });
    id("map-button").addEventListener("click", () => setScreen("trail"));
    id("garden-button").addEventListener("click", () => setScreen("patch"));
    id("daily-button").addEventListener("click", () => {
      if (game.save.daily.date === dayStamp() && game.save.daily.done)
        setScreen("patch");
      else id("daily-modal").classList.remove("hidden");
    });
    id("daily-start").addEventListener("click", startDaily);
    id("puzzle-home").addEventListener("click", () => {
      save(true);
      setScreen("home");
    });
    id("trail-home").addEventListener("click", () => setScreen("home"));
    id("patch-home").addEventListener("click", () => setScreen("home"));
    id("journal-back").addEventListener("click", () => setScreen("puzzle"));
    id("pause-button").addEventListener("click", togglePause);
    id("resume-button").addEventListener("click", resume);
    id("leave-board").addEventListener("click", leaveBoard);
    id("result-home").addEventListener("click", () => {
      closeModal("result-modal");
      setScreen("home");
    });
    id("journal-button").addEventListener("click", () => setScreen("journal"));
    id("sound-button").addEventListener("click", () => {
      game.save.sound = !game.save.sound;
      id("sound-button").textContent = game.save.sound ? "◖))" : "◖×";
      save(true);
      if (game.save.sound) tone(620, 0.12);
    });
    document
      .querySelectorAll("[data-booster]")
      .forEach((button) =>
        button.addEventListener("click", () =>
          armBooster(button.dataset.booster),
        ),
      );
    document
      .querySelectorAll("[data-close]")
      .forEach((button) =>
        button.addEventListener("click", () =>
          closeModal(button.dataset.close),
        ),
      );
    document.addEventListener("keydown", (event) => {
      if (event.key === "Escape") {
        if (!id("pause-modal").classList.contains("hidden")) resume();
        else if (game.screen === "puzzle") togglePause();
        else setScreen("home");
      }
    });
    window.addEventListener("beforeunload", () => save(true));
    document.addEventListener("visibilitychange", () => {
      if (
        document.hidden &&
        game.screen === "puzzle" &&
        game.state === "playing"
      )
        togglePause();
    });
    window.addEventListener("storage", (event) => {
      if (event.key === SAVE_KEY) game.save = loadSave();
    });
  }

  function armBooster(type) {
    if (game.busy || game.state !== "playing") return;
    if (type === "dew") {
      useExtraMove();
      return;
    }
    const amount = game.save.boosters[type] || 0;
    if (amount <= 0) return;
    game.usePower = game.usePower === type ? "" : type;
    id("booster-hint").textContent =
      game.usePower === "trowel"
        ? "Choose one tile to lift with the trowel."
        : game.usePower === "lantern"
          ? "Choose a tile color; the lantern will gather every matching piece."
          : "Pick a piece to tend the garden.";
    renderBoard();
    updatePuzzleHud();
  }

  function closeModal(name) {
    id(name).classList.add("hidden");
  }

  function tone(
    frequency,
    duration = 0.09,
    type = "sine",
    volume = 0.025,
    target = null,
  ) {
    if (!game.save.sound) return;
    if (!game.audio) {
      const Type = window.AudioContext || window.webkitAudioContext;
      if (Type) game.audio = new Type();
    }
    if (!game.audio) return;
    if (game.audio.state === "suspended") game.audio.resume();
    const oscillator = game.audio.createOscillator(),
      gain = game.audio.createGain();
    oscillator.type = type;
    oscillator.frequency.setValueAtTime(frequency, game.audio.currentTime);
    if (target)
      oscillator.frequency.exponentialRampToValueAtTime(
        target,
        game.audio.currentTime + duration,
      );
    gain.gain.setValueAtTime(volume, game.audio.currentTime);
    gain.gain.exponentialRampToValueAtTime(
      0.0001,
      game.audio.currentTime + duration,
    );
    oscillator.connect(gain);
    gain.connect(game.audio.destination);
    oscillator.start();
    oscillator.stop(game.audio.currentTime + duration);
  }

  function handlePowerSelection(row, col) {
    if (game.usePower === "trowel") useTrowel(row, col);
    else if (game.usePower === "lantern") useLantern(game.board[row][col].type);
  }

  function updateHomeVisuals() {
    renderHome();
    drawGardenBackground();
  }

  function boot() {
    bind();
    game.save.visitCount += 1;
    updateHomeVisuals();
    save(true);
  }

  boot();
})();
