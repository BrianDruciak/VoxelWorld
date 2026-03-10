namespace VoxelEngine
{
    public class ChunkData
    {
        public const int Width = 16;
        public const int Height = 256;
        public const int Depth = 16;
        public const int Volume = Width * Height * Depth;

        private readonly byte[] _blocks = new byte[Volume];

        public int ChunkX { get; }
        public int ChunkZ { get; }

        public ChunkData(int chunkX, int chunkZ)
        {
            ChunkX = chunkX;
            ChunkZ = chunkZ;
        }

        private static int Index(int x, int y, int z)
        {
            return (y * Depth + z) * Width + x;
        }

        public byte GetBlock(int x, int y, int z)
        {
            if (x < 0 || x >= Width || y < 0 || y >= Height || z < 0 || z >= Depth)
                return (byte)BlockID.Air;
            return _blocks[Index(x, y, z)];
        }

        public void SetBlock(int x, int y, int z, byte blockId)
        {
            if (x < 0 || x >= Width || y < 0 || y >= Height || z < 0 || z >= Depth)
                return;
            _blocks[Index(x, y, z)] = blockId;
        }

        public void SetBlock(int x, int y, int z, BlockID blockId)
        {
            SetBlock(x, y, z, (byte)blockId);
        }
    }
}
