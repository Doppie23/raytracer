#version 300 es

in vec3 a_Position;
in vec2 a_Uv;
out vec2 v_Uv;

void main() {
    gl_Position = vec4(a_Position, 1.0);
    v_Uv = a_Uv;
}
