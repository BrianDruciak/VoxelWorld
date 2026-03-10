using Godot;

namespace VoxelEngine
{
    public partial class ChunkNode : Node3D
    {
        public ChunkData Data { get; private set; }
        public Vector2I ChunkPosition { get; private set; }
        public bool IsReady { get; private set; }

        private MeshInstance3D _meshInstance;
        private StaticBody3D _body;
        private CollisionShape3D _collision;
        private Material _opaqueMat;
        private Material _transMat;

        public void Initialize(ChunkData data, Vector2I pos)
        {
            Data = data;
            ChunkPosition = pos;
            Position = new Vector3(pos.X * ChunkData.Width, 0, pos.Y * ChunkData.Depth);

            _meshInstance = new MeshInstance3D();
            AddChild(_meshInstance);

            _body = new StaticBody3D();
            AddChild(_body);

            _collision = new CollisionShape3D();
            _body.AddChild(_collision);
        }

        public void ApplyMesh(ArrayMesh mesh, Vector3[] collisionFaces,
                              Material opaqueMat, Material transMat)
        {
            _opaqueMat = opaqueMat;
            _transMat = transMat;

            _meshInstance.Mesh = mesh;

            if (mesh.GetSurfaceCount() > 0)
                _meshInstance.SetSurfaceOverrideMaterial(0, opaqueMat);
            if (mesh.GetSurfaceCount() > 1)
                _meshInstance.SetSurfaceOverrideMaterial(1, transMat);

            if (collisionFaces != null && collisionFaces.Length >= 3)
            {
                var shape = new ConcavePolygonShape3D();
                shape.Data = collisionFaces;
                _collision.Shape = shape;
            }

            IsReady = true;
        }

        public void RebuildMesh(ChunkData left, ChunkData right,
                                ChunkData front, ChunkData back)
        {
            var meshData = ChunkMesher.BuildMeshData(Data, left, right, front, back);
            var mesh = ChunkMesher.CreateArrayMesh(meshData);
            ApplyMesh(mesh, meshData.CollisionFaces, _opaqueMat, _transMat);
        }
    }
}
