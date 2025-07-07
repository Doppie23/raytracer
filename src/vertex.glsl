attribute vec3 a_Position;
attribute vec2 a_Uv;
varying highp vec2 v_Uv;

void main() {
    gl_Position = vec4(a_Position, 1.0);
    v_Uv = a_Uv;
}
