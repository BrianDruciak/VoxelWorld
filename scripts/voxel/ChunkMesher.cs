using Godot;
using System.Collections.Generic;

namespace VoxelEngine
{
    public class MeshBuildResult
    {
        public Vector3[] OpaqueVerts;
        public Vector3[] OpaqueNormals;
        public Vector2[] OpaqueUVs;
        public int[] OpaqueIndices;

        public Vector3[] TransVerts;
        public Vector3[] TransNormals;
        public Vector2[] TransUVs;
        public int[] TransIndices;

        public Vector3[] CollisionFaces;

        public bool HasOpaque => OpaqueVerts != null && OpaqueVerts.Length > 0;
        public bool HasTransparent => TransVerts != null && TransVerts.Length > 0;
    }

    public static class ChunkMesher
    {
        private static readonly Vector3I[] Normals =
        {
            new( 0,  1,  0),  // 0 Top
            new( 0, -1,  0),  // 1 Bottom
            new( 1,  0,  0),  // 2 Right  (+X)
            new(-1,  0,  0),  // 3 Left   (-X)
            new( 0,  0,  1),  // 4 Front  (+Z)
            new( 0,  0, -1),  // 5 Back   (-Z)
        };

        // Each quad: 4 vertices wound counter-clockwise when viewed from outside.
        // Side faces: v0,v1 at y=0 (bottom), v2,v3 at y=1 (top).
        private static readonly Vector3[][] FaceVerts =
        {
            new[] { new Vector3(0,1,0), new Vector3(1,1,0), new Vector3(1,1,1), new Vector3(0,1,1) },  // Top
            new[] { new Vector3(0,0,1), new Vector3(1,0,1), new Vector3(1,0,0), new Vector3(0,0,0) },  // Bottom
            new[] { new Vector3(1,0,0), new Vector3(1,0,1), new Vector3(1,1,1), new Vector3(1,1,0) },  // Right
            new[] { new Vector3(0,0,1), new Vector3(0,0,0), new Vector3(0,1,0), new Vector3(0,1,1) },  // Left
            new[] { new Vector3(1,0,1), new Vector3(0,0,1), new Vector3(0,1,1), new Vector3(1,1,1) },  // Front
            new[] { new Vector3(0,0,0), new Vector3(1,0,0), new Vector3(1,1,0), new Vector3(0,1,0) },  // Back
        };

