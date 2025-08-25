// density_compute.glsl
// shader_type compute je Godot-specific compute shader
shader_type compute;

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

// out image: RGBA32F 2D texture used as atlas
layout(binding = 0, rgba32f) writeonly uniform image2D outAtlas;

uniform ivec3 gridSize;    // gx, gy, gz
uniform vec3 chunkOrigin;  // world-space origin of chunk
uniform float step;        // world step between samples (1f / Resolution)
uniform float noiseScale;
uniform int slicePitch;    // gy (height in slices) such that sliceOffset = slice * slicePitch

// Simple FBM (octaves) noise stub - replace with your preferred shader noise
// For brevity use a basic value noise / sin-based pseudo-noise — you should replace
// this with a proper noise implementation (classic perlin / simplex / fastnoise port)
float hash(vec3 p) {
    p = fract(p * 0.3183099 + vec3(0.71, 0.113, 0.419));
    p *= 17.0;
    return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float fbm_noise(vec3 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 4; i++) {
        v += a * hash(p);
        p *= 2.0;
        a *= 0.5;
    }
    return v;
}

void main() {
    ivec2 gid = ivec2(gl_GlobalInvocationID.xy); // x, y in atlas
    int ax = gid.x;
    int ay = gid.y;

    // compute slice and local y
    int gx = gridSize.x;
    int gy = gridSize.y;
    int gz = gridSize.z;

    if (ax >= gx || ay >= gy * gz) {
        return; // out of bound
    }

    int slice = ay / gy;        // 0..gz-1
    int local_y = ay - slice * gy; // 0..gy-1

    int ix = ax;                // 0..gx-1
    int iy = local_y;           // 0..gy-1
    int iz = slice;             // 0..gz-1

    // world pos
    vec3 worldPos = chunkOrigin + vec3(float(ix) * step, float(iy) * step, float(iz) * step);

    // sample noise (FBM)
    float n = fbm_noise(worldPos * noiseScale);

    // map noise to 0..1
    n = clamp(n, 0.0, 1.0);

    // pack to RGBA32F (we only need R)
    imageStore(outAtlas, ivec2(ax, ay), vec4(n,0.0,0.0,0.0));
}
