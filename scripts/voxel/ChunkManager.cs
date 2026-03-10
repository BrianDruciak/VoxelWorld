using Godot;
using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;

namespace VoxelEngine
{
    public partial class ChunkManager : Node3D
    {
        [Export] public int RenderDistance { get; set; } = 8;
        [Export] public int WorldSeed { get; set; } = 12345;

        private WorldGenerator _worldGen;
        private readonly Dictionary<Vector2I, ChunkNode> _chunks = new();
        private readonly ConcurrentDictionary<Vector2I, ChunkData> _dataCache = new();
        private readonly HashSet<Vector2I> _generating = new();

        private readonly ConcurrentQueue<ChunkJob> _ready = new();

        private Vector2I _lastPlayerChunk = new(int.MaxValue, int.MaxValue);
        private StandardMaterial3D _opaqueMat;
        private StandardMaterial3D _transMat;
        private CancellationTokenSource _cts;
        private int _retryClock;

        [ThreadStatic] private static WorldGenerator _threadGen;
        [ThreadStatic] private static int _threadSeed;

        public int GetLoadedChunkCount() => _chunks.Count;
        public int GetPendingChunkCount() => _generating.Count;

        private struct ChunkJob
        {
            public Vector2I Pos;
            public ChunkData Data;
            public MeshBuildResult Mesh;
        }

        public override void _Ready()
        {
            _worldGen = new WorldGenerator(WorldSeed);
            _cts = new CancellationTokenSource();
            BuildMaterials();
        }

        private void BuildMaterials()
        {
            var tex = TextureGenerator.GenerateAtlas();

            _opaqueMat = new StandardMaterial3D
            {
                AlbedoTexture = tex,
                TextureFilter = BaseMaterial3D.TextureFilterEnum.Nearest,
                SpecularMode = BaseMaterial3D.SpecularModeEnum.Disabled,
            };

            _transMat = new StandardMaterial3D
            {
                AlbedoTexture = tex,
                TextureFilter = BaseMaterial3D.TextureFilterEnum.Nearest,
                Transparency = BaseMaterial3D.TransparencyEnum.Alpha,
                AlbedoColor = new Color(1, 1, 1, 0.7f),
                SpecularMode = BaseMaterial3D.SpecularModeEnum.Disabled,
            };
        }

        // ------------------------------------------------------------------
        // Synchronously generate a 3x3 patch so the player has ground
        // ------------------------------------------------------------------

        public void GenerateInitialChunks(Vector3 spawnPos)
        {
            var center = new Vector2I(
                Mathf.FloorToInt(spawnPos.X / ChunkData.Width),
                Mathf.FloorToInt(spawnPos.Z / ChunkData.Depth));

            for (int dx = -1; dx <= 1; dx++)
            for (int dz = -1; dz <= 1; dz++)
            {
                var pos = new Vector2I(center.X + dx, center.Y + dz);
                var data = _worldGen.GenerateChunk(pos.X, pos.Y);
                _dataCache[pos] = data;
            }

            for (int dx = -1; dx <= 1; dx++)
            for (int dz = -1; dz <= 1; dz++)
            {
                var pos = new Vector2I(center.X + dx, center.Y + dz);
                var data = _dataCache[pos];

                _dataCache.TryGetValue(new Vector2I(pos.X - 1, pos.Y), out var left);
                _dataCache.TryGetValue(new Vector2I(pos.X + 1, pos.Y), out var right);
                _dataCache.TryGetValue(new Vector2I(pos.X, pos.Y + 1), out var front);
                _dataCache.TryGetValue(new Vector2I(pos.X, pos.Y - 1), out var back);

                var meshData = ChunkMesher.BuildMeshData(data, left, right, front, back);
                var arrayMesh = ChunkMesher.CreateArrayMesh(meshData);

                var node = new ChunkNode();
                node.Initialize(data, pos);
                node.ApplyMesh(arrayMesh, meshData.CollisionFaces, _opaqueMat, _transMat);
                AddChild(node);
                _chunks[pos] = node;
            }
        }

        // ------------------------------------------------------------------
        // Called every frame by GameManager.gd
        // ------------------------------------------------------------------

