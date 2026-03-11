# data-wars

## Linux Builds

The damn Linux export templates for Godot 4.6 seem to have some microphone bug. But the following got builds working:
```
cp /run/current-system/sw/bin/godot4.6 data-wars.x86_64
chmod u+w data-wars.x86_64
cat data-wars.pck >> data-wars.x86_64
chmod +x data-wars.x86_64
```

## Web Builds

I made this game with the latest (at the time) Godot 4.6 - unfortunately, a lot of previous nice Web compatibility
stuff seems to have been totally broken in this version over 4.2 or 3.x. I went through the following JS/HTML
hacks to get things back working again.

The general idea is to pass Deepgram audio directly to the browser to playback (by-passing Godot entirely),
and to pass microphone audio directly to Deepgram via the browser (by-passing Godot entirely). We also
hack back in authentication. Otherwise, text messages to and from Deepgram and Godot still function.

### Auth

In Web builds, in `index.js`, replace:
```
if(protos){socket=new WebSocket(url,protos.split(","))}else{socket=new WebSocket(url)}}
```
with (this fixes the WebSocket authentication issues):
```
if(protos){socket=new WebSocket(url,protos.split(","))}else if(url.startsWith("wss://agent.deepgram.com")){socket=new WebSocket(url,["token","DEEPGRAM_API_KEY"])}else{socket=new WebSocket(url)}}
```

### Microphone (and Auth)

In Web builds, in `index.js`, replace:
```
if(protos){socket=new WebSocket(url,protos.split(","))}else{socket=new WebSocket(url)}}
```
with (this fixes, additionally, the browser microphone issues, when including the Deepgram Mic helper below):
```
if(protos){socket=new WebSocket(url,protos.split(","))}else if(url.startsWith("wss://agent.deepgram.com")){socket=new WebSocket(url,["token","DEEPGRAM_API_KEY"]);if(window.DeepgramMic){window.DeepgramMic.ws=socket;socket.addEventListener("open",()=>{window.DeepgramMic.start().catch(console.error)})}}else{socket=new WebSocket(url)}}
```

Next, add between this:
```
                <div id="status">
                        <img id="status-splash" class="show-image--true fullsize--true use-filter--true" src="index.png" alt="">
                        <progress id="status-progress"></progress>
                        <div id="status-notice"></div>
                </div>
```
and this:
```
                <script src="index.js"></script>
                <script>
const GODOT_CONFIG = {"args":[],"canvasResizePolicy":2,"emscriptenPoolSize":8,"ensureCrossOriginIsolationHeaders":true,"executable":"index","experimentalVK":>
const GODOT_THREADS_ENABLED = false;
const engine = new Engine(GODOT_CONFIG);
```
in `index.html`, the following:
```
		<!-- Deepgram Mic helper: must be before index.js -->
		<script>
		window.DeepgramMic = {
			ctx: null,
			source: null,
			processor: null,
			ws: null,

			async start () {
				if (this.processor) return;
				if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
					console.error("getUserMedia not available");
					return;
				}
				const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
				const Ctx = window.AudioContext || window.webkitAudioContext;
				const ctx = new Ctx();
				this.ctx = ctx;

				const source = ctx.createMediaStreamSource(stream);
				this.source = source;

				const bufferSize = 2048;
				const processor = ctx.createScriptProcessor(bufferSize, 1, 1);
				this.processor = processor;

				processor.onaudioprocess = (event) => {
					if (!this.ws || this.ws.readyState !== WebSocket.OPEN) return;
					const input = event.inputBuffer.getChannelData(0); // mono Float32

					const len = input.length;
					const pcm16 = new Int16Array(len);
					for (let i = 0; i < len; i++) {
						let s = input[i];
						s = Math.max(-1, Math.min(1, s));
						pcm16[i] = s < 0 ? s * 0x8000 : s * 0x7fff;
					}
					this.ws.send(pcm16.buffer);
				};

				source.connect(processor);
				// Optionally connect to destination if you want local monitoring:
				// processor.connect(ctx.destination);
			},

			stop () {
				if (!this.processor) return;
				this.source && this.source.disconnect();
				this.processor.disconnect();
				this.processor.onaudioprocess = null;
				this.processor = null;
			}
		};
		</script>
```

### Playback (and Microphone (and Auth))

Ok, but this doesn't solve the audio playback issues. For that, in `index.js` replace the following and everything between:
```
let socket=null;try
```
and:
```
return GodotWebSocket.create(socket, on_open, on_message, on_error, on_close)}
```
with:
```
let socket=null;try{if(protos){
  socket = new WebSocket(url, protos.split(","))
}else if(url.startsWith("wss://agent.deepgram.com")){
  socket = new WebSocket(url, ["token","DEEPGRAM_API_KEY"]);

  if(window.DeepgramMic){
    window.DeepgramMic.ws = socket;
    socket.addEventListener("open", () => {
      window.DeepgramMic.start().catch(console.error);
    });
  }

  // Deepgram-specific handlers: text → Godot, binary → JS only
  socket.onopen  = (ev) => on_open(ev);
  socket.onerror = (ev) => on_error(ev);
  socket.onclose = (ev) => on_close(ev);
socket.onmessage = (event) => {
  if (typeof event.data === "string") {
    try {
      const msg = JSON.parse(event.data);
      if (msg && msg.type === "UserStartedSpeaking") {
        if (window.DeepgramTTS && window.DeepgramTTS.reset) {
          window.DeepgramTTS.reset();
        }
      }
    } catch (e) {
      // ignore
    }

    const enc = new TextEncoder("utf-8");
    const buffer = new Uint8Array(enc.encode(event.data));
    const len = buffer.length;
    const out = GodotRuntime.malloc(len);
    HEAPU8.set(buffer, out);
    on_message(out, len, 1);
    GodotRuntime.free(out);
  } else {
    if (window.DeepgramTTS) {
      if (event.data instanceof ArrayBuffer) {
        window.DeepgramTTS.enqueue(event.data);
      } else if (event.data instanceof Blob) {
        event.data.arrayBuffer().then(buf => window.DeepgramTTS.enqueue(buf));
      }
    }
  }
};
  socket.binaryType = "arraybuffer";
  return IDHandler.add(socket);
}else{
  socket = new WebSocket(url)
}}
catch(e){return 0}
socket.binaryType = "arraybuffer";
return GodotWebSocket.create(socket, on_open, on_message, on_error, on_close)}
```
and add the following after the Deepgram Mic helper JS script:
```
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

  async resume() {
    this._ensureCtx();
    if (this.ctx.state !== "running") {
      await this.ctx.resume();
    }
  },

  enqueue(arrayBuffer) {
    this._ensureCtx();

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

    // If reset happened while we were preparing this chunk, drop it.
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
```
