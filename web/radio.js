(() => {
  "use strict";

  const tracks = [
    { artist: "Buruklyn Boyz", title: "24", file: "Buruklyn Boyz - 24.ogg" },
    { artist: "Buruklyn Boyz", title: "East Kwetu", file: "Buruklyn Boyz - East Kwetu.ogg" },
    { artist: "Mtu Mboka & Moti The NRG", title: "Morio Wa Me", file: "Mtu Mboka & Moti The NRG - Morio Wa Me.ogg" },
    { artist: "NI GENJE", title: "Stickman", file: "NI GENJE - Stickman.ogg" }
  ];

  const audio = new Audio();
  audio.preload = "auto";
  audio.volume = 0.5;
  let index = Math.floor(Math.random() * tracks.length);
  let started = false;

  const panel = document.createElement("div");
  panel.id = "mm-radio";
  panel.setAttribute("role", "status");
  panel.innerHTML = '<button id="mm-radio-toggle" type="button">▶ ENABLE MUSIC</button><span id="mm-radio-track">254 STREET RADIO</span>';
  document.body.appendChild(panel);

  const style = document.createElement("style");
  style.textContent = `
    #mm-radio {
      position: fixed; right: 14px; top: 14px; z-index: 2147483647;
      display: flex; align-items: center; gap: 10px; max-width: min(520px, calc(100vw - 28px));
      padding: 9px 12px; border: 1px solid rgba(92,236,255,.8); border-radius: 12px;
      background: rgba(4,8,18,.92); color: #5cecff; font: 700 13px/1.25 system-ui,sans-serif;
      box-shadow: 0 8px 28px rgba(0,0,0,.45);
    }
    #mm-radio button {
      border: 0; border-radius: 8px; padding: 7px 10px; cursor: pointer;
      background: #ffe15a; color: #111827; font: 900 12px system-ui,sans-serif;
    }
    #mm-radio-track { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  `;
  document.head.appendChild(style);

  const button = document.getElementById("mm-radio-toggle");
  const label = document.getElementById("mm-radio-track");

  function loadCurrent() {
    const track = tracks[index];
    audio.src = "radio/" + encodeURIComponent(track.file).replace(/%2F/g, "/");
    label.textContent = track.artist + " — " + track.title;
  }

  async function playCurrent() {
    if (!audio.src) loadCurrent();
    try {
      await audio.play();
      started = true;
      button.textContent = "❚❚ PAUSE";
      panel.style.borderColor = "rgba(98,255,130,.9)";
    } catch (error) {
      started = false;
      button.textContent = "▶ ENABLE MUSIC";
      label.textContent = "CLICK ENABLE MUSIC • " + (error && error.name ? error.name : "BROWSER BLOCKED AUDIO");
      panel.style.borderColor = "rgba(255,77,100,.95)";
    }
  }

  function next() {
    index = (index + 1) % tracks.length;
    loadCurrent();
    void playCurrent();
  }

  function toggle() {
    if (!audio.paused) {
      audio.pause();
      button.textContent = "▶ PLAY MUSIC";
      return;
    }
    void playCurrent();
  }

  button.addEventListener("click", event => {
    event.preventDefault();
    event.stopPropagation();
    toggle();
  });

  audio.addEventListener("ended", next);
  audio.addEventListener("error", () => {
    label.textContent = "TRACK LOAD FAILED • PRESS N";
    panel.style.borderColor = "rgba(255,77,100,.95)";
  });

  window.addEventListener("pointerdown", event => {
    if (event.target && event.target.closest && event.target.closest("#mm-radio")) return;
    if (!started || audio.paused) void playCurrent();
  }, true);

  window.addEventListener("keydown", event => {
    if (event.repeat) return;
    if (event.key.toLowerCase() === "n") next();
    if (event.key.toLowerCase() === "m") toggle();
  }, true);

  loadCurrent();
})();