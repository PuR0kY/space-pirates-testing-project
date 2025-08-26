using Godot;
using SpacePiratesTestingProject.Marching_Cubes;
using System;
using System.Collections.Generic;
using System.Linq;

namespace SpacePiratesTestingProject.Marching_Cubes;

public class Chunk
{
    public Vector3I Position { get; private set; } // world origin (v jednotkách světa)
    public int Width { get; private set; }         // šířka chunku v jednotkách
    public int Height { get; private set; }        // výška chunku v jednotkách
    public int Resolution { get; }                 // vzorků na jednotku (>=1)

    public List<Vector3> Vertices = new List<Vector3>();
    public List<int> Triangles = new List<int>();
    private float[,,] heights;                     // indexová 3D mřížka (gx+1, gy+1, gz+1)

    public MeshInstance3D MeshInstance { get; private set; }

    private FastNoiseLite Noise;
    private float HeightThreshold;

    private float StepSize => 1f / Resolution;

    public Chunk(Vector3I position, int width, int height, FastNoiseLite noise, float heightThreshold, int resolution)
    {
        Position = position;
        Width = width;
        Height = height;
        Noise = noise;
        HeightThreshold = heightThreshold;
        Resolution = Mathf.Max(1, resolution);

        MeshInstance = new MeshInstance3D();
    }

    public void GenerateMesh()
    {
        Vertices.Clear();
        Triangles.Clear();

        int gx = Width * Resolution;
        int gy = Height * Resolution;
        int gz = Width * Resolution;

        // alokace pole heights (indexy 0..gx, 0..gy, 0..gz)
        heights = new float[gx + 1, gy + 1, gz + 1];

        Vector3 origin = new Vector3(Position.X, Position.Y, Position.Z);

        // naplníme heights pomocí indexové mřížky (bez float klíčů)
        for (int ix = 0; ix <= gx; ix++)
        {
            float wx = origin.X + ix * StepSize;
            for (int iy = 0; iy <= gy; iy++)
            {
                float wy = origin.Y + iy * StepSize;
                for (int iz = 0; iz <= gz; iz++)
                {
                    float wz = origin.Z + iz * StepSize;
                    heights[ix, iy, iz] = ComputeHeight(new Vector3(wx, wy, wz));
                }
            }
        }

        // marching cubes přes indexovanou mřížku (buňky 0..gx-1, ...)
        for (int x = 0; x < gx; x++)
        {
            for (int y = 0; y < gy; y++)
            {
                for (int z = 0; z < gz; z++)
                {
                    float[] cubeCorners = new float[8];

                    // načteme hodnoty rohů jako indexy (0 nebo 1 offset)
                    for (int i = 0; i < 8; i++)
                    {
                        int ox = (int)MarchingTable.Corners[i].X; // 0 nebo 1
                        int oy = (int)MarchingTable.Corners[i].Y;
                        int oz = (int)MarchingTable.Corners[i].Z;
                        cubeCorners[i] = heights[x + ox, y + oy, z + oz];
                    }

                    int configIndex = GetConfigurationIndex(cubeCorners);
                    if (configIndex == 0 || configIndex == 255) continue;

                    // base world position pro tento cell
                    Vector3 basePos = origin + new Vector3(x * StepSize, y * StepSize, z * StepSize);

                    MarchCube(basePos, cubeCorners, configIndex);
                }
            }
        }

        // vytvoření mesh (včetně normál)
        var arrayMesh = new ArrayMesh();
        var arrays = new Godot.Collections.Array();
        arrays.Resize((int)ArrayMesh.ArrayType.Max);

        arrays[(int)ArrayMesh.ArrayType.Vertex] = Vertices.ToArray();
        arrays[(int)ArrayMesh.ArrayType.Index] = Triangles.ToArray();
        arrays[(int)ArrayMesh.ArrayType.Normal] = CalculateNormals(Vertices, Triangles);

        arrayMesh.AddSurfaceFromArrays(Mesh.PrimitiveType.Triangles, arrays);
        MeshInstance.Mesh = arrayMesh;

        // materiál
        var mat = new StandardMaterial3D();
        mat.AlbedoColor = new Color(0.8f, 0.3f, 0.1f);
        mat.Metallic = 0.6f;
        mat.Roughness = 0.0f;
        MeshInstance.MaterialOverride = mat;
    }

