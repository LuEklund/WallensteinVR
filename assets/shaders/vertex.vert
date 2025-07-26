
#version 450
layout(location = 0) out vec3 color;
layout(binding = 0) uniform Matrices {
    mat4 projection;
    mat4 view;
    mat4 model;
} matrices;
vec3 vertices[3] = vec3[](
    vec3(1, 1, 4),
    vec3(-1, -1, 4),
    vec3(+1, -1, 4)
);
vec3 colors[3] = vec3[](
    vec3(1, 0, 0),
    vec3(0, 1, 0),
    vec3(0, 0, 1)
);

void main()
{
    gl_Position = matrices.projection * matrices.view * matrices.model * vec4(vertices[gl_VertexIndex], 1);
    color = colors[gl_VertexIndex];
    //color = abs(vertices[gl_VertexIndex]);
}