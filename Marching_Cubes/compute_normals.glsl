#[compute]
#version 450
layout(local_size_x = 64) in;

layout(set = 0, binding = 0, std430) readonly buffer Verts {
    vec4 verts[];
};

layout(set = 0, binding = 1, std430) readonly buffer Tris {
    int tris[];
};

layout(set = 0, binding = 2, std430) buffer TriNormals {
    vec4 normals[]; // jedna normála na trojúhelník
};

void main() {
    uint triIndex = gl_GlobalInvocationID.x;
    if (triIndex * 3 + 2 >= tris.length()) return;

    uint i0 = uint(tris[triIndex * 3 + 0]);
    uint i1 = uint(tris[triIndex * 3 + 1]);
    uint i2 = uint(tris[triIndex * 3 + 2]);

    vec3 v0 = verts[i0].xyz;
    vec3 v1 = verts[i1].xyz;
    vec3 v2 = verts[i2].xyz;

    vec3 n = normalize(cross(v1 - v0, v2 - v0));
    normals[triIndex] = vec4(n, 0.0);
}
