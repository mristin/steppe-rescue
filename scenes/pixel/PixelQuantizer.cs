using Godot;

namespace SteppeRescue.Pixel;

/// <summary>
/// Turn a supersampled picture into pixel art in the palette, for
/// <c>Pixelate</c> (scenes/pixel/pixelate.gd), which rasterizes the vector
/// pictures. The loop over the pixels is too slow in GDScript for the
/// creatures, which are pixelated anew for each heading while the game runs.
/// </summary>
[GlobalClass]
public partial class PixelQuantizer : RefCounted
{
    private byte[] _palette = [];

    /// <summary>Set the colors of the palette, as RGB triples.</summary>
    public void SetPalette(Color[] colors)
    {
        _palette = new byte[colors.Length * 3];
        for (int i = 0; i < colors.Length; i++)
        {
            _palette[i * 3] = (byte)colors[i].R8;
            _palette[i * 3 + 1] = (byte)colors[i].G8;
            _palette[i * 3 + 2] = (byte)colors[i].B8;
        }
    }

    /// <summary>
    /// Pixelate the RGBA8 <paramref name="sampled"/> picture of
    /// <paramref name="sampledWidth"/> x <paramref name="sampledHeight"/>
    /// into <paramref name="width"/> x <paramref name="height"/> pixels:
    /// each pixel takes the palette color (or the transparency) of most of its
    /// <paramref name="supersample"/> x <paramref name="supersample"/>
    /// samples, and the transparent pixels next to the opaque ones take the
    /// <paramref name="outline"/> color, if <paramref name="withOutline"/>.
    /// Returns the RGBA8 pixels.
    /// </summary>
    public byte[] Quantize(
        byte[] sampled,
        int sampledWidth,
        int sampledHeight,
        int width,
        int height,
        int supersample,
        bool withOutline,
        Color outline
    )
    {
        return QuantizeCore(
            sampled,
            sampledWidth,
            sampledHeight,
            width,
            height,
            supersample,
            _palette,
            withOutline ? new byte[] { (byte)outline.R8, (byte)outline.G8, (byte)outline.B8 } : null
        );
    }

    /// <summary>The core of <see cref="Quantize"/>, without Godot types.</summary>
    public static byte[] QuantizeCore(
        byte[] sampled,
        int sampledWidth,
        int sampledHeight,
        int width,
        int height,
        int supersample,
        byte[] palette,
        byte[]? outline
    )
    {
        int colors = palette.Length / 3;
        int transparent = colors;
        var votes = new int[colors + 1];
        var nearest = new System.Collections.Generic.Dictionary<int, int>();
        var indices = new int[width * height];

        for (int y = 0; y < height; y++)
        {
            for (int x = 0; x < width; x++)
            {
                System.Array.Clear(votes);
                for (int sy = 0; sy < supersample; sy++)
                {
                    int row = System.Math.Min(y * supersample + sy, sampledHeight - 1);
                    for (int sx = 0; sx < supersample; sx++)
                    {
                        int column = System.Math.Min(x * supersample + sx, sampledWidth - 1);
                        int offset = (row * sampledWidth + column) * 4;
                        if (sampled[offset + 3] < 128)
                        {
                            votes[transparent]++;
                            continue;
                        }
                        int rgb = (sampled[offset] << 16) | (sampled[offset + 1] << 8) | sampled[offset + 2];
                        if (!nearest.TryGetValue(rgb, out int index))
                        {
                            index = Nearest(palette, sampled[offset], sampled[offset + 1], sampled[offset + 2]);
                            nearest[rgb] = index;
                        }
                        votes[index]++;
                    }
                }

                int best = transparent;
                for (int i = 0; i < votes.Length; i++)
                {
                    if (votes[i] > votes[best])
                    {
                        best = i;
                    }
                }
                indices[y * width + x] = best;
            }
        }

        var result = new byte[width * height * 4];
        for (int y = 0; y < height; y++)
        {
            for (int x = 0; x < width; x++)
            {
                int index = indices[y * width + x];
                int offset = (y * width + x) * 4;
                if (index != transparent)
                {
                    result[offset] = palette[index * 3];
                    result[offset + 1] = palette[index * 3 + 1];
                    result[offset + 2] = palette[index * 3 + 2];
                    result[offset + 3] = 255;
                    continue;
                }
                if (outline == null)
                {
                    continue;
                }
                bool edge =
                    (x > 0 && indices[y * width + x - 1] != transparent)
                    || (x < width - 1 && indices[y * width + x + 1] != transparent)
                    || (y > 0 && indices[(y - 1) * width + x] != transparent)
                    || (y < height - 1 && indices[(y + 1) * width + x] != transparent);
                if (edge)
                {
                    result[offset] = outline[0];
                    result[offset + 1] = outline[1];
                    result[offset + 2] = outline[2];
                    result[offset + 3] = 255;
                }
            }
        }
        return result;
    }

    /// <summary>The index of the palette color nearest to the color, weighted as the eye sees it.</summary>
    private static int Nearest(byte[] palette, byte r, byte g, byte b)
    {
        int best = 0;
        double bestDistance = double.MaxValue;
        for (int i = 0; i < palette.Length / 3; i++)
        {
            double dr = palette[i * 3] - r;
            double dg = palette[i * 3 + 1] - g;
            double db = palette[i * 3 + 2] - b;
            double distance = 0.3 * dr * dr + 0.59 * dg * dg + 0.11 * db * db;
            if (distance < bestDistance)
            {
                bestDistance = distance;
                best = i;
            }
        }
        return best;
    }
}
