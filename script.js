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

  // instance.exports.init();

  const vertex = `
    attribute vec3 a_Position;
    attribute vec2 a_Uv;
    varying highp vec2 v_Uv;
    void main() {
        gl_Position = vec4(a_Position, 1.0);
        v_Uv = a_Uv;
    }
  `;

  const vertexShader = gl.createShader(gl.VERTEX_SHADER);
  if (!vertexShader) return;
  gl.shaderSource(vertexShader, vertex);
  gl.compileShader(vertexShader);
  if (!gl.getShaderParameter(vertexShader, gl.COMPILE_STATUS)) {
    alert("Error compiling shader: " + gl.getShaderInfoLog(vertexShader));
    return;
  }

  const fragment = `
    varying highp vec2 v_Uv;
    void main() {
        gl_FragColor = vec4(v_Uv, 0.0, 1.0);
    }
  `;

  const fragmentShader = gl.createShader(gl.FRAGMENT_SHADER);
  if (!fragmentShader) return;
  gl.shaderSource(fragmentShader, fragment);
  gl.compileShader(fragmentShader);
  if (!gl.getShaderParameter(fragmentShader, gl.COMPILE_STATUS)) {
    alert("Error compiling shader: " + gl.getShaderInfoLog(fragmentShader));
    return;
  }

  const glProgram = gl.createProgram();

  gl.attachShader(glProgram, vertexShader);
  gl.attachShader(glProgram, fragmentShader);
  gl.linkProgram(glProgram);
  if (!gl.getProgramParameter(glProgram, gl.LINK_STATUS)) {
    alert("Unable to initialize the shader program");
    return;
  }

  gl.useProgram(glProgram);

  // prettier-ignore
  const vertices = new Float32Array([
    -1.0, -1.0, 0.0,
    1.0, -1.0, 0.0,
    -1.0, 1.0, 0.0,
    1.0, 1.0, 0.0,
  ]);
  // prettier-ignore
  const colors = new Float32Array([
    0.0, 1.0,
    1.0, 1.0,
    0.0, 0.0,
    1.0, 0.0,
  ]);

  const vertexBuffer = gl.createBuffer();
  gl.bindBuffer(gl.ARRAY_BUFFER, vertexBuffer);
  gl.bufferData(gl.ARRAY_BUFFER, vertices, gl.STATIC_DRAW);
  const a_Position = gl.getAttribLocation(glProgram, "a_Position");
  gl.vertexAttribPointer(a_Position, 3, gl.FLOAT, false, 0, 0);
  gl.enableVertexAttribArray(a_Position);

  const trianglesColorBuffer = gl.createBuffer();
  gl.bindBuffer(gl.ARRAY_BUFFER, trianglesColorBuffer);
  gl.bufferData(gl.ARRAY_BUFFER, colors, gl.STATIC_DRAW);
  const a_Uv = gl.getAttribLocation(glProgram, "a_Uv");
  gl.vertexAttribPointer(a_Uv, 2, gl.FLOAT, false, 0, 0);
  gl.enableVertexAttribArray(a_Uv);

  gl.clearColor(0.0, 0.0, 0.0, 1.0);
  gl.clear(gl.COLOR_BUFFER_BIT);

  gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4);

  // console.log(r);
})();
