using Godot;

namespace VoxelEngine
{
    public class WorldGenerator
    {
        private readonly int _seed;
        private readonly NoiseGenerator _terrainNoise;
        private readonly NoiseGenerator _roughnessNoise;
        private readonly BiomeManager _biomeManager;
        private readonly NoiseGenerator _oreNoise;
        private readonly NoiseGenerator _oreNoise2;

        private const float OreZoneSafeEnd = 128f;
        private const float OreZoneWildEnd = 320f;
        private const float OreZoneFrozenEnd = 560f;
        private const float OreZoneScorchedEnd = 800f;

        public WorldGenerator(int seed)
        {
            _seed = seed;
            _terrainNoise = new NoiseGenerator(seed, 0.008f, 5);
            _roughnessNoise = new NoiseGenerator(seed + 500, 0.015f, 3);
            _biomeManager = new BiomeManager(seed);
            _oreNoise = new NoiseGenerator(seed + 2000, 0.12f, 2);
            _oreNoise2 = new NoiseGenerator(seed + 3000, 0.09f, 2);
        }

        public ChunkData GenerateChunk(int chunkX, int chunkZ)
        {
            var chunk = new ChunkData(chunkX, chunkZ);

            for (int x = 0; x < ChunkData.Width; x++)
            for (int z = 0; z < ChunkData.Depth; z++)
            {
                float wx = chunkX * ChunkData.Width + x;
                float wz = chunkZ * ChunkData.Depth + z;

                float dist = Mathf.Sqrt(wx * wx + wz * wz);

                float baseNoise = _terrainNoise.Sample2D(wx, wz);
                float roughness = _roughnessNoise.Sample2D(wx, wz);

                float distFactor = Mathf.Clamp(dist / 800f, 0f, 1f);
                float combinedNoise = baseNoise + roughness * distFactor * 0.5f;

                var (height, biome) = _biomeManager.GetBlendedHeight(wx, wz, combinedNoise);
                int colHeight = Mathf.Clamp(Mathf.RoundToInt(height), 1, ChunkData.Height - 1);

                int seaLvl = biome.SeaLevel;

                for (int y = 0; y < ChunkData.Height; y++)
                {
                    BlockID block;

                    if (y == 0)
                        block = BlockID.Stone;
                    else if (y < colHeight - biome.SubSurfaceDepth)
                        block = BlockID.Stone;
                    else if (y < colHeight)
                        block = biome.SubSurfaceBlock;
                    else if (y == colHeight)
                        block = biome.SurfaceBlock;
                    else if (y <= seaLvl)
                        block = biome.SeaBlock;
                    else
                        block = BlockID.Air;

                    chunk.SetBlock(x, y, z, block);
                }
            }

            PlaceOres(chunk, chunkX, chunkZ);
            return chunk;
        }

        private void PlaceOres(ChunkData chunk, int chunkX, int chunkZ)
        {
            for (int x = 0; x < ChunkData.Width; x++)
            for (int z = 0; z < ChunkData.Depth; z++)
            {
                float wx = chunkX * ChunkData.Width + x;
                float wz = chunkZ * ChunkData.Depth + z;
                float dist = Mathf.Sqrt(wx * wx + wz * wz);

                float oreVal1 = _oreNoise.Sample2D(wx, wz);
                float oreVal2 = _oreNoise2.Sample2D(wx, wz);

                // Primary ore (noise 1)
                BlockID ore1 = BlockID.Air;
                float thresh1 = 1.0f;

                if (dist >= OreZoneScorchedEnd)
                    { ore1 = BlockID.VoidShard; thresh1 = 0.72f; }
                else if (dist >= OreZoneFrozenEnd)
                    { ore1 = BlockID.Embersite; thresh1 = 0.68f; }
                else if (dist >= OreZoneWildEnd)
                    { ore1 = BlockID.Frostite; thresh1 = 0.65f; }
                else if (dist >= OreZoneSafeEnd)
                    { ore1 = BlockID.WildCrystal; thresh1 = 0.62f; }
                else
                    { ore1 = BlockID.CopperOre; thresh1 = 0.55f; }

                // Secondary ore (noise 2) — no second ore in Void
                BlockID ore2 = BlockID.Air;
                float thresh2 = 1.0f;

                if (dist >= OreZoneScorchedEnd)
                    { /* Void: no secondary ore */ }
                else if (dist >= OreZoneFrozenEnd)
                    { ore2 = BlockID.MagmaCore; thresh2 = 0.62f; }
                else if (dist >= OreZoneWildEnd)
                    { ore2 = BlockID.GlacialGem; thresh2 = 0.60f; }
                else if (dist >= OreZoneSafeEnd)
                    { ore2 = BlockID.Thornite; thresh2 = 0.58f; }
                else
                    { ore2 = BlockID.IronOre; thresh2 = 0.60f; }

                TryPlaceOre(chunk, x, z, ore1, oreVal1, thresh1);
                TryPlaceOre(chunk, x, z, ore2, oreVal2, thresh2);
            }
        }

        private void TryPlaceOre(ChunkData chunk, int x, int z, BlockID oreType, float noiseVal, float threshold)
        {
            if (oreType == BlockID.Air || noiseVal < threshold)
                return;

            for (int checkY = ChunkData.Height - 1; checkY > 1; checkY--)
            {
                byte block = chunk.GetBlock(x, checkY, z);
                if (BlockTypes.IsSolid(block))
                {
                    int depth = Mathf.Abs((int)(noiseVal * 100) % 3);
                    int placeY = Mathf.Max(checkY - depth, 1);
                    chunk.SetBlock(x, placeY, z, oreType);
                    break;
                }
            }
        }

        public int GetHeightAt(float worldX, float worldZ)
        {
            float dist = Mathf.Sqrt(worldX * worldX + worldZ * worldZ);
            float baseNoise = _terrainNoise.Sample2D(worldX, worldZ);
            float roughness = _roughnessNoise.Sample2D(worldX, worldZ);
            float distFactor = Mathf.Clamp(dist / 800f, 0f, 1f);
            float combinedNoise = baseNoise + roughness * distFactor * 0.5f;
            var (h, _) = _biomeManager.GetBlendedHeight(worldX, worldZ, combinedNoise);
            return Mathf.RoundToInt(h);
        }

        public BiomeType GetBiomeAt(float worldX, float worldZ)
        {
            return _biomeManager.GetBiome(worldX, worldZ).Type;
        }
    }
}
