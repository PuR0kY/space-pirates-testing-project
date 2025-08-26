using Godot;
using System;
using System.Threading.Tasks;

namespace SpacePiratesTestingProject.Marching_Cubes
{
	public partial class ComputeDensity : Node
	{
		[Export] public FastNoiseLite Noise;
		[Export] public Shader ComputeShaderResource;

		/// <summary>
		/// Vypočítá density atlas pro chunk na hlavním threadu.
		/// </summary>
		public async Task<float[,,]> ComputeDensityAtlasAsync(Vector3 chunkOrigin, int gx, int gy, int gz, float step, float noiseScale)
		{
			// velikost "atlasu" pro readback
			int atlasW = gx;
			int atlasH = gy * gz;

			// připravíme image + textura
			Image atlasImage = Image.Create(atlasW, atlasH, false, Image.Format.Rgb8);
			atlasImage.Fill(Colors.Black);
			ImageTexture atlasTexture = ImageTexture.CreateFromImage(atlasImage);

			// shader
			Shader shader = ComputeShaderResource ?? GD.Load<Shader>("res://Marching Cubes/density_compute.gdshader");
			if (shader == null)
				throw new Exception("Compute shader not found: res://Marching Cubes/density_compute.gdshader");

			ShaderMaterial material = new ShaderMaterial();
			material.Shader = shader;
			material.SetShaderParameter("gridSize", new Vector3I(gx, gy, gz));
			material.SetShaderParameter("chunkOrigin", chunkOrigin);
			material.SetShaderParameter("step", step);
			material.SetShaderParameter("noiseScale", noiseScale);
			material.SetShaderParameter("slicePitch", gy);
			material.SetShaderParameter("outAtlas", atlasTexture);

			// viewport a canvas pro shader
			SubViewport vp = new SubViewport();
			vp.Size = new Vector2I(atlasW, atlasH);
			vp.OwnWorld3D = false;
			vp.Disable3D = true;
			AddChild(vp);

			ColorRect canvas = new ColorRect();
			canvas.CustomMinimumSize = new Vector2(atlasW, atlasH);
			canvas.Material = material;
			vp.AddChild(canvas);

			// počkáme 2 idle_frame pro dokončení GPU výpočtu
			var tree = (SceneTree)Engine.GetMainLoop(); // SceneTree je hlavní loop
			await ToSignal(tree, "physics_frame");
			await ToSignal(tree, "physics_frame");

			// readback do Image
			Image resultImage = vp.GetTexture().GetImage();

			float[,,] result = new float[gx, gy, gz];
			for (int iz = 0; iz < gz; iz++)
			{
				for (int iy = 0; iy < gy; iy++)
				{
					for (int ix = 0; ix < gx; ix++)
					{
						int ax = ix;
						int ay = iz * gy + iy;
						Color c = resultImage.GetPixel(ax, ay);
						result[ix, iy, iz] = c.R;
					}
				}
			}

			// cleanup
			canvas.QueueFree();
			vp.QueueFree();

			return result;
		}
	}
}
