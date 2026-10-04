using System.IO;
using System.Windows;
using System.Windows.Media;
using System.Windows.Media.Imaging;
namespace Mosaic;

internal record Photo(BitmapSource Image, string Name, double X=.5, double Y=.5, double Zoom=1);
internal record Collage(List<Photo> Photos, string Layout="grid", double Ratio=1, double Border=24, Color? FrameColor=null)
{
    internal int OutputWidth => Ratio>=1 ? 3840 : (int)Math.Round(3840*Ratio);
    internal int OutputHeight => Ratio>=1 ? (int)Math.Round(3840/Ratio) : 3840;
    internal List<StreamGeometry> Cells(int? count=null) => NativeGeometry.Frame(Layout,count??Math.Max(1,Photos.Count),OutputWidth,OutputHeight,Border);
    internal static Rect Placement(Photo photo, Rect box)
    {
        double scale=Math.Max(box.Width/photo.Image.PixelWidth,box.Height/photo.Image.PixelHeight)*photo.Zoom;
        double w=photo.Image.PixelWidth*scale,h=photo.Image.PixelHeight*scale;
        return new Rect(box.X-(w-box.Width)*photo.X,box.Y-(h-box.Height)*photo.Y,w,h);
    }
    internal static Photo Transform(Photo photo, Rect box, Point anchor, Point destination, double zoom)
    {
        var before=Placement(photo,box);var result=photo with{Zoom=Math.Clamp(zoom,1,4)};
        var after=Placement(result,box);
        double left=destination.X-(anchor.X-before.X)*after.Width/before.Width;
        double top=destination.Y-(anchor.Y-before.Y)*after.Height/before.Height;
        return result with{
            X=after.Width>box.Width?Math.Clamp((box.X-left)/(after.Width-box.Width),0,1):.5,
            Y=after.Height>box.Height?Math.Clamp((box.Y-top)/(after.Height-box.Height),0,1):.5};
    }
    internal void Draw(DrawingContext context, double width, double height, int selected=-1)
    {
        context.PushClip(new RectangleGeometry(new Rect(0,0,width,height)));
        context.PushTransform(new ScaleTransform(width/OutputWidth,height/OutputHeight));
        var frame=new SolidColorBrush(FrameColor??Colors.White); frame.Freeze();
        context.DrawRectangle(frame,null,new Rect(0,0,OutputWidth,OutputHeight));
        var cells=Cells();
        for(int i=0;i<Photos.Count;i++)
        {
            context.PushClip(cells[i]); context.DrawImage(Photos[i].Image,Placement(Photos[i],cells[i].Bounds)); context.Pop();
            if(i==selected)
            {
                double stroke=OutputWidth/width;
                context.DrawGeometry(null,new Pen(Brushes.White,3*stroke),cells[i]);
                context.DrawGeometry(null,new Pen(Brushes.Black,stroke){DashStyle=DashStyles.Dash},cells[i]);
            }
        }
        context.Pop();context.Pop();
    }
    internal void Export(string filename,bool png)
    {
        if(Photos.Count==0)throw new InvalidOperationException("No photos");
        var visual=new DrawingVisual(); using(var context=visual.RenderOpen())Draw(context,OutputWidth,OutputHeight);
        var output=new RenderTargetBitmap(OutputWidth,OutputHeight,96,96,PixelFormats.Pbgra32);output.Render(visual);output.Freeze();
        BitmapEncoder encoder=png ? new PngBitmapEncoder() : new JpegBitmapEncoder{QualityLevel=96};
        encoder.Frames.Add(BitmapFrame.Create(output));
        // Encode beside the destination, then replace atomically. Failures leave existing user files intact.
        string temp=filename+"."+Guid.NewGuid().ToString("N")+".tmp";
        try { using(var stream=File.Create(temp))encoder.Save(stream); File.Move(temp,filename,true); }
        finally { if(File.Exists(temp))File.Delete(temp); }
    }
}
internal static class PhotoDecoder
{
    internal static BitmapSource Decode(string path,double maxPixels)
    {
        var info=new FileInfo(path); if(info.Length<=0||info.Length>30*1024*1024)throw new InvalidDataException("Photo must be under 30 MB");
        int width,height,orientation=1;
        using(var stream=File.OpenRead(path))
        {
            var decoder=BitmapDecoder.Create(stream,BitmapCreateOptions.DelayCreation,BitmapCacheOption.OnDemand);
            var frame=decoder.Frames[0];width=frame.PixelWidth;height=frame.PixelHeight;
            if(frame.Metadata is BitmapMetadata metadata)
            {
                foreach(var query in new[]{"/app1/ifd/{ushort=274}","/ifd/{ushort=274}"})
                {
                    try { if(metadata.ContainsQuery(query)){orientation=Convert.ToInt32(metadata.GetQuery(query));break;} } catch(NotSupportedException) { }
                }
            }
        }
        if(width<=0||height<=0)throw new InvalidDataException("Invalid dimensions");
        double scale=Math.Min(1,Math.Min(3840.0/Math.Max(width,height),Math.Sqrt(maxPixels/((double)width*height))));
        var image=new BitmapImage();
        using(var stream=File.OpenRead(path))
        {
            image.BeginInit(); image.CacheOption=BitmapCacheOption.OnLoad;image.StreamSource=stream;
            image.DecodePixelWidth=Math.Max(1,(int)(width*scale));image.DecodePixelHeight=Math.Max(1,(int)(height*scale));image.EndInit();image.Freeze();
        }
        Matrix matrix=orientation switch {
            2=>new(-1,0,0,1,0,0),3=>new(-1,0,0,-1,0,0),4=>new(1,0,0,-1,0,0),
            5=>new(0,1,1,0,0,0),6=>new(0,1,-1,0,0,0),7=>new(0,-1,-1,0,0,0),8=>new(0,-1,1,0,0,0),_=>Matrix.Identity};
        if(matrix.IsIdentity)return image;
        var oriented=new TransformedBitmap(image,new MatrixTransform(matrix));oriented.Freeze();return oriented;
    }
    internal static BitmapSource Shrink(BitmapSource image,double maxPixels)
    {
        double scale=Math.Min(1,Math.Sqrt(maxPixels/((double)image.PixelWidth*image.PixelHeight)));
        if(scale>=1)return image;
        var transformed=new TransformedBitmap(image,new ScaleTransform(scale,scale));
        // Materialize pixels so the resized image does not retain the larger source.
        int stride=(transformed.PixelWidth*transformed.Format.BitsPerPixel+7)/8;
        var pixels=new byte[stride*transformed.PixelHeight];transformed.CopyPixels(pixels,stride,0);
        var copy=BitmapSource.Create(transformed.PixelWidth,transformed.PixelHeight,96,96,transformed.Format,transformed.Palette,pixels,stride);
        copy.Freeze();return copy;
    }
}
