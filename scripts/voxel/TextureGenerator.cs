using Godot;

namespace VoxelEngine
{
    public static class TextureGenerator
    {
        private const int TS = 16;
        private const int TC = BlockTypes.TileCount;

        public static ImageTexture GenerateAtlas()
        {
            var img = Image.CreateEmpty(TS * TC, TS, false, Image.Format.Rgba8);

            Fill(img, 0,  new Color(0.50f, 0.50f, 0.50f));   // Stone
            Fill(img, 1,  new Color(0.55f, 0.36f, 0.20f));   // Dirt
            Fill(img, 2,  new Color(0.30f, 0.65f, 0.20f));   // Grass top
            GrassSide(img, 3, new Color(0.30f, 0.65f, 0.20f), new Color(0.55f, 0.36f, 0.20f));
            Fill(img, 4,  new Color(0.86f, 0.80f, 0.55f));   // Sand
            Fill(img, 5,  new Color(0.20f, 0.40f, 0.80f));   // Water
            Fill(img, 6,  new Color(0.92f, 0.95f, 0.97f));   // Snow
            Fill(img, 7,  new Color(0.70f, 0.85f, 0.95f));   // Ice
            Fill(img, 8,  new Color(0.15f, 0.35f, 0.10f));   // Dark grass top
            GrassSide(img, 9, new Color(0.15f, 0.35f, 0.10f), new Color(0.30f, 0.20f, 0.10f));
            Fill(img, 10, new Color(0.30f, 0.20f, 0.10f));   // Dark dirt
            Fill(img, 11, new Color(0.25f, 0.25f, 0.28f));   // Basalt
            Fill(img, 12, new Color(0.10f, 0.08f, 0.12f));   // Obsidian
            LavaTile(img, 13);                                 // Lava
            Fill(img, 14, new Color(0.40f, 0.38f, 0.35f));   // Ash
            OreTile(img, 15, new Color(0.35f, 0.20f, 0.35f), new Color(0.65f, 0.20f, 0.85f));  // WildCrystal
            OreTile(img, 16, new Color(0.30f, 0.50f, 0.55f), new Color(0.30f, 0.85f, 0.95f));  // Frostite
            OreTile(img, 17, new Color(0.40f, 0.20f, 0.10f), new Color(0.95f, 0.45f, 0.10f));  // Embersite
            OreTile(img, 18, new Color(0.08f, 0.05f, 0.10f), new Color(0.85f, 0.80f, 0.95f));  // VoidShard
            OreTile(img, 19, new Color(0.45f, 0.30f, 0.15f), new Color(0.72f, 0.45f, 0.20f));  // CopperOre
            OreTile(img, 20, new Color(0.35f, 0.35f, 0.38f), new Color(0.70f, 0.70f, 0.75f));  // IronOre
            OreTile(img, 21, new Color(0.15f, 0.30f, 0.10f), new Color(0.20f, 0.85f, 0.15f));  // Thornite
            OreTile(img, 22, new Color(0.40f, 0.55f, 0.65f), new Color(0.85f, 0.92f, 1.00f));  // GlacialGem
            OreTile(img, 23, new Color(0.40f, 0.10f, 0.05f), new Color(0.95f, 0.80f, 0.15f));  // MagmaCore

            for (int i = 0; i < TC; i++)
                Noise(img, i);

            return ImageTexture.CreateFromImage(img);
        }

        private static void Fill(Image img, int tile, Color c)
        {
            int sx = tile * TS;
            for (int x = 0; x < TS; x++)
            for (int y = 0; y < TS; y++)
                img.SetPixel(sx + x, y, c);
        }

        private static void GrassSide(Image img, int tile, Color grass, Color dirt)
        {
            int sx = tile * TS;
            for (int x = 0; x < TS; x++)
            for (int y = 0; y < TS; y++)
            {
                int depth = 3 + ((x * 7) % 3 == 0 ? 1 : 0);
                img.SetPixel(sx + x, y, y < depth ? grass : dirt);
            }
        }

        private static void LavaTile(Image img, int tile)
        {
            int sx = tile * TS;
            var rng = new RandomNumberGenerator();
            rng.Seed = 99999;
            for (int x = 0; x < TS; x++)
            for (int y = 0; y < TS; y++)
            {
                float r = rng.RandfRange(0.7f, 1.0f);
                float g = rng.RandfRange(0.15f, 0.45f);
                img.SetPixel(sx + x, y, new Color(r, g, 0.0f));
            }
        }

        private static void OreTile(Image img, int tile, Color baseColor, Color sparkle)
        {
            int sx = tile * TS;
            var rng = new RandomNumberGenerator();
            rng.Seed = (ulong)(tile * 77777 + 333);
            for (int x = 0; x < TS; x++)
            for (int y = 0; y < TS; y++)
            {
                bool isSparkle = rng.Randf() < 0.15f;
                img.SetPixel(sx + x, y, isSparkle ? sparkle : baseColor);
            }
        }

        private static void Noise(Image img, int tile)
        {
            int sx = tile * TS;
            var rng = new RandomNumberGenerator();
            rng.Seed = (ulong)(tile * 54321 + 111);
            for (int x = 0; x < TS; x++)
            for (int y = 0; y < TS; y++)
            {
                Color c = img.GetPixel(sx + x, y);
                float n = rng.RandfRange(-0.05f, 0.05f);
                c.R = Mathf.Clamp(c.R + n, 0, 1);
                c.G = Mathf.Clamp(c.G + n, 0, 1);
                c.B = Mathf.Clamp(c.B + n, 0, 1);
                img.SetPixel(sx + x, y, c);
            }
        }
    }
}
