using Godot;

namespace VoxelEngine
{
    public enum BiomeType
    {
        Plains,
        Desert,
        Mountains,
        DarkForest,
        FrozenWastes,
        IcePeaks,
        ScorchedLands,
        LavaFields,
        TheVoid
    }

    public struct BiomeData
    {
        public BiomeType Type;
        public float BaseHeight;
        public float HeightAmplitude;
        public float NoiseFreqMult;
        public BlockID SurfaceBlock;
        public BlockID SubSurfaceBlock;
        public int SubSurfaceDepth;
        public BlockID SeaBlock;
        public int SeaLevel;
    }

    public class BiomeManager
    {
        private readonly NoiseGenerator _varNoise;

        const float Zone1End = 128;
        const float Zone2End = 320;
        const float Zone3End = 560;
        const float Zone4End = 800;
        const float BlendWidth = 64;

        // --- Safe Haven sub-biomes ---
        private static readonly BiomeData Plains = new()
        {
            Type = BiomeType.Plains, BaseHeight = 68, HeightAmplitude = 8,
            NoiseFreqMult = 1f,
            SurfaceBlock = BlockID.Grass, SubSurfaceBlock = BlockID.Dirt,
            SubSurfaceDepth = 4, SeaBlock = BlockID.Water, SeaLevel = 64
        };
        private static readonly BiomeData Desert = new()
        {
            Type = BiomeType.Desert, BaseHeight = 66, HeightAmplitude = 6,
            NoiseFreqMult = 1f,
            SurfaceBlock = BlockID.Sand, SubSurfaceBlock = BlockID.Sand,
            SubSurfaceDepth = 5, SeaBlock = BlockID.Water, SeaLevel = 64
        };
        private static readonly BiomeData SafeMountains = new()
        {
            Type = BiomeType.Mountains, BaseHeight = 78, HeightAmplitude = 20,
            NoiseFreqMult = 1f,
            SurfaceBlock = BlockID.Stone, SubSurfaceBlock = BlockID.Stone,
            SubSurfaceDepth = 1, SeaBlock = BlockID.Water, SeaLevel = 64
        };

        // --- Wilderness ---
        private static readonly BiomeData DarkForest = new()
        {
            Type = BiomeType.DarkForest, BaseHeight = 70, HeightAmplitude = 15,
            NoiseFreqMult = 1.5f,
            SurfaceBlock = BlockID.DarkGrass, SubSurfaceBlock = BlockID.DarkDirt,
            SubSurfaceDepth = 4, SeaBlock = BlockID.Water, SeaLevel = 64
        };
        private static readonly BiomeData DarkMountains = new()
        {
            Type = BiomeType.Mountains, BaseHeight = 82, HeightAmplitude = 30,
            NoiseFreqMult = 1.5f,
            SurfaceBlock = BlockID.Stone, SubSurfaceBlock = BlockID.DarkDirt,
            SubSurfaceDepth = 3, SeaBlock = BlockID.Water, SeaLevel = 64
        };

        // --- Frozen Wastes ---
        private static readonly BiomeData FrozenPlains = new()
        {
            Type = BiomeType.FrozenWastes, BaseHeight = 72, HeightAmplitude = 12,
            NoiseFreqMult = 2f,
            SurfaceBlock = BlockID.Snow, SubSurfaceBlock = BlockID.Ice,
            SubSurfaceDepth = 3, SeaBlock = BlockID.Ice, SeaLevel = 64
        };
        private static readonly BiomeData IcePeaks = new()
        {
            Type = BiomeType.IcePeaks, BaseHeight = 90, HeightAmplitude = 50,
            NoiseFreqMult = 2f,
            SurfaceBlock = BlockID.Snow, SubSurfaceBlock = BlockID.Stone,
            SubSurfaceDepth = 2, SeaBlock = BlockID.Ice, SeaLevel = 64
        };

