using Godot;

namespace VoxelEngine
{
    public class NoiseGenerator
    {
        private readonly FastNoiseLite _noise;

        public NoiseGenerator(int seed, float frequency = 0.01f, int octaves = 4)
        {
            _noise = new FastNoiseLite();
            _noise.Seed = seed;
            _noise.Frequency = frequency;
            _noise.NoiseType = FastNoiseLite.NoiseTypeEnum.SimplexSmooth;
            _noise.FractalType = FastNoiseLite.FractalTypeEnum.Fbm;
            _noise.FractalOctaves = octaves;
        }

        public float Sample2D(float x, float z)
        {
            return _noise.GetNoise2D(x, z);
        }

        public float Sample3D(float x, float y, float z)
        {
            return _noise.GetNoise3D(x, y, z);
        }
    }
}