        public static MeshBuildResult BuildMeshData(
            ChunkData chunk,
            ChunkData leftNeighbor,
            ChunkData rightNeighbor,
            ChunkData frontNeighbor,
            ChunkData backNeighbor)
        {
            var ov = new List<Vector3>(4096);
            var on = new List<Vector3>(4096);
            var ou = new List<Vector2>(4096);
            var oi = new List<int>(6144);

            var tv = new List<Vector3>(1024);
            var tn = new List<Vector3>(1024);
            var tu = new List<Vector2>(1024);
            var ti = new List<int>(1536);

            var cf = new List<Vector3>(8192);

            for (int x = 0; x < ChunkData.Width; x++)
            for (int y = 0; y < ChunkData.Height; y++)
            for (int z = 0; z < ChunkData.Depth; z++)
            {
                byte id = chunk.GetBlock(x, y, z);
                if (id == (byte)BlockID.Air)
                    continue;

                var props = BlockTypes.Get(id);
                bool transparent = props.IsTransparent;
                var blockPos = new Vector3(x, y, z);

                for (int face = 0; face < 6; face++)
                {
                    var norm = Normals[face];
                    int nx = x + norm.X;
                    int ny = y + norm.Y;
                    int nz = z + norm.Z;

                    byte nb = GetNeighbor(chunk, leftNeighbor, rightNeighbor,
                                          frontNeighbor, backNeighbor, nx, ny, nz);

                    bool render;
                    if (transparent)
                    {
                        // Transparent blocks render against air and against
                        // different transparent types (ice next to water, etc.)
                        render = nb == (byte)BlockID.Air || (nb != id && BlockTypes.IsTransparent(nb));
                    }
                    else
                    {
                        render = BlockTypes.IsTransparent(nb);
                    }

                    if (!render) continue;

                    BlockFaceUV uv = face == 0 ? props.TopUV
                                   : face == 1 ? props.BottomUV
                                   : props.SideUV;

                    var verts  = transparent ? tv : ov;
                    var norms  = transparent ? tn : on;
                    var uvs    = transparent ? tu : ou;
                    var inds   = transparent ? ti : oi;

                    int baseIdx = verts.Count;
                    var fv = FaceVerts[face];
                    var normalVec = new Vector3(norm.X, norm.Y, norm.Z);

                    float waterDip = (transparent && face == 0) ? -0.1f : 0f;

                    for (int v = 0; v < 4; v++)
                    {
                        var vert = blockPos + fv[v];
                        if (waterDip != 0f && fv[v].Y > 0.5f)
                            vert.Y += waterDip;
                        verts.Add(vert);
                        norms.Add(normalVec);
                    }

                    // UV mapping: V is flipped so bottom of quad gets bottom
                    // of texture and top of quad gets top of texture.
                    // For side faces this puts grass stripe at the top correctly.
                    uvs.Add(new Vector2(uv.Min.X, uv.Max.Y));  // v0 (bottom-left)
                    uvs.Add(new Vector2(uv.Max.X, uv.Max.Y));  // v1 (bottom-right)
                    uvs.Add(new Vector2(uv.Max.X, uv.Min.Y));  // v2 (top-right)
                    uvs.Add(new Vector2(uv.Min.X, uv.Min.Y));  // v3 (top-left)

                    inds.Add(baseIdx);
                    inds.Add(baseIdx + 1);
                    inds.Add(baseIdx + 2);
                    inds.Add(baseIdx);
                    inds.Add(baseIdx + 2);
                    inds.Add(baseIdx + 3);

                    if (!transparent)
                    {
                        cf.Add(blockPos + fv[0]);
                        cf.Add(blockPos + fv[1]);
                        cf.Add(blockPos + fv[2]);
                        cf.Add(blockPos + fv[0]);
                        cf.Add(blockPos + fv[2]);
                        cf.Add(blockPos + fv[3]);
                    }
                }
            }

            return new MeshBuildResult
            {
                OpaqueVerts   = ov.ToArray(),
                OpaqueNormals = on.ToArray(),
                OpaqueUVs     = ou.ToArray(),
                OpaqueIndices = oi.ToArray(),
                TransVerts    = tv.ToArray(),
                TransNormals  = tn.ToArray(),
                TransUVs      = tu.ToArray(),
                TransIndices  = ti.ToArray(),
                CollisionFaces = cf.ToArray(),
            };
        }

        public static ArrayMesh CreateArrayMesh(MeshBuildResult d)
        {
            var mesh = new ArrayMesh();

            if (d.HasOpaque)
                AddSurface(mesh, d.OpaqueVerts, d.OpaqueNormals, d.OpaqueUVs, d.OpaqueIndices);

            if (d.HasTransparent)
                AddSurface(mesh, d.TransVerts, d.TransNormals, d.TransUVs, d.TransIndices);

            return mesh;
        }

        private static void AddSurface(ArrayMesh mesh, Vector3[] v, Vector3[] n,
                                        Vector2[] u, int[] idx)
        {
            var arrays = new Godot.Collections.Array();
            arrays.Resize((int)Mesh.ArrayType.Max);
            arrays[(int)Mesh.ArrayType.Vertex] = v;
            arrays[(int)Mesh.ArrayType.Normal] = n;
            arrays[(int)Mesh.ArrayType.TexUV]  = u;
            arrays[(int)Mesh.ArrayType.Index]  = idx;
            mesh.AddSurfaceFromArrays(Mesh.PrimitiveType.Triangles, arrays);
        }

        private static byte GetNeighbor(
            ChunkData chunk, ChunkData left, ChunkData right,
            ChunkData front, ChunkData back,
            int x, int y, int z)
        {
            if (y < 0 || y >= ChunkData.Height)
                return (byte)BlockID.Air;

            if (x >= 0 && x < ChunkData.Width && z >= 0 && z < ChunkData.Depth)
                return chunk.GetBlock(x, y, z);

            // For missing neighbors, return Air so boundary faces always render.
            // Slightly wasteful (hidden faces behind loaded neighbors) but no holes.
            if (x < 0)
                return left?.GetBlock(x + ChunkData.Width, y, z) ?? (byte)BlockID.Air;
            if (x >= ChunkData.Width)
                return right?.GetBlock(x - ChunkData.Width, y, z) ?? (byte)BlockID.Air;
            if (z >= ChunkData.Depth)
                return front?.GetBlock(x, y, z - ChunkData.Depth) ?? (byte)BlockID.Air;
            if (z < 0)
                return back?.GetBlock(x, y, z + ChunkData.Depth) ?? (byte)BlockID.Air;

            return (byte)BlockID.Air;
        }
    }
}