        // --- Scorched Lands ---
        private static readonly BiomeData ScorchedFlats = new()
        {
            Type = BiomeType.ScorchedLands, BaseHeight = 60, HeightAmplitude = 20,
            NoiseFreqMult = 2.5f,
            SurfaceBlock = BlockID.Basalt, SubSurfaceBlock = BlockID.Obsidian,
            SubSurfaceDepth = 3, SeaBlock = BlockID.Lava, SeaLevel = 58
        };
        private static readonly BiomeData LavaFields = new()
        {
            Type = BiomeType.LavaFields, BaseHeight = 50, HeightAmplitude = 35,
            NoiseFreqMult = 2.5f,
            SurfaceBlock = BlockID.Ash, SubSurfaceBlock = BlockID.Basalt,
            SubSurfaceDepth = 4, SeaBlock = BlockID.Lava, SeaLevel = 62
        };

        // --- The Void ---
        private static readonly BiomeData Void = new()
        {
            Type = BiomeType.TheVoid, BaseHeight = 40, HeightAmplitude = 80,
            NoiseFreqMult = 3f,
            SurfaceBlock = BlockID.Obsidian, SubSurfaceBlock = BlockID.Basalt,
            SubSurfaceDepth = 2, SeaBlock = BlockID.Lava, SeaLevel = 30
        };

        public BiomeManager(int seed)
        {
            _varNoise = new NoiseGenerator(seed + 1000, 0.006f, 3);
        }

        public BiomeData GetBiome(float worldX, float worldZ)
        {
            float dist = Mathf.Sqrt(worldX * worldX + worldZ * worldZ);
            float v = _varNoise.Sample2D(worldX, worldZ);

            if (dist < Zone1End) return PickSafe(v);
            if (dist < Zone2End) return PickWild(v);
            if (dist < Zone3End) return PickFrozen(v);
            if (dist < Zone4End) return PickScorched(v);
            return Void;
        }

        public (float height, BiomeData biome) GetBlendedHeight(
            float worldX, float worldZ, float terrainNoise)
        {
            float dist = Mathf.Sqrt(worldX * worldX + worldZ * worldZ);
            float v = _varNoise.Sample2D(worldX, worldZ);

            // Get smoothly blended height params from each relevant zone
            var (safeH, safeA, safeSea, safeB) = BlendSafe(v);
            var (wildH, wildA, wildSea, wildB) = BlendWild(v);
            var (frozenH, frozenA, frozenSea, frozenB) = BlendFrozen(v);
            var (scorchH, scorchA, scorchSea, scorchB) = BlendScorched(v);
            float voidH = Void.BaseHeight;
            float voidA = Void.HeightAmplitude;

            // Zone weights based on distance (smooth transitions)
            float w1 = ZoneWeight(dist, 0, Zone1End);
            float w2 = ZoneWeight(dist, Zone1End, Zone2End);
            float w3 = ZoneWeight(dist, Zone2End, Zone3End);
            float w4 = ZoneWeight(dist, Zone3End, Zone4End);
            float w5 = ZoneWeight(dist, Zone4End, Zone4End + 400);

            // Normalize weights
            float total = w1 + w2 + w3 + w4 + w5;
            if (total > 0)
            {
                w1 /= total; w2 /= total; w3 /= total; w4 /= total; w5 /= total;
            }

            float baseH = safeH * w1 + wildH * w2 + frozenH * w3 + scorchH * w4 + voidH * w5;
            float amp = safeA * w1 + wildA * w2 + frozenA * w3 + scorchA * w4 + voidA * w5;

            float height = baseH + terrainNoise * amp;

            // Pick dominant biome for surface block selection
            BiomeData primary;
            float maxW = w1;
            primary = safeB;
            if (w2 > maxW) { maxW = w2; primary = wildB; }
            if (w3 > maxW) { maxW = w3; primary = frozenB; }
            if (w4 > maxW) { maxW = w4; primary = scorchB; }
            if (w5 > maxW) { primary = Void; }

            // Blend sea level too
            int seaLvl = Mathf.RoundToInt(
                safeSea * w1 + wildSea * w2 + frozenSea * w3 + scorchSea * w4 + Void.SeaLevel * w5);
            primary.SeaLevel = seaLvl;

            return (height, primary);
        }

