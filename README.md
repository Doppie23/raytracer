# Raytracer

A raytracer written in Zig and JavaScript using WebGL2 and zero external dependencies.

![screenshot](/img/Screenshot%202025-07-13%20at%2016-09-48%20Document.png)

## Features

- [Phong shading](https://en.wikipedia.org/wiki/Phong_shading)
- Fully mirror like reflections
- Reflective surfaces using stochastic sampling, to simulate a rougher reflective surface.
- Progressive rendering to reduce noise in stochastic sampled rays.

## Keybinds

- Movement: `w`, `a`, `s`, `d`
- Fov:
  - `z`: zoom out
  - `x`: zoom in
  - `c`: reset

## Getting Started

```
zig build
```

Serve the webpage

```
python -m http.server 8080 -d public
# or
npm install -g live-server
live-server public
# or whatever else you might already have installed
```

## References

- HDRI: https://polyhaven.com/a/dikhololo_night
