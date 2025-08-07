#version 460

layout(location = 0) in vec3 color;
layout(location = 1) in vec3 normal;

layout(location = 0) out vec4 fragColor;

void main()
{
    vec3 unitNormal = normalize(normal);
    vec3 lightDirection = normalize(vec3(0,1,0));
    float brightness = max(dot(unitNormal, lightDirection), 0.2);
    fragColor = vec4(color * brightness, 1);
}
