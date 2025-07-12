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

  const drawArrays = (count) => {
    gl.drawArrays(gl.TRIANGLE_STRIP, 0, count);
  };

  const uniform3f = (p, uPtr, uLen, x, y, z) => {
    const loc = gl.getUniformLocation(programs[p], readString(uPtr, uLen));
    gl.uniform3f(loc, x, y, z);
  };
  const uniform1f = (p, uPtr, uLen, x) => {
    const loc = gl.getUniformLocation(programs[p], readString(uPtr, uLen));
    gl.uniform1f(loc, x);
  };
  const uniform1i = (p, uPtr, uLen, x) => {
    const loc = gl.getUniformLocation(programs[p], readString(uPtr, uLen));
    gl.uniform1i(loc, x);
  };
  const uniform1ui = (p, uPtr, uLen, x) => {
    const loc = gl.getUniformLocation(programs[p], readString(uPtr, uLen));
    gl.uniform1ui(loc, x);
  };

  const bindAndCreateTexture = (srcPtr, srcLen, textureUnit) => {
    const src = readString(srcPtr, srcLen);

    const image = new Image();
    image.src = src;
    image.addEventListener("load", () => {
      gl.activeTexture(textureUnit);
      const texture = gl.createTexture();
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
  };

  const framebuffers = [];
  const createFramebuffer = () => {
    const framebuffer = gl.createFramebuffer();
    framebuffers.push(framebuffer);
    return framebuffers.length - 1;
  };

  const bindFramebuffer = (framebufferIdx) => {
    gl.bindFramebuffer(gl.FRAMEBUFFER, framebuffers[framebufferIdx]);
  };

  const activeTexture = (textureUnit) => {
    gl.activeTexture(textureUnit);
  };

  const textures = [];
  const createTexture = () => {
    const tex = gl.createTexture();
    textures.push(tex);
    return textures.length - 1;
  };
  const bindTexture = (textureIdx) => {
    gl.bindTexture(gl.TEXTURE_2D, textures[textureIdx]);
  };

  const bindNullTexture = () => {
    gl.bindTexture(gl.TEXTURE_2D, null);
  };

  const createFramebufferTexture = (width, height) => {
    const framebufferTexture = gl.createTexture();
    textures.push(framebufferTexture);

    gl.bindTexture(gl.TEXTURE_2D, framebufferTexture);
    gl.texImage2D(
      gl.TEXTURE_2D,
      0,
      gl.RGBA,
      width,
      height,
      0,
      gl.RGBA,
      gl.UNSIGNED_BYTE,
      null,
    );
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);

    gl.framebufferTexture2D(
      gl.FRAMEBUFFER,
      gl.COLOR_ATTACHMENT0,
      gl.TEXTURE_2D,
      framebufferTexture,
      0,
    );

    if (gl.checkFramebufferStatus(gl.FRAMEBUFFER) !== gl.FRAMEBUFFER_COMPLETE) {
      throw new Error("Framebuffer is not complete");
    }

    return textures.length - 1;
  };

  const bindNullFramebuffer = () => {
    gl.bindFramebuffer(gl.FRAMEBUFFER, null);
  };

  const env = {
    _print,
    compileShader,
    createProgram,
    useProgram,
    drawArrays,
    uniform3f,
    uniform1f,
    uniform1i,
    uniform1ui,
    bindAndCreateTexture,
    createFramebuffer,
    bindFramebuffer,
    activeTexture,
    createTexture,
    bindTexture,
    bindNullTexture,
    createFramebufferTexture,
    bindNullFramebuffer,

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

  exports.init(canvas.width, canvas.height);

  const animate = () => {
    exports.tick(canvas.width, canvas.height);
    window.requestAnimationFrame(() => animate());
  };
  animate();
})();
