using Godot;

namespace VoxelEngine
{
    public enum BlockID : byte
    {
        Air = 0,
        Stone = 1,
        Dirt = 2,
        Grass = 3,
        Sand = 4,
        Water = 5,
        Snow = 6,
        Ice = 7,
        DarkGrass = 8,
        DarkDirt = 9,
        Basalt = 10,
        Obsidian = 11,
        Lava = 12,
        Ash = 13,
        WildCrystal = 14,
        Frostite = 15,
        Embersite = 16,
        VoidShard = 17,
        CopperOre = 18,
        IronOre = 19,
        Thornite = 20,
        GlacialGem = 21,
        MagmaCore = 22,
        Count = 23
    }

    public struct BlockFaceUV
    {
        public Vector2 Min;
        public Vector2 Max;

        public BlockFaceUV(Vector2 min, Vector2 max)
        {
            Min = min;
            Max = max;
        }
    }

    public struct BlockProperties
    {
        public bool IsSolid;
        public bool IsTransparent;
        public bool IsLiquid;
        public BlockFaceUV TopUV;
        public BlockFaceUV SideUV;
        public BlockFaceUV BottomUV;
    }

    public static class BlockTypes
    {
        // Tile indices in atlas:
        //  0 stone, 1 dirt, 2 grass_top, 3 grass_side,
        //  4 sand, 5 water, 6 snow, 7 ice,
        //  8 darkgrass_top, 9 darkgrass_side, 10 darkdirt,
        //  11 basalt, 12 obsidian, 13 lava, 14 ash,
        //  15 wildcrystal, 16 frostite, 17 embersite, 18 voidshard
        //  19 copperore, 20 ironore, 21 thornite, 22 glacialgem, 23 magmacore
        public const int TileCount = 24;
        private static readonly BlockProperties[] _props = new BlockProperties[((int)BlockID.Count)];

        static BlockTypes()
        {
            float s = 1.0f / TileCount;

            _props[(int)BlockID.Air] = new BlockProperties { IsSolid = false, IsTransparent = true };

            var stoneUV = T(0, s);
            _props[(int)BlockID.Stone] = Solid(stoneUV, stoneUV, stoneUV);

            var dirtUV = T(1, s);
            _props[(int)BlockID.Dirt] = Solid(dirtUV, dirtUV, dirtUV);

            _props[(int)BlockID.Grass] = Solid(T(2, s), T(3, s), dirtUV);

            var sandUV = T(4, s);
            _props[(int)BlockID.Sand] = Solid(sandUV, sandUV, sandUV);

            var waterUV = T(5, s);
            _props[(int)BlockID.Water] = new BlockProperties
            {
                IsSolid = false, IsTransparent = true, IsLiquid = true,
                TopUV = waterUV, SideUV = waterUV, BottomUV = waterUV
            };

            var snowUV = T(6, s);
            _props[(int)BlockID.Snow] = Solid(snowUV, snowUV, snowUV);

            var iceUV = T(7, s);
            _props[(int)BlockID.Ice] = new BlockProperties
            {
                IsSolid = true, IsTransparent = true,
                TopUV = iceUV, SideUV = iceUV, BottomUV = iceUV
            };

            var dDirtUV = T(10, s);
            _props[(int)BlockID.DarkGrass] = Solid(T(8, s), T(9, s), dDirtUV);

            _props[(int)BlockID.DarkDirt] = Solid(dDirtUV, dDirtUV, dDirtUV);

            var basaltUV = T(11, s);
            _props[(int)BlockID.Basalt] = Solid(basaltUV, basaltUV, basaltUV);

            var obsidianUV = T(12, s);
            _props[(int)BlockID.Obsidian] = Solid(obsidianUV, obsidianUV, obsidianUV);

            var lavaUV = T(13, s);
            _props[(int)BlockID.Lava] = new BlockProperties
            {
                IsSolid = false, IsTransparent = true, IsLiquid = true,
                TopUV = lavaUV, SideUV = lavaUV, BottomUV = lavaUV
            };

            var ashUV = T(14, s);
            _props[(int)BlockID.Ash] = Solid(ashUV, ashUV, ashUV);

            var wildCrystalUV = T(15, s);
            _props[(int)BlockID.WildCrystal] = Solid(wildCrystalUV, wildCrystalUV, wildCrystalUV);

            var frostiteUV = T(16, s);
            _props[(int)BlockID.Frostite] = Solid(frostiteUV, frostiteUV, frostiteUV);

            var embersiteUV = T(17, s);
            _props[(int)BlockID.Embersite] = Solid(embersiteUV, embersiteUV, embersiteUV);

            var voidShardUV = T(18, s);
            _props[(int)BlockID.VoidShard] = Solid(voidShardUV, voidShardUV, voidShardUV);

            var copperOreUV = T(19, s);
            _props[(int)BlockID.CopperOre] = Solid(copperOreUV, copperOreUV, copperOreUV);

            var ironOreUV = T(20, s);
            _props[(int)BlockID.IronOre] = Solid(ironOreUV, ironOreUV, ironOreUV);

            var thorniteUV = T(21, s);
            _props[(int)BlockID.Thornite] = Solid(thorniteUV, thorniteUV, thorniteUV);

            var glacialGemUV = T(22, s);
            _props[(int)BlockID.GlacialGem] = Solid(glacialGemUV, glacialGemUV, glacialGemUV);

            var magmaCoreUV = T(23, s);
            _props[(int)BlockID.MagmaCore] = Solid(magmaCoreUV, magmaCoreUV, magmaCoreUV);
        }

        private static BlockFaceUV T(int i, float s)
        {
            const float pixelSize = 1.0f / (TileCount * 16);
            float pad = pixelSize * 0.5f;
            const float vPad = 0.5f / 16f;
            return new(
                new Vector2(i * s + pad, vPad),
                new Vector2((i + 1) * s - pad, 1f - vPad));
        }

        private static BlockProperties Solid(BlockFaceUV top, BlockFaceUV side, BlockFaceUV bot)
            => new() { IsSolid = true, IsTransparent = false, TopUV = top, SideUV = side, BottomUV = bot };

        public static BlockProperties Get(byte id) => _props[id];
        public static bool IsSolid(byte id) => _props[id].IsSolid;
        public static bool IsTransparent(byte id) => _props[id].IsTransparent;

        public static readonly string[] Names =
        {
            "Air", "Stone", "Dirt", "Grass", "Sand", "Water",
            "Snow", "Ice", "DarkGrass", "DarkDirt", "Basalt",
            "Obsidian", "Lava", "Ash",
            "WildCrystal", "Frostite", "Embersite", "VoidShard",
            "CopperOre", "IronOre", "Thornite", "GlacialGem", "MagmaCore"
        };
    }
}
