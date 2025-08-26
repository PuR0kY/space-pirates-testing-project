#[compute]
#version 450
layout(local_size_x = 64) in;

layout(set = 0, binding = 2, std430) readonly buffer NormalsAccum {
    ivec4 normalsAccum[];
};

layout(set = 0, binding = 3, std430) buffer NormalsOut {
    vec4 normals[];
};

const float SCALE = 1000000.0;

void main() {
    uint i = gl_GlobalInvocationID.x;
    if(i >= normals.length()) return;

    vec3 n = vec3(normalsAccum[i].xyz) / SCALE;
    if(length(n) == 0.0)
        n = vec3(0.0,1.0,0.0);

    normals[i] = vec4(normalize(n), 0.0);
}
