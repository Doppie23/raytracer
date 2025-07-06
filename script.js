// @ts-check

(async () => {
  /** @type {HTMLCanvasElement | null} */
  const canvas = document.querySelector("#canvas");
  if (!canvas) throw new Error("No canvas");
  const gl = canvas.getContext("webgl");

  if (!gl) {
    alert(
      "Unable to initialize WebGL. Your browser or machine may not support it.",
    );
    return;
  }

  let exports;

  const _print = (ptr, len) => {
    const mem = new Uint8Array(instance.exports.memory.buffer);
    const msgBytes = mem.slice(ptr, ptr + len);
    const msg = new TextDecoder().decode(msgBytes);
    console.log(msg);
  };

  const env = {
    _print,
    clearColor: (r, g, b, a) => gl.clearColor(r, g, b, a),
    clear: (x) => gl.clear(x),
  };

  const res = await fetch("zig-out/bin/raytracer.wasm");
  const bytes = await res.arrayBuffer();

  const results = await WebAssembly.instantiate(bytes, { env });
  const instance = results.instance;
  exports = instance.exports;

  instance.exports.init();

  // console.log(r);
})();