    /** TODO: Přesun do Vertex nebo Compute shaderu a počítat na gpu? */
    //for (int i = 0; i < tris.Count; i += 3)
    //{
    //    int i0 = tris[i];
    //    int i1 = tris[i + 1];
    //    int i2 = tris[i + 2];

    //    Vector3 v0 = verts[i0];
    //    Vector3 v1 = verts[i1];
    //    Vector3 v2 = verts[i2];

    //    Vector3 normal = (v1 - v0).Cross(v2 - v0).Normalized();

    //    normals[i0] += normal;
    //    normals[i1] += normal;
    //    normals[i2] += normal;
    //}

    //return normals;
    private Vector3[] CalculateNormals(List<Vector3> verts, List<int> tris)
    {
        Vector3[] normals = new Vector3[verts.Count];

        var rd = RenderingServer.GetRenderingDevice();

        // --- Buffery ---
        int vertsSize = verts.Count * sizeof(float) * 4; // vec4 stride
        int trisSize = tris.Count * sizeof(int);
        int normalsAccumSize = normals.Length * sizeof(int) * 4; // ivec4 stride
        int normalsSize = normals.Length * sizeof(float) * 4; // vec4

        var vertsBuffer = rd.StorageBufferCreate((uint)vertsSize, ToBytesVec4(verts));
        var trisBuffer = rd.StorageBufferCreate((uint)trisSize, ToBytes(tris.ToArray()));
        var normalsAccumBuffer = rd.StorageBufferCreate((uint)normalsAccumSize, new byte[normalsAccumSize]);
        var normalsBuffer = rd.StorageBufferCreate((uint)normalsSize, new byte[normalsSize]);

        // --- Shadery ---
        var accumulateShaderFile = GD.Load<RDShaderFile>("res://Marching_Cubes/compute_normals.glsl");
        var normalizeShaderFile = GD.Load<RDShaderFile>("res://Marching_Cubes/normalize_normals.glsl");

        Rid accumulateShaderRID = rd.ShaderCreateFromSpirV(accumulateShaderFile.GetSpirV());
        Rid normalizeShaderRID = rd.ShaderCreateFromSpirV(normalizeShaderFile.GetSpirV());

        Rid accumulatePipeline = rd.ComputePipelineCreate(accumulateShaderRID);
        Rid normalizePipeline = rd.ComputePipelineCreate(normalizeShaderRID);

        // --- UniformSet (accumulate) ---
        var uVerts = new RDUniform { UniformType = RenderingDevice.UniformType.StorageBuffer, Binding = 0 };
        uVerts.AddId(vertsBuffer);

        var uTris = new RDUniform { UniformType = RenderingDevice.UniformType.StorageBuffer, Binding = 1 };
        uTris.AddId(trisBuffer);

        var uNormalsAccum = new RDUniform { UniformType = RenderingDevice.UniformType.StorageBuffer, Binding = 2 };
        uNormalsAccum.AddId(normalsAccumBuffer);

        var uniformsAccumulate = new Godot.Collections.Array<RDUniform> { uVerts, uTris, uNormalsAccum };
        Rid uniformSetAccumulate = rd.UniformSetCreate(uniformsAccumulate, accumulateShaderRID, 0);

        // --- Dispatch accumulate ---
        long list = rd.ComputeListBegin();
        rd.ComputeListBindComputePipeline(list, accumulatePipeline);
        rd.ComputeListBindUniformSet(list, uniformSetAccumulate, 0);


        uint localSize = 64;
        uint totalTriangles = (uint)(tris.Count / 3);
        uint groups = (uint)Math.Ceiling(totalTriangles / (float)localSize);

        rd.ComputeListDispatch(list, groups, 1, 1);
        rd.ComputeListEnd();
        rd.Submit();
        rd.Sync();

        // --- UniformSet (normalize) ---
        var uNormalsAccum2 = new RDUniform { UniformType = RenderingDevice.UniformType.StorageBuffer, Binding = 2 };
        uNormalsAccum2.AddId(normalsAccumBuffer);

        var uNormalsOut = new RDUniform { UniformType = RenderingDevice.UniformType.StorageBuffer, Binding = 3 };
        uNormalsOut.AddId(normalsBuffer);

        var uniformsNormalize = new Godot.Collections.Array<RDUniform> { uNormalsAccum2, uNormalsOut };
        Rid uniformSetNormalize = rd.UniformSetCreate(uniformsNormalize, normalizeShaderRID, 0);

        // --- Dispatch normalize ---
        list = rd.ComputeListBegin();
        rd.ComputeListBindComputePipeline(list, normalizePipeline);
        rd.ComputeListBindUniformSet(list, uniformSetNormalize, 0);

        uint totalVerts = (uint)verts.Count;
        uint groupsNormalize = (uint)Math.Ceiling(totalVerts / (float)localSize);

        rd.ComputeListDispatch(list, groupsNormalize, 1, 1);
        rd.ComputeListEnd();
        rd.Submit();
        rd.Sync();

        // --- Načtení výsledků ---
        var bytes = rd.BufferGetData(normalsBuffer);
        return FromBytesToVector3Vec4(bytes);
    }

