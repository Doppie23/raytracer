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

  let textureIndex = 2; // start from 2 as 0 and 1 are used for the framebuffer
  const bindAndCreateTexture = (srcPtr, srcLen) => {
    const currentIndex = textureIndex;
    textureIndex++;
    const src = readString(srcPtr, srcLen);

    const image = new Image();
    image.src = src;
    image.addEventListener("load", () => {
      gl.activeTexture(gl.TEXTURE0 + currentIndex);
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

    return currentIndex;
  };

  // === FRAMEBUFFER SETUP ===
  // let framebufferOne = null;
  // let framebufferTextureOne = null;
  // let framebufferTwo = null;
  // let framebufferTextureTwo = null;
  let postProcessProgram = null;

  const createFramebuffer = (width, height) => {
    // Create framebuffer
    const framebuffer = gl.createFramebuffer();
    gl.bindFramebuffer(gl.FRAMEBUFFER, framebuffer);

    // Create texture for framebuffer
    const framebufferTexture = gl.createTexture();
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

    // Attach texture to framebuffer
    gl.framebufferTexture2D(
      gl.FRAMEBUFFER,
      gl.COLOR_ATTACHMENT0,
      gl.TEXTURE_2D,
      framebufferTexture,
      0,
    );

    // Create depth buffer (optional, if your raytracer needs it)
    const depthBuffer = gl.createRenderbuffer();
    gl.bindRenderbuffer(gl.RENDERBUFFER, depthBuffer);
    gl.renderbufferStorage(
      gl.RENDERBUFFER,
      gl.DEPTH_COMPONENT16,
      width,
      height,
    );
    gl.framebufferRenderbuffer(
      gl.FRAMEBUFFER,
      gl.DEPTH_ATTACHMENT,
      gl.RENDERBUFFER,
      depthBuffer,
    );

    // Check framebuffer completeness
    if (gl.checkFramebufferStatus(gl.FRAMEBUFFER) !== gl.FRAMEBUFFER_COMPLETE) {
      throw new Error("Framebuffer is not complete");
    }

    // Unbind framebuffer
    gl.bindFramebuffer(gl.FRAMEBUFFER, null);

    return { framebuffer, framebufferTexture };
  };

  const createPostProcessShaders = () => {
    // Simple vertex shader for fullscreen quad
    const vertexShaderSource = `#version 300 es
    out vec2 v_texCoord;
    void main() {
      vec2 pos = vec2((gl_VertexID << 1) & 2, gl_VertexID & 2);
      v_texCoord = vec2(pos.x, pos.y);
      gl_Position = vec4(pos * 2.0 - 1.0, 0.0, 1.0);
    }`;

    // Fragment shader for post-processing (you can modify this for effects)
    const fragmentShaderSource = `#version 300 es
    precision mediump float;

    in vec2 v_texCoord;
    uniform sampler2D u_texture;
    out vec4 fragColor;

    void main() {
      // Simple pass-through (you can add effects here)
      fragColor = texture(u_texture, v_texCoord);

      // Example: Add a slight color tint
      // fragColor.rgb *= vec3(1.1, 1.0, 0.9);
    }`;

    // Create shaders
    const vertexShader = gl.createShader(gl.VERTEX_SHADER);
    gl.shaderSource(vertexShader, vertexShaderSource);
    gl.compileShader(vertexShader);

    const fragmentShader = gl.createShader(gl.FRAGMENT_SHADER);
    gl.shaderSource(fragmentShader, fragmentShaderSource);
    gl.compileShader(fragmentShader);

    // Create program
    postProcessProgram = gl.createProgram();
    gl.attachShader(postProcessProgram, vertexShader);
    gl.attachShader(postProcessProgram, fragmentShader);
    gl.linkProgram(postProcessProgram);

    if (!gl.getProgramParameter(postProcessProgram, gl.LINK_STATUS)) {
      throw new Error("Post-process program failed to link");
    }
  };

  const renderPostProcess = (framebufferTexture, textureUnit) => {
    // Bind default framebuffer (canvas)
    gl.bindFramebuffer(gl.FRAMEBUFFER, null);
    gl.viewport(0, 0, canvas.width, canvas.height);

    // Use post-process program
    gl.useProgram(postProcessProgram);

    // Bind framebuffer texture
    gl.activeTexture(textureUnit);
    gl.bindTexture(gl.TEXTURE_2D, framebufferTexture);
    gl.uniform1i(gl.getUniformLocation(postProcessProgram, "u_texture"), 0);

    // Draw fullscreen quad
    gl.drawArrays(gl.TRIANGLE_FAN, 0, 3);
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

  // Initialize framebuffer and post-processing
  let framebufferTextureUnitActive = gl.TEXTURE0;
  let framebufferTextureUnitOther = gl.TEXTURE1;
  let {
    framebuffer: framebufferActive,
    framebufferTexture: framebufferTextureActive,
  } = createFramebuffer(canvas.width, canvas.height);
  let {
    framebuffer: framebufferOther,
    framebufferTexture: framebufferTextureOther,
  } = createFramebuffer(canvas.width, canvas.height);
  createPostProcessShaders();

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
    // Render to framebuffer
    gl.bindFramebuffer(gl.FRAMEBUFFER, framebufferActive);
    gl.viewport(0, 0, canvas.width, canvas.height);

    gl.activeTexture(framebufferTextureUnitActive);
    gl.bindTexture(gl.TEXTURE_2D, null);

    // Your raytracer renders here
    const previousFrame = framebufferTextureUnitOther - gl.TEXTURE0;
    exports.tick(canvas.width, canvas.height, previousFrame);

    // Render post-process pass to canvas
    renderPostProcess(framebufferTextureActive, framebufferTextureUnitActive);

    [framebufferActive, framebufferOther] = [
      framebufferOther,
      framebufferActive,
    ];
    [framebufferTextureActive, framebufferTextureOther] = [
      framebufferTextureOther,
      framebufferTextureActive,
    ];
    [framebufferTextureUnitActive, framebufferTextureUnitOther] = [
      framebufferTextureUnitOther,
      framebufferTextureUnitActive,
    ];
    //
    //   framebufferTextureActive,
    //   framebufferTextureUnitActive,
    // ] = [
    //   framebufferOther,
    //   framebufferTextureOther,
    //   framebufferTextureUnitOther,
    // ];

    window.requestAnimationFrame(() => animate());
  };
  animate();
})();
