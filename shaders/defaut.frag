/*
#version 430 core

layout(location = 0) out vec4 color;

layout(location = 0) in vec3 v_VertCouleur;
layout(location = 1) in vec2 v_TexCoord;

void main()
{
    color = vec4(1, 1, 1, 1);
}
*/
#version 450

layout(location = 0) in vec3 fragColor;

layout(location = 0) out vec4 outColor;

void main() {
    outColor = vec4(fragColor, 1.0);
}