    private static byte[] ToBytesVec4(List<Vector3> verts)
    {
        byte[] bytes = new byte[verts.Count * 16]; // vec4 stride
        int offset = 0;
        foreach (var v in verts)
        {
            Buffer.BlockCopy(new float[] { v.X, v.Y, v.Z, 0f }, 0, bytes, offset, 16);
            offset += 16;
        }
        return bytes;
    }

    private static byte[] ToBytes(int[] array)
    {
        byte[] bytes = new byte[array.Length * 4];
        Buffer.BlockCopy(array, 0, bytes, 0, bytes.Length);
        return bytes;
    }

    private static Vector3[] FromBytesToVector3Vec4(byte[] bytes)
    {
        int count = bytes.Length / 16;
        Vector3[] result = new Vector3[count];
        float[] floats = new float[count * 4];
        Buffer.BlockCopy(bytes, 0, floats, 0, bytes.Length);
        for (int i = 0; i < count; i++)
            result[i] = new Vector3(floats[i * 4], floats[i * 4 + 1], floats[i * 4 + 2]);
        return result;
    }

    private float ComputeHeight(Vector3 pos)
    {
        // ponechal jsem tvou původní logiku; pokud chceš škálovat noise, přidej NoiseScale
        float h = Height * ((Noise.GetNoise2D(pos.X, pos.Z) + 1f) / 2f);
        return pos.Y > h ? 1f : 0f;
    }

    private int GetConfigurationIndex(float[] cubeCorners)
    {
        int index = 0;
        for (int i = 0; i < 8; i++)
            if (cubeCorners[i] < HeightThreshold)
                index |= 1 << i;
        return index;
    }

    private void MarchCube(Vector3 pos, float[] cubeCorners, int configIndex)
    {
        int edgeIndex = 0;
        for (int t = 0; t < 5; t++)
        {
            for (int v = 0; v < 3; v++)
            {
                int triVal = MarchingTable.Triangles[configIndex, edgeIndex];
                if (triVal == -1) return;

                Vector3 edgeStart = pos + MarchingTable.Edges[triVal, 0] * StepSize;
                Vector3 edgeEnd = pos + MarchingTable.Edges[triVal, 1] * StepSize;
                Vector3 vertex = (edgeStart + edgeEnd) * 0.5f;

                Vertices.Add(vertex);
                Triangles.Add(Vertices.Count - 1);
                edgeIndex++;
            }
        }
    }
}
