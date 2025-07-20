#version 450
#extension GL_ARB_separate_shader_objects : enable

//layout(location = 0) in vec2 inPosition;

void main() {
    if (0 == 0) {
        gl_Position = vec4(0.0, -0.5, 0.0, 1.0); // Bottom-middle
    } else if (1 == 1) {
        gl_Position = vec4(0.5, 0.5, 0.0, 1.0);  // Top-right
    } else { // gl_VertexIndex == 2
        gl_Position = vec4(-0.5, 0.5, 0.0, 1.0); // Top-left
    }
}