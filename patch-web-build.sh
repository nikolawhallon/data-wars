#!/bin/bash
set -e

# Script to patch the web build with Deepgram proxy integration
# This applies the patches described in the README

BUILD_DIR="${1:-build/web}"

if [ ! -d "$BUILD_DIR" ]; then
    echo "Error: Build directory '$BUILD_DIR' does not exist"
    exit 1
fi

INDEX_JS="$BUILD_DIR/index.js"
INDEX_HTML="$BUILD_DIR/index.html"

if [ ! -f "$INDEX_JS" ]; then
    echo "Error: index.js not found at $INDEX_JS"
    exit 1
fi

if [ ! -f "$INDEX_HTML" ]; then
    echo "Error: index.html not found at $INDEX_HTML"
    exit 1
fi

echo "Patching web build in $BUILD_DIR..."

# Backup original files
cp "$INDEX_JS" "$INDEX_JS.backup"
cp "$INDEX_HTML" "$INDEX_HTML.backup"

echo "Patching index.js..."

# Patch index.js - replace the WebSocket creation code
perl -i -pe 's/let socket=null;try\{if\(protos\)\{socket=new WebSocket\(url,protos\.split\(","\)\)\}else\{socket=new WebSocket\(url\)\}\}catch\(e\)\{return 0\}socket\.binaryType="arraybuffer";return GodotWebSocket\.create\(socket,on_open,on_message,on_error,on_close\)/let socket = null;\n\ntry {\n  const parsedUrl = new URL(url, window.location.href);\n  const tag = parsedUrl.searchParams.get("tag");\n  const isDeepgram = url.startsWith("wss:\/\/deeproxy.vacuumbrewstudios.com");\n  const isPlayer = isDeepgram \&\& tag === "player";\n\n  if (protos) {\n    socket = new WebSocket(url, protos.split(","));\n\n  } else if (isDeepgram) {\n    socket = new WebSocket(url);\n\n    if (isPlayer) {\n      if (window.DeepgramMic) {\n        window.DeepgramMic.ws = socket;\n        socket.addEventListener("open", () => {\n          window.DeepgramMic.start().catch(console.error);\n        });\n      }\n\n      \/\/ Deepgram-specific handlers: text -> Godot, binary -> JS only\n      socket.onopen = (ev) => on_open(ev);\n      socket.onerror = (ev) => on_error(ev);\n      socket.onclose = (ev) => on_close(ev);\n\n      socket.onmessage = (event) => {\n        if (typeof event.data === "string") {\n          try {\n            const msg = JSON.parse(event.data);\n            if (msg \&\& msg.type === "UserStartedSpeaking") {\n              if (window.DeepgramTTS \&\& window.DeepgramTTS.reset) {\n                window.DeepgramTTS.reset();\n              }\n            }\n          } catch (e) {\n            \/\/ ignore\n          }\n\n          const enc = new TextEncoder("utf-8");\n          const buffer = new Uint8Array(enc.encode(event.data));\n          const len = buffer.length;\n          const out = GodotRuntime.malloc(len);\n\n          HEAPU8.set(buffer, out);\n          on_message(out, len, 1);\n          GodotRuntime.free(out);\n\n        } else {\n          if (window.DeepgramTTS) {\n            if (event.data instanceof ArrayBuffer) {\n              window.DeepgramTTS.enqueue(event.data);\n            } else if (event.data instanceof Blob) {\n              event.data.arrayBuffer().then(buf => window.DeepgramTTS.enqueue(buf));\n            }\n          }\n        }\n      };\n\n      socket.binaryType = "arraybuffer";\n      return IDHandler.add(socket);\n    }\n\n  } else {\n    socket = new WebSocket(url);\n  }\n\n} catch (e) {\n  return 0;\n}\n\nsocket.binaryType = "arraybuffer";\nreturn GodotWebSocket.create(socket, on_open, on_message, on_error, on_close)/g' "$INDEX_JS"

echo "Patching index.html..."

# Create the helper scripts to inject into index.html
HELPER_SCRIPTS='<script>
window.addEventListener("pointerdown", async () => {
  try {
    if (window.DeepgramMic && window.DeepgramMic.ctx && window.DeepgramMic.ctx.state !== "running") {
      await window.DeepgramMic.ctx.resume();
      console.log("Resumed DeepgramMic AudioContext");
    }
    if (window.DeepgramTTS && window.DeepgramTTS.ctx && window.DeepgramTTS.ctx.state !== "running") {
      await window.DeepgramTTS.ctx.resume();
      console.log("Resumed DeepgramTTS AudioContext");
    }
  } catch (e) {
    console.error("AudioContext resume failed:", e);
  }
}, { once: false });
</script>

