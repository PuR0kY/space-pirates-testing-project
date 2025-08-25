using Godot;
using SpacePiratesTestingProject.Marching_Cubes;
using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;

public partial class ChunkLoader : Node3D
{
	[Export] public int RenderDistance = 2;
	[Export] public int ChunkSize = 16;
	[Export] public int ChunkHeight = 32;
	[Export] public FastNoiseLite Noise;
	[Export] public float NoiseScale = 1.0f;
	[Export] public float HeightThreshold = 0.5f;
	[Export] public bool Use3DNoise = false;
	[Export] public int Resolution = 2;

	// 0 = auto (počítá se z počtu jader), jinak fixní limit
	[Export] public int MaxConcurrentGenerations = 0;

	private readonly Dictionary<Vector3I, Chunk> _chunks = new();
	private readonly ConcurrentQueue<(Vector3I pos, Chunk chunk)> _readyChunks = new();
	private readonly HashSet<Vector3I> _pending = new(); // “už se generuje”

	// Definuj si hranice LODů
	public int Lod0Distance = 3;
	public int Lod1Distance = 7;
	public int Lod2Distance = 12;

	// Definuj rozlišení pro každý LOD
	public int Lod0Resolution = 16;
	public int Lod1Resolution = 32;
	public int Lod2Resolution = 64;

	private SemaphoreSlim _genGate;

	[Export] public Node3D Player;

	public override void _Ready()
	{
		var max = MaxConcurrentGenerations > 0
			? MaxConcurrentGenerations
			: Math.Max(1, System.Environment.ProcessorCount - 1);

		_genGate = new SemaphoreSlim(max, max);
		GD.Print($"[ChunkLoader] Max concurrency: {max}");
	}

	public Chunk GetPlayerCurrentChunk()
	{
		Vector3 playerPos = Player.Position;

		foreach (var chunk in _chunks.Values.ToArray())
		{
			Vector3 min = new Vector3(chunk.Position.X, chunk.Position.Y, chunk.Position.Z);
			Vector3 max = min + new Vector3(chunk.Width, chunk.Height, chunk.Width); // assuming square chunk in XZ

			if (playerPos.X >= min.X && playerPos.X < max.X &&
				playerPos.Z >= min.Z && playerPos.Z < max.Z)
			{
				return chunk;
			}
		}

		return null; // hráč není v žádném chunku
	}

	public override void _Process(double delta)
	{
		var playerChunk = new Vector3I(
			Mathf.FloorToInt(Player.Position.X / ChunkSize),
			0,
			Mathf.FloorToInt(Player.Position.Z / ChunkSize)
		);

		var currentChunk = GetPlayerCurrentChunk();
		if (currentChunk != null)
		{
			GD.Print("Chunk position: " + currentChunk.Position + " Player position: " + Player.Transform.Origin);
		}

		// Cílová množina chunků v dosahu
		var target = new HashSet<Vector3I>();
		for (int x = -RenderDistance; x <= RenderDistance; x++)
			for (int z = -RenderDistance; z <= RenderDistance; z++)
				target.Add(GetPlayerCurrentChunk()?.Position ?? playerChunk + new Vector3I(x, 0, z));

		// Spusť generaci chybějících chunků (není v cache ani v pending)
		foreach (var pos in target)
		{
			if (_chunks.ContainsKey(pos)) continue;
			if (_pending.Contains(pos)) continue;
			GenerateChunkAsync(pos);
		}

		// Přidej hotové chunky do scény
		while (_readyChunks.TryDequeue(out var item))
		{
			if (_chunks.ContainsKey(item.pos))
			{
				// už byl mezitím vygenerován/načten – zahodíme
				item.chunk.MeshInstance.QueueFree();
				continue;
			}

			_chunks[item.pos] = item.chunk;
			AddChild(item.chunk.MeshInstance);
		}

		//Unload vzdálených chunků mimo dosah <- NOT WORKING, nemaže chunky správně
		var toRemove = _chunks.Keys
			.Where(pos => pos.DistanceSquaredTo(playerChunk) > RenderDistance * 15)
			.ToList();

		foreach (var pos in toRemove)
		{
			if (_chunks.TryGetValue(pos, out var ch))
			{
				ch.MeshInstance.QueueFree();
				_chunks.Remove(pos);
			}
		}
	}

	private int GetChunkResolution(Vector3I chunkPos, Vector3I playerChunk)
	{
		int dist = (int)(chunkPos - playerChunk).Length();
		if (dist <= Lod0Distance)
			return Lod0Resolution;
		if (dist <= Lod1Distance)
			return Lod1Resolution;
		return Lod2Resolution;
	}

	private async void GenerateChunkAsync(Vector3I chunkPos)
	{
		// Zabraň duplicitám
		if (!_pending.Add(chunkPos)) return;

		await _genGate.WaitAsync(); // limituj paralelní běhy
		try
		{
			// Těžké výpočty mimo hlavní thread
			var newChunk = await Task.Run(() =>
			{
				var chunk = new Chunk(chunkPos * ChunkSize, ChunkSize, ChunkHeight, Noise, HeightThreshold, Resolution);
				chunk.GenerateMesh(); // jen výpočty + sestavení dat
				return chunk;
			});

			_readyChunks.Enqueue((chunkPos, newChunk));
		}
		catch (Exception e)
		{
			GD.PushError($"Chunk gen error at {chunkPos}: {e}");
		}
		finally
		{
			_pending.Remove(chunkPos);
			_genGate.Release();
		}
	}
}
