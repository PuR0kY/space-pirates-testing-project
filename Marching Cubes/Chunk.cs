using Godot;
using SpacePiratesTestingProject.Marching_Cubes;
using System.Collections.Generic;

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

    private Vector3[] CalculateNormals(List<Vector3> verts, List<int> tris)
    {
        Vector3[] normals = new Vector3[verts.Count];

        for (int i = 0; i < tris.Count; i += 3)
        {
            int i0 = tris[i];
            int i1 = tris[i + 1];
            int i2 = tris[i + 2];

            Vector3 v0 = verts[i0];
            Vector3 v1 = verts[i1];
            Vector3 v2 = verts[i2];

            Vector3 normal = (v1 - v0).Cross(v2 - v0).Normalized();

            normals[i0] += normal;
            normals[i1] += normal;
            normals[i2] += normal;
        }

        for (int i = 0; i < normals.Length; i++)
            normals[i] = normals[i].Normalized();

        return normals;
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