<!-- Deepgram Mic helper -->
<script>
window.DeepgramMic = {
  ctx: null,
  source: null,
  processor: null,
  ws: null,
  muted: false,

  toggleMute() {
    this.muted = !this.muted;
    console.log("Mic muted:", this.muted);
  },

  async start() {
    if (this.processor) return;

    if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
      console.error("getUserMedia not available");
      return;
    }

    const stream = await navigator.mediaDevices.getUserMedia({ audio: true });

    const Ctx = window.AudioContext || window.webkitAudioContext;
    const ctx = new Ctx();
    this.ctx = ctx;

    await ctx.resume().catch(console.error);
    console.log("Mic ctx state:", ctx.state);

    const source = ctx.createMediaStreamSource(stream);
    this.source = source;

    const bufferSize = 2048;
    const processor = ctx.createScriptProcessor(bufferSize, 1, 1);
    this.processor = processor;

    processor.onaudioprocess = (event) => {
      if (!this.ws || this.ws.readyState !== WebSocket.OPEN) return;

      const input = event.inputBuffer.getChannelData(0);
      const len = input.length;
      const pcm16 = new Int16Array(len);

      for (let i = 0; i < len; i++) {
        let s = this.muted ? 0 : input[i];
        s = Math.max(-1, Math.min(1, s));
        pcm16[i] = s < 0 ? s * 0x8000 : s * 0x7fff;
      }

      this.ws.send(pcm16.buffer);
    };

    // Chrome needs the processor connected to a live graph
    const muteGain = ctx.createGain();
    muteGain.gain.value = 0;

    source.connect(processor);
    processor.connect(muteGain);
    muteGain.connect(ctx.destination);
  },

  stop() {
    if (!this.processor) return;

    this.source && this.source.disconnect();
    this.processor.disconnect();
    this.processor.onaudioprocess = null;
    this.processor = null;
  }
};

window.addEventListener("keydown", (e) => {
  if (e.repeat) return;
  if (e.key === "m" || e.key === "M") {
    if (window.DeepgramMic) {
      window.DeepgramMic.toggleMute();
    }
  }
});
</script>

<!-- Deepgram TTS helper -->
<script>
window.DeepgramTTS = {
  ctx: null,
  nextTime: 0,
  started: false,
  activeSources: new Set(),
  generation: 0,

  _ensureCtx() {
    if (this.ctx) return;

    const Ctx = window.AudioContext || window.webkitAudioContext;
    this.ctx = new Ctx();
  },

  async enqueue(arrayBuffer) {
    this._ensureCtx();

    if (this.ctx.state !== "running") {
      await this.ctx.resume().catch(console.error);
    }

    console.log("TTS ctx state:", this.ctx.state);

    const myGeneration = this.generation;

    const pcm16 = new Int16Array(arrayBuffer);
    const len = pcm16.length;

    const audioBuffer = this.ctx.createBuffer(1, len, this.ctx.sampleRate);
    const ch = audioBuffer.getChannelData(0);

    for (let i = 0; i < len; i++) {
      ch[i] = pcm16[i] / 32768;
    }

    const src = this.ctx.createBufferSource();
    src.buffer = audioBuffer;
    src.connect(this.ctx.destination);

    const now = this.ctx.currentTime;

    if (!this.started || this.nextTime < now + 0.03) {
      this.nextTime = now + 0.03;
      this.started = true;
    }

    this.activeSources.add(src);

    src.onended = () => {
      this.activeSources.delete(src);
    };

    if (myGeneration !== this.generation) {
      try { src.disconnect(); } catch (_) {}
      this.activeSources.delete(src);
      return;
    }

    src.start(this.nextTime);
    this.nextTime += audioBuffer.duration;
  },

  reset() {
    this.generation += 1;
    this.started = false;
    this.nextTime = 0;

    for (const src of this.activeSources) {
      try { src.stop(0); } catch (_) {}
      try { src.disconnect(); } catch (_) {}
    }

    this.activeSources.clear();
  }
};
</script>

		<script src="index.js"></script>'

# Escape special characters for sed
HELPER_SCRIPTS_ESCAPED=$(printf '%s\n' "$HELPER_SCRIPTS" | sed -e 's/[\/&]/\\&/g')

# Replace <script src="index.js"></script> with the helper scripts
sed -i "s/<script src=\"index.js\"><\/script>/$HELPER_SCRIPTS_ESCAPED/g" "$INDEX_HTML"

echo "Web build patched successfully!"
echo "Backups saved as:"
echo "  - $INDEX_JS.backup"
echo "  - $INDEX_HTML.backup"