        public void UpdatePlayerPosition(Vector3 pos)
        {
            var pc = new Vector2I(
                Mathf.FloorToInt(pos.X / ChunkData.Width),
                Mathf.FloorToInt(pos.Z / ChunkData.Depth));

            if (pc == _lastPlayerChunk) return;
            _lastPlayerChunk = pc;

            QueueChunks(pc);
            UnloadDistant(pc);
        }

        // ------------------------------------------------------------------
        // Block modification (called from GDScript via world coords)
        // ------------------------------------------------------------------

        public byte GetBlockWorld(int wx, int wy, int wz)
        {
            var cp = new Vector2I(
                Mathf.FloorToInt((float)wx / ChunkData.Width),
                Mathf.FloorToInt((float)wz / ChunkData.Depth));

            if (!_chunks.TryGetValue(cp, out var node))
                return (byte)BlockID.Air;

            int lx = ((wx % ChunkData.Width) + ChunkData.Width) % ChunkData.Width;
            int lz = ((wz % ChunkData.Depth) + ChunkData.Depth) % ChunkData.Depth;
            return node.Data.GetBlock(lx, wy, lz);
        }

        public bool SetBlockWorld(int wx, int wy, int wz, byte blockId)
        {
            var cp = new Vector2I(
                Mathf.FloorToInt((float)wx / ChunkData.Width),
                Mathf.FloorToInt((float)wz / ChunkData.Depth));

            if (!_chunks.TryGetValue(cp, out var node))
                return false;

            int lx = ((wx % ChunkData.Width) + ChunkData.Width) % ChunkData.Width;
            int lz = ((wz % ChunkData.Depth) + ChunkData.Depth) % ChunkData.Depth;

            node.Data.SetBlock(lx, wy, lz, blockId);
            _dataCache[cp] = node.Data;

            RebuildChunk(cp);

            if (lx == 0) RebuildChunkIfLoaded(new Vector2I(cp.X - 1, cp.Y));
            if (lx == ChunkData.Width - 1) RebuildChunkIfLoaded(new Vector2I(cp.X + 1, cp.Y));
            if (lz == 0) RebuildChunkIfLoaded(new Vector2I(cp.X, cp.Y - 1));
            if (lz == ChunkData.Depth - 1) RebuildChunkIfLoaded(new Vector2I(cp.X, cp.Y + 1));

            return true;
        }

        private void RebuildChunk(Vector2I cp)
        {
            if (!_chunks.TryGetValue(cp, out var node)) return;

            _dataCache.TryGetValue(new Vector2I(cp.X - 1, cp.Y), out var left);
            _dataCache.TryGetValue(new Vector2I(cp.X + 1, cp.Y), out var right);
            _dataCache.TryGetValue(new Vector2I(cp.X, cp.Y + 1), out var front);
            _dataCache.TryGetValue(new Vector2I(cp.X, cp.Y - 1), out var back);

            node.RebuildMesh(left, right, front, back);
        }

        private void RebuildChunkIfLoaded(Vector2I cp)
        {
            if (_chunks.ContainsKey(cp))
                RebuildChunk(cp);
        }

        // ------------------------------------------------------------------
        // Loading
        // ------------------------------------------------------------------

        private void QueueChunk(Vector2I pos)
        {
            _generating.Add(pos);
            var token = _cts.Token;
            var p = pos;
            var seed = WorldSeed;
            Task.Run(() => GenerateAsync(p, seed, token), token);
        }

        private void QueueChunks(Vector2I center)
        {
            var list = SpiralPositions(center, RenderDistance);
            foreach (var p in list)
            {
                if (_chunks.ContainsKey(p) || _generating.Contains(p))
                    continue;
                QueueChunk(p);
            }
        }

