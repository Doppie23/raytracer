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

  const readString = (ptr, len) => {
    const bytes = new Uint8Array(exports.memory.buffer, ptr, len);
    return new TextDecoder().decode(bytes);
  };

  const _print = (ptr, len) => {
    console.log(readString(ptr, len));
  };

  const shaders = [];
  const compileShader = (srcPointer, srcLen, shaderType) => {
    const src = readString(srcPointer, srcLen);
    const shader = gl.createShader(shaderType);
    if (!shader) throw new Error("Shader is null...");
    gl.shaderSource(shader, src);
    gl.compileShader(shader);

    if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
      throw new Error("Error compiling shader: " + gl.getShaderInfoLog(shader));
    }

    shaders.push(shader);
    return shaders.length - 1;
  };

  const programs = [];
  const createProgram = (vertexShaderIdx, fragmentShaderIdx) => {
    const glProgram = gl.createProgram();

    gl.attachShader(glProgram, shaders[vertexShaderIdx]);
    gl.attachShader(glProgram, shaders[fragmentShaderIdx]);
    gl.linkProgram(glProgram);
    if (!gl.getProgramParameter(glProgram, gl.LINK_STATUS)) {
      alert("Unable to initialize the shader program");
      return;
    }

    gl.useProgram(glProgram);

    programs.push(glProgram);
    return programs.length - 1;
  };

  const useProgram = (programIdx) => {
    gl.useProgram(programs[programIdx]);
  };

  const createBufferAndBind = (
    programIdx,
    dataPtr,
    dataLen,
    dataSize,
    attPtr,
    attLen,
  ) => {
    const data = new Float32Array(exports.memory.buffer, dataPtr, dataLen);
    const attName = readString(attPtr, attLen);

    const buffer = gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER, buffer);
    gl.bufferData(gl.ARRAY_BUFFER, data, gl.STATIC_DRAW);
    const att = gl.getAttribLocation(programs[programIdx], attName);
    gl.vertexAttribPointer(att, dataSize, gl.FLOAT, false, 0, 0);
    gl.enableVertexAttribArray(att);
  };

  const drawArrays = (count) => {
    gl.drawArrays(gl.TRIANGLE_STRIP, 0, count);
  };

  const env = {
    _print,
    compileShader,
    createProgram,
    useProgram,
    createBufferAndBind,
    drawArrays,

    clearColor: (r, g, b, a) => gl.clearColor(r, g, b, a),
    clear: (x) => gl.clear(x),
  };

  const res = await fetch("zig-out/bin/raytracer.wasm");
  const bytes = await res.arrayBuffer();

  const results = await WebAssembly.instantiate(bytes, { env });
  const instance = results.instance;
  exports = instance.exports;

  exports.init();
})();
