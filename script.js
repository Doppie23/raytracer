// @ts-check

(async () => {
  /** @type {HTMLCanvasElement | null} */
  const canvas = document.querySelector("#canvas");
  if (!canvas) throw new Error("No canvas");
  const gl = canvas.getContext("webgl2");

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

  // TODO: remove some duplication
  const uniform3f = (programIdx, uniformPtr, uniformLen, x, y, z) => {
    const name = readString(uniformPtr, uniformLen);
    const loc = gl.getUniformLocation(programs[programIdx], name);
    gl.uniform3f(loc, x, y, z);
  };
  const uniform1f = (programIdx, uniformPtr, uniformLen, x) => {
    const name = readString(uniformPtr, uniformLen);
    const loc = gl.getUniformLocation(programs[programIdx], name);
    gl.uniform1f(loc, x);
  };
  const uniform1i = (programIdx, uniformPtr, uniformLen, x) => {
    const name = readString(uniformPtr, uniformLen);
    const loc = gl.getUniformLocation(programs[programIdx], name);
    gl.uniform1i(loc, x);
  };

  let textureIndex = 0;
  const bindAndCreateTexture = (srcPtr, srcLen) => {
    const src = readString(srcPtr, srcLen);

    const texture = gl.createTexture();
    gl.bindTexture(gl.TEXTURE_2D, texture);

    const image = new Image();
    image.src = src;
    image.addEventListener("load", () => {
      gl.bindTexture(gl.TEXTURE_2D, texture);
      gl.texImage2D(
        gl.TEXTURE_2D,
        0,
        gl.RGBA,
        gl.RGBA,
        gl.UNSIGNED_BYTE,
        image,
      );
      gl.generateMipmap(gl.TEXTURE_2D);
    });

    const r = textureIndex;
    textureIndex++;
    return r;
  };

  const env = {
    _print,
    compileShader,
    createProgram,
    useProgram,
    createBufferAndBind,
    drawArrays,
    uniform3f,
    uniform1f,
    uniform1i,
    bindAndCreateTexture,

    clearColor: (r, g, b, a) => gl.clearColor(r, g, b, a),
    clear: (x) => gl.clear(x),
  };

  const res = await fetch("zig-out/bin/raytracer.wasm");
  const bytes = await res.arrayBuffer();

  const results = await WebAssembly.instantiate(bytes, { env });
  const instance = results.instance;
  exports = instance.exports;

  const keymap = {
    KeyW: 0,
    ArrowUp: 0,
    KeyA: 1,
    ArrowLeft: 1,
    KeyS: 2,
    ArrowDown: 2,
    KeyD: 3,
    ArrowRight: 3,
    Space: 4,
    ShiftLeft: 5,
  };
  document.addEventListener("keydown", (e) => {
    if (e.code in keymap) {
      exports.onKeyDown(keymap[e.code], true);
    }
  });
  document.addEventListener("keyup", (e) => {
    if (e.code in keymap) {
      exports.onKeyDown(keymap[e.code], false);
    }
  });
  canvas.addEventListener("click", async () => {
    await canvas.requestPointerLock();
  });

  const updatePosition = (e) => {
    exports.onMouseMove(e.movementX, e.movementY);
  };

  document.addEventListener(
    "pointerlockchange",
    () => {
      if (document.pointerLockElement === canvas) {
        document.addEventListener("mousemove", updatePosition, false);
      } else {
        document.removeEventListener("mousemove", updatePosition, false);
      }
    },
    false,
  );

  exports.init();

  const animate = () => {
    exports.tick(canvas.width, canvas.height);
    window.requestAnimationFrame(() => animate());
  };
  animate();
})();