        // Zone weight: bell-shaped contribution centered in each zone
        private static float ZoneWeight(float dist, float start, float end)
        {
            float center = (start + end) * 0.5f;
            float halfWidth = (end - start) * 0.5f + BlendWidth;
            float d = Mathf.Abs(dist - center) / halfWidth;
            if (d >= 1f) return 0f;
            float t = 1f - d;
            return t * t;
        }

        // Smooth blend between sub-biomes within each zone
        private static (float baseH, float amp, float seaLvl, BiomeData primary) BlendSafe(float v)
        {
            float dw = Smooth01((v - 0.05f) / 0.3f);
            float mw = Smooth01((-v - 0.05f) / 0.3f);
            float pw = Mathf.Max(1f - dw - mw, 0f);

            float baseH = Plains.BaseHeight * pw + Desert.BaseHeight * dw + SafeMountains.BaseHeight * mw;
            float amp = Plains.HeightAmplitude * pw + Desert.HeightAmplitude * dw + SafeMountains.HeightAmplitude * mw;
            float sea = Plains.SeaLevel * pw + Desert.SeaLevel * dw + SafeMountains.SeaLevel * mw;

            BiomeData p = Plains;
            if (dw > pw && dw > mw) p = Desert;
            else if (mw > pw) p = SafeMountains;

            return (baseH, amp, sea, p);
        }

        private static (float baseH, float amp, float seaLvl, BiomeData primary) BlendWild(float v)
        {
            float mw = Smooth01((-v) / 0.4f);
            float fw = 1f - mw;

            float baseH = DarkForest.BaseHeight * fw + DarkMountains.BaseHeight * mw;
            float amp = DarkForest.HeightAmplitude * fw + DarkMountains.HeightAmplitude * mw;
            float sea = DarkForest.SeaLevel * fw + DarkMountains.SeaLevel * mw;

            return (baseH, amp, sea, mw > 0.5f ? DarkMountains : DarkForest);
        }

        private static (float baseH, float amp, float seaLvl, BiomeData primary) BlendFrozen(float v)
        {
            float pw = Smooth01((-v + 0.1f) / 0.4f);
            float fw = 1f - pw;

            float baseH = FrozenPlains.BaseHeight * fw + IcePeaks.BaseHeight * pw;
            float amp = FrozenPlains.HeightAmplitude * fw + IcePeaks.HeightAmplitude * pw;
            float sea = FrozenPlains.SeaLevel * fw + IcePeaks.SeaLevel * pw;

            return (baseH, amp, sea, pw > 0.5f ? IcePeaks : FrozenPlains);
        }

        private static (float baseH, float amp, float seaLvl, BiomeData primary) BlendScorched(float v)
        {
            float lw = Smooth01((-v) / 0.4f);
            float sw = 1f - lw;

            float baseH = ScorchedFlats.BaseHeight * sw + LavaFields.BaseHeight * lw;
            float amp = ScorchedFlats.HeightAmplitude * sw + LavaFields.HeightAmplitude * lw;
            float sea = ScorchedFlats.SeaLevel * sw + LavaFields.SeaLevel * lw;

            return (baseH, amp, sea, lw > 0.5f ? LavaFields : ScorchedFlats);
        }

        private static BiomeData PickSafe(float v)
        {
            if (v > 0.2f) return Desert;
            if (v < -0.2f) return SafeMountains;
            return Plains;
        }

        private static BiomeData PickWild(float v)
            => v < 0f ? DarkMountains : DarkForest;

        private static BiomeData PickFrozen(float v)
            => v < -0.1f ? IcePeaks : FrozenPlains;

        private static BiomeData PickScorched(float v)
            => v < 0f ? LavaFields : ScorchedFlats;

        private static float Smooth01(float x)
        {
            x = Mathf.Clamp(x, 0f, 1f);
            return x * x * (3f - 2f * x);
        }
    }
}