        private void GenerateAsync(Vector2I pos, int seed, CancellationToken ct)
        {
            try
            {
                if (ct.IsCancellationRequested) return;

                if (_threadGen == null || _threadSeed != seed)
                {
                    _threadGen = new WorldGenerator(seed);
                    _threadSeed = seed;
                }

                var data = _threadGen.GenerateChunk(pos.X, pos.Y);
                _dataCache[pos] = data;

                if (ct.IsCancellationRequested) return;

                _dataCache.TryGetValue(new Vector2I(pos.X - 1, pos.Y), out var left);
                _dataCache.TryGetValue(new Vector2I(pos.X + 1, pos.Y), out var right);
                _dataCache.TryGetValue(new Vector2I(pos.X, pos.Y + 1), out var front);
                _dataCache.TryGetValue(new Vector2I(pos.X, pos.Y - 1), out var back);

                var meshData = ChunkMesher.BuildMeshData(data, left, right, front, back);

                _ready.Enqueue(new ChunkJob { Pos = pos, Data = data, Mesh = meshData });
            }
            catch (Exception)
            {
                _ready.Enqueue(new ChunkJob { Pos = pos, Data = null, Mesh = null });
            }
        }

        // ------------------------------------------------------------------
        // Main-thread: create Godot objects from finished jobs + retry scan
        // ------------------------------------------------------------------

        public override void _Process(double delta)
        {
            int added = 0;
            while (_ready.TryDequeue(out var job) && added < 8)
            {
                _generating.Remove(job.Pos);

                if (job.Data == null || job.Mesh == null)
                    continue;

                if (_chunks.ContainsKey(job.Pos))
                    continue;

                var mesh = ChunkMesher.CreateArrayMesh(job.Mesh);
                var node = new ChunkNode();
                node.Initialize(job.Data, job.Pos);
                node.ApplyMesh(mesh, job.Mesh.CollisionFaces, _opaqueMat, _transMat);
                AddChild(node);
                _chunks[job.Pos] = node;
                added++;
            }

            RetryMissingChunks();
        }

        private void RetryMissingChunks()
        {
            _retryClock++;
            if (_retryClock < 90) return;
            _retryClock = 0;

            if (_lastPlayerChunk.X == int.MaxValue) return;

            int queued = 0;
            for (int dx = -RenderDistance; dx <= RenderDistance; dx++)
            for (int dz = -RenderDistance; dz <= RenderDistance; dz++)
            {
                var pos = new Vector2I(_lastPlayerChunk.X + dx, _lastPlayerChunk.Y + dz);

                if (_chunks.ContainsKey(pos))
                    continue;

                _generating.Remove(pos);
                QueueChunk(pos);
                queued++;
            }

            if (queued > 0)
                GD.Print($"[ChunkManager] Retry: re-queued {queued} missing chunks");
        }

        // ------------------------------------------------------------------
        // Unloading
        // ------------------------------------------------------------------

        private void UnloadDistant(Vector2I center)
        {
            int limit = RenderDistance + 2;
            var remove = new List<Vector2I>();

            foreach (var kv in _chunks)
            {
                int dx = Mathf.Abs(kv.Key.X - center.X);
                int dz = Mathf.Abs(kv.Key.Y - center.Y);
                if (dx > limit || dz > limit)
                    remove.Add(kv.Key);
            }

            foreach (var p in remove)
            {
                _chunks[p].QueueFree();
                _chunks.Remove(p);
                _dataCache.TryRemove(p, out _);
            }
        }

        // ------------------------------------------------------------------
        // Helpers exposed to GDScript (main thread only)
        // ------------------------------------------------------------------

        public int GetHeightAt(float worldX, float worldZ)
            => _worldGen.GetHeightAt(worldX, worldZ);

        public string GetBiomeNameAt(float worldX, float worldZ)
            => _worldGen.GetBiomeAt(worldX, worldZ).ToString();

        // ------------------------------------------------------------------
        // Spiral sort: closest chunks first
        // ------------------------------------------------------------------

        private static List<Vector2I> SpiralPositions(Vector2I center, int radius)
        {
            var list = new List<Vector2I>((2 * radius + 1) * (2 * radius + 1));
            for (int dx = -radius; dx <= radius; dx++)
            for (int dz = -radius; dz <= radius; dz++)
                list.Add(new Vector2I(center.X + dx, center.Y + dz));

            list.Sort((a, b) =>
            {
                float da = (a - center).LengthSquared();
                float db = (b - center).LengthSquared();
                return da.CompareTo(db);
            });
            return list;
        }

        public override void _ExitTree()
        {
            _cts?.Cancel();
            _cts?.Dispose();
        }
    }
}
