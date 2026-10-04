using System.IO;
using System.Windows;
using System.Windows.Media;
using System.Windows.Media.Imaging;
namespace Mosaic;
internal static class Tests
{
    private static void Check(bool condition,string label){if(!condition)throw new Exception(label);}
    [STAThread] private static int Main()
    {
        string temp=Path.Combine(Path.GetTempPath(),"mosaic-tests-"+Guid.NewGuid());Directory.CreateDirectory(temp);
        try
        {
            Check(NativeGeometry.Layouts.Length==36,"36 layouts");
            Check(NativeGeometry.Layouts.Any(l=>l.Vi.Contains('ư')),"UTF-8 labels");
            foreach(var layout in NativeGeometry.Layouts)
            foreach(double ratio in new[]{.2,1.0,5.0})
            foreach(int count in new[]{1,2,7,24})
            {
                var c=new Collage([],layout.Id,ratio,120);
                var cells=c.Cells(count);Check(cells.Count==count,"cell count");
                foreach(var cell in cells)Check(cell.Bounds.Width>0&&cell.Bounds.Height>0&&double.IsFinite(cell.Bounds.Width),"nonempty geometry");
            }
            byte[] pixels=new byte[80*40*4];
            for(int y=0;y<40;y++)for(int x=0;x<80;x++){int p=(y*80+x)*4;pixels[p+(y<20?2:0)]=255;pixels[p+3]=255;}
            var source=BitmapSource.Create(80,40,96,96,PixelFormats.Bgra32,null,pixels,80*4);source.Freeze();
            var photo=new Photo(source,"fixture");
            foreach(double x in new[]{0,.5,1})foreach(double y in new[]{0,.5,1})foreach(double z in new[]{1.0,4.0})
            {
                var box=new Rect(12,24,100,300);var placed=Collage.Placement(photo with{X=x,Y=y,Zoom=z},box);Check(placed.Contains(box),"crop containment");
            }
            var zoomBox=new Rect(10,20,200,200);var anchor=new Point(70,100);
            var zoomed=Collage.Transform(photo,zoomBox,anchor,anchor,2);
            var before=Collage.Placement(photo,zoomBox);var after=Collage.Placement(zoomed,zoomBox);
            Check(Math.Abs((anchor.X-before.X)/before.Width-(anchor.X-after.X)/after.Width)<1e-9,"zoom horizontal anchor");
            Check(Math.Abs((anchor.Y-before.Y)/before.Height-(anchor.Y-after.Y)/after.Height)<1e-9,"zoom vertical anchor");
            foreach(double zoom in new[]{.1,1,3,12}) {
                var moved=Collage.Transform(zoomed,zoomBox,anchor,new Point(-900,1600),zoom);
                Check(moved.Zoom>=1&&moved.Zoom<=4&&Collage.Placement(moved,zoomBox).Contains(zoomBox),"zoom/pan limits");
            }
            var collage=new Collage([photo],Border:0);
            foreach(bool png in new[]{true,false})
            {
                string path=Path.Combine(temp,png?"export.png":"export.jpg");collage.Export(path,png);
                var result=PhotoDecoder.Decode(path,20_000_000);Check(result.PixelWidth==3840&&result.PixelHeight==3840,"4K dimensions");
                var rgba=new FormatConvertedBitmap(result,PixelFormats.Bgra32,null,0);byte[] top=new byte[4],bottom=new byte[4];
                rgba.CopyPixels(new Int32Rect(1920,400,1,1),top,4,0);rgba.CopyPixels(new Int32Rect(1920,3400,1,1),bottom,4,0);
                Check(top[2]>230&&top[0]<25&&bottom[0]>230&&bottom[2]<25,"export colors and orientation");
                var bounded=PhotoDecoder.Decode(path,100_000);Check((long)bounded.PixelWidth*bounded.PixelHeight<=100_000,"bounded decode");
            }
            var shrunk=PhotoDecoder.Shrink(source,400);Check(shrunk.IsFrozen&&(long)shrunk.PixelWidth*shrunk.PixelHeight<=400,"materialized resize");
            string rotated=Path.Combine(temp,"rotated.jpg");
            var metadata=new BitmapMetadata("jpg");metadata.SetQuery("/app1/ifd/{ushort=274}",(ushort)6);
            var encoder=new JpegBitmapEncoder();encoder.Frames.Add(BitmapFrame.Create(source,null,metadata,null));using(var s=File.Create(rotated))encoder.Save(s);
            var decoded=PhotoDecoder.Decode(rotated,100_000);Check(decoded.PixelWidth==40&&decoded.PixelHeight==80,"EXIF rotation");
            string bad=Path.Combine(temp,"invalid.png");File.WriteAllText(bad,"invalid");bool rejected=false;try{PhotoDecoder.Decode(bad,100);}catch{rejected=true;}Check(rejected,"reject corrupt image");
            Console.WriteLine("PASS: 432 layout cases, crop containment, PNG/JPG 4K pixels, bounded decode/resize, EXIF and invalid input");return 0;
        }
        catch(Exception e){Console.Error.WriteLine(e);return 1;}
        finally{Directory.Delete(temp,true);}
    }
}
