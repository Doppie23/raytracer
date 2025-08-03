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
  const deleteFramebuffer = (idx) => {
    const framebuffer = framebuffers[idx];
    gl.deleteFramebuffer(framebuffer);
    framebuffers.splice(idx, 1);
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
  const deleteTexture = (idx) => {
    const tex = textures[idx];
    gl.deleteTexture(tex);
    textures.splice(idx, 0);
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
    deleteFramebuffer,
    bindFramebuffer,
    activeTexture,
    createTexture,
    deleteTexture,
    bindTexture,
    bindNullTexture,
    createFramebufferTexture,
    bindNullFramebuffer,

    clearColor: (r, g, b, a) => gl.clearColor(r, g, b, a),
    clear: (x) => gl.clear(x),
  };

  const res = await fetch("raytracer.wasm");
  const bytes = await res.arrayBuffer();

  const results = await WebAssembly.instantiate(bytes, { env });
  const instance = results.instance;
  exports = instance.exports;

  // desktop controls
  // TODO: handle keycodes in js
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
    KeyZ: 6,
    KeyX: 7,
    KeyC: 8,
  };
  document.addEventListener("keydown", (e) => {
    if (e.code in keymap && document.pointerLockElement === canvas) {
      exports.onKeyDown(keymap[e.code], true);
    }
  });
  document.addEventListener("keyup", (e) => {
    if (e.code in keymap && document.pointerLockElement === canvas) {
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

  // mobile controls
  const joystick = new Joystick();

  let previous = null;
  canvas.addEventListener("touchmove", (e) => {
    e.preventDefault();
    const touch = e.touches[0];
    if (!previous) {
      previous = {
        x: touch.clientX,
        y: touch.clientY,
      };
      return;
    }

    const dx = -(touch.clientX - previous.x);
    const dy = -(touch.clientY - previous.y);
    console.log(dx);
    exports.onMouseMove(dx, dy);

    previous = {
      x: touch.clientX,
      y: touch.clientY,
    };
  });
  canvas.addEventListener("touchend", () => {
    previous = null;
  });

  const resizeCanvasToDisplaySize = () => {
    const { width, height } = canvas.parentElement.getBoundingClientRect();

    const displayWidth = Math.floor(width);
    const displayHeight = Math.floor(height);

    if (canvas.width !== displayWidth || canvas.height !== displayHeight) {
      canvas.width = displayWidth;
      canvas.height = displayHeight;
    }

    gl.viewport(0, 0, canvas.width, canvas.height);
    exports.onResize(canvas.width, canvas.height);
  };
  resizeCanvasToDisplaySize();

  const ro = new ResizeObserver(resizeCanvasToDisplaySize);
  ro.observe(canvas.parentElement);

  exports.init(canvas.width, canvas.height);

  const animate = () => {
    if (joystick.dx !== 0 || joystick.dy !== 0) {
      const sens = 0.04;
      exports.moveCamera(joystick.dy * sens, joystick.dx * sens, 0);
    }
    exports.tick(canvas.width, canvas.height);
    window.requestAnimationFrame(() => animate());
  };
  animate();
})();

class Joystick {
  /** @type {HTMLDivElement} */
  outer;
  /** @type {HTMLDivElement} */
  inner;
  /** @type {number} */
  dx = 0;
  /** @type {number} */
  dy = 0;

  constructor() {
    /** @type {HTMLDivElement | null} */
    const outer = document.querySelector(".joystick-outer");
    if (!outer) {
      throw new Error("no outer circle");
    }
    this.outer = outer;

    /** @type {HTMLDivElement | null} */
    const inner = outer.querySelector(".joystick-inner");
    if (!inner) {
      throw new Error("no inner circle");
    }
    this.inner = inner;

    outer.addEventListener(
      "touchmove",
      (e) => {
        e.preventDefault();
        const touch = e.touches[0];
        this.moveInner(touch.clientX, touch.clientY);
      },
      { passive: false },
    );
    outer.addEventListener("touchend", () => {
      this.centerInner();
    });

    this.centerInner();
  }

  centerInner() {
    const { width: outerWidth, height: outerHeight } =
      this.outer.getBoundingClientRect();
    const { width: innerWidth, height: innerHeight } =
      this.inner.getBoundingClientRect();

    const y = outerHeight / 2 - innerHeight / 2;
    const x = outerWidth / 2 - innerWidth / 2;

    this.inner.style.top = `${y}px`;
    this.inner.style.left = `${x}px`;

    this.dx = 0;
    this.dy = 0;
  }

  moveInner(pageX, pageY) {
    const {
      top: outerTop,
      left: outerLeft,
      width: outerWidth,
      height: outerHeight,
    } = this.outer.getBoundingClientRect();
    const { width: innerWidth, height: innerHeight } =
      this.inner.getBoundingClientRect();

    const r = outerWidth / 2;

    const cx = outerLeft + outerWidth / 2;
    const cy = outerTop + outerHeight / 2;

    const isOutsideOuter =
      Math.pow(pageX - cx, 2) + Math.pow(pageY - cy, 2) > Math.pow(r, 2);

    let top;
    let left;

    if (!isOutsideOuter) {
      top = pageY - outerTop - innerHeight / 2;
      left = pageX - outerLeft - innerWidth / 2;
    } else {
      const dx = pageX - cx;
      const dy = pageY - cy;

      const l = Math.sqrt(Math.pow(dx, 2) + Math.pow(dy, 2));
      const ndx = dx / l;
      const ndy = dy / l;

      left = outerLeft + outerWidth - innerWidth / 2 - cx + ndx * r;
      top = outerTop + outerHeight - innerHeight / 2 - cy + ndy * r;
    }

    this.inner.style.top = `${top}px`;
    this.inner.style.left = `${left}px`;

    this.dx = ((left + innerWidth / 2 - outerWidth / 2) / outerWidth) * 2;
    this.dy = -((top + innerHeight / 2 - outerHeight / 2) / outerHeight) * 2;
  }
}
