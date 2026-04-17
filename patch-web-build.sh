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

# Use perl to inject the helper scripts before the index.js script tag
perl -i -pe 'BEGIN{undef $/;} s/<script src="index.js"><\/script>/<script>\nwindow.addEventListener("pointerdown", async () => {\n  try {\n    if (window.DeepgramMic && window.DeepgramMic.ctx && window.DeepgramMic.ctx.state !== "running") {\n      await window.DeepgramMic.ctx.resume();\n      console.log("Resumed DeepgramMic AudioContext");\n    }\n    if (window.DeepgramTTS && window.DeepgramTTS.ctx && window.DeepgramTTS.ctx.state !== "running") {\n      await window.DeepgramTTS.ctx.resume();\n      console.log("Resumed DeepgramTTS AudioContext");\n    }\n  } catch (e) {\n    console.error("AudioContext resume failed:", e);\n  }\n}, { once: false });\n<\/script>\n\n<!-- Deepgram Mic helper -->\n<script>\nwindow.DeepgramMic = {\n  ctx: null,\n  source: null,\n  processor: null,\n  ws: null,\n  muted: false,\n\n  toggleMute() {\n    this.muted = !this.muted;\n    console.log("Mic muted:", this.muted);\n  },\n\n  async start() {\n    if (this.processor) return;\n\n    if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {\n      console.error("getUserMedia not available");\n      return;\n    }\n\n    const stream = await navigator.mediaDevices.getUserMedia({ audio: true });\n\n    const Ctx = window.AudioContext || window.webkitAudioContext;\n    const ctx = new Ctx();\n    this.ctx = ctx;\n\n    await ctx.resume().catch(console.error);\n    console.log("Mic ctx state:", ctx.state);\n\n    const source = ctx.createMediaStreamSource(stream);\n    this.source = source;\n\n    const bufferSize = 2048;\n    const processor = ctx.createScriptProcessor(bufferSize, 1, 1);\n    this.processor = processor;\n\n    processor.onaudioprocess = (event) => {\n      if (!this.ws || this.ws.readyState !== WebSocket.OPEN) return;\n\n      const input = event.inputBuffer.getChannelData(0);\n      const len = input.length;\n      const pcm16 = new Int16Array(len);\n\n      for (let i = 0; i < len; i++) {\n        let s = this.muted ? 0 : input[i];\n        s = Math.max(-1, Math.min(1, s));\n        pcm16[i] = s < 0 ? s * 0x8000 : s * 0x7fff;\n      }\n\n      this.ws.send(pcm16.buffer);\n    };\n\n    \/\/ Chrome needs the processor connected to a live graph\n    const muteGain = ctx.createGain();\n    muteGain.gain.value = 0;\n\n    source.connect(processor);\n    processor.connect(muteGain);\n    muteGain.connect(ctx.destination);\n  },\n\n  stop() {\n    if (!this.processor) return;\n\n    this.source && this.source.disconnect();\n    this.processor.disconnect();\n    this.processor.onaudioprocess = null;\n    this.processor = null;\n  }\n};\n\nwindow.addEventListener("keydown", (e) => {\n  if (e.repeat) return;\n  if (e.key === "m" || e.key === "M") {\n    if (window.DeepgramMic) {\n      window.DeepgramMic.toggleMute();\n    }\n  }\n});\n<\/script>\n\n<!-- Deepgram TTS helper -->\n<script>\nwindow.DeepgramTTS = {\n  ctx: null,\n  nextTime: 0,\n  started: false,\n  activeSources: new Set(),\n  generation: 0,\n\n  _ensureCtx() {\n    if (this.ctx) return;\n\n    const Ctx = window.AudioContext || window.webkitAudioContext;\n    this.ctx = new Ctx();\n  },\n\n  async enqueue(arrayBuffer) {\n    this._ensureCtx();\n\n    if (this.ctx.state !== "running") {\n      await this.ctx.resume().catch(console.error);\n    }\n\n    console.log("TTS ctx state:", this.ctx.state);\n\n    const myGeneration = this.generation;\n\n    const pcm16 = new Int16Array(arrayBuffer);\n    const len = pcm16.length;\n\n    const audioBuffer = this.ctx.createBuffer(1, len, this.ctx.sampleRate);\n    const ch = audioBuffer.getChannelData(0);\n\n    for (let i = 0; i < len; i++) {\n      ch[i] = pcm16[i] \/ 32768;\n    }\n\n    const src = this.ctx.createBufferSource();\n    src.buffer = audioBuffer;\n    src.connect(this.ctx.destination);\n\n    const now = this.ctx.currentTime;\n\n    if (!this.started || this.nextTime < now + 0.03) {\n      this.nextTime = now + 0.03;\n      this.started = true;\n    }\n\n    this.activeSources.add(src);\n\n    src.onended = () => {\n      this.activeSources.delete(src);\n    };\n\n    if (myGeneration !== this.generation) {\n      try { src.disconnect(); } catch (_) {}\n      this.activeSources.delete(src);\n      return;\n    }\n\n    src.start(this.nextTime);\n    this.nextTime += audioBuffer.duration;\n  },\n\n  reset() {\n    this.generation += 1;\n    this.started = false;\n    this.nextTime = 0;\n\n    for (const src of this.activeSources) {\n      try { src.stop(0); } catch (_) {}\n      try { src.disconnect(); } catch (_) {}\n    }\n\n    this.activeSources.clear();\n  }\n};\n<\/script>\n\n\t\t<script src="index.js"><\/script>/s' "$INDEX_HTML"

echo "Web build patched successfully!"
echo "Backups saved as:"
echo "  - $INDEX_JS.backup"
echo "  - $INDEX_HTML.backup"
