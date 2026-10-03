using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Media;
namespace Mosaic;

internal record Layout(string Id, string Category, string Vi, string En);
internal static class NativeGeometry
{
    [DllImport("MosaicGeometry", CallingConvention = CallingConvention.Cdecl)]
    private static extern int mosaic_frame([MarshalAs(UnmanagedType.LPUTF8Str)] string id, int count, double width, double height, double gap, [Out] double[]? output, int capacity);
    [DllImport("MosaicGeometry", CallingConvention = CallingConvention.Cdecl)] private static extern int mosaic_layout_count();
    [DllImport("MosaicGeometry", CallingConvention = CallingConvention.Cdecl)] private static extern IntPtr mosaic_layout_field(int index, int field);
    internal static readonly Layout[] Layouts = Enumerable.Range(0, mosaic_layout_count()).Select(i => new Layout(Field(i,0),Field(i,1),Field(i,2),Field(i,3))).ToArray();
    private static string Field(int i, int field) => Marshal.PtrToStringUTF8(mosaic_layout_field(i,field)) ?? "";
    internal static List<StreamGeometry> Frame(string id, int count, double width, double height, double gap)
    {
        int length = mosaic_frame(id,count,width,height,gap,null,0);
        if(length<1 || length>10000) throw new InvalidOperationException("Invalid collage geometry");
        var values = new double[length];
        if(mosaic_frame(id,count,width,height,gap,values,length)!=length) throw new InvalidOperationException("Geometry bridge failed");
        var cells = new List<StreamGeometry>(); int offset=1;
        while(offset<length)
        {
            int vertices=(int)values[offset++]; var path=new StreamGeometry();
            using(var writer=path.Open())
            {
                for(int i=0;i<vertices;i++)
                {
                    var point=new Point(values[offset++],values[offset++]);
                    if(i==0)writer.BeginFigure(point,true,true);else writer.LineTo(point,true,false);
                }
            }
            path.Freeze(); cells.Add(path);
        }
        return cells;
    }
}
