using System.Windows;
using System.Windows.Input;
using System.Windows.Media;
namespace Mosaic;
internal sealed class Preview : FrameworkElement
{
    internal Collage Collage = new([]);
    internal int Selected;
    internal Action<int,double,double>? CropChanged;
    private Photo? dragPhoto;
    private Point dragStart;
    private Rect dragBox;
    private Rect CanvasBox {
        get { double w=Math.Min(ActualWidth,ActualHeight*Collage.Ratio);return new Rect((ActualWidth-w)/2,(ActualHeight-w/Collage.Ratio)/2,w,w/Collage.Ratio); }
    }
    internal Preview() { ClipToBounds=true;Focusable=true;Cursor=Cursors.Hand; }
    protected override void OnRender(DrawingContext context)
    {
        base.OnRender(context);var box=CanvasBox;
        if(box.Width<=0||box.Height<=0)return;
        context.PushTransform(new TranslateTransform(box.X,box.Y));Collage.Draw(context,box.Width,box.Height,Selected);context.Pop();
    }
    protected override void OnMouseLeftButtonDown(MouseButtonEventArgs e)
    {
        if(Collage.Photos.Count==0)return;
        var box=CanvasBox;var p=e.GetPosition(this);if(!box.Contains(p))return;
        var native=new Point((p.X-box.X)*Collage.OutputWidth/box.Width,(p.Y-box.Y)*Collage.OutputHeight/box.Height);
        var cells=Collage.Cells();int index=cells.FindIndex(c=>c.FillContains(native));if(index<0)return;
        Selected=index;dragPhoto=Collage.Photos[index];dragStart=native;dragBox=cells[index].Bounds;
        CropChanged?.Invoke(index,dragPhoto.X,dragPhoto.Y);CaptureMouse();Focus();e.Handled=true;
    }
    protected override void OnMouseMove(MouseEventArgs e)
    {
        if(dragPhoto is null||!IsMouseCaptured)return;
        var box=CanvasBox;var p=e.GetPosition(this);var place=Collage.Placement(dragPhoto,dragBox);
        double dx=place.Width-dragBox.Width,dy=place.Height-dragBox.Height;
        double x=dx>0?Math.Clamp(dragPhoto.X-((p.X-box.X)*Collage.OutputWidth/box.Width-dragStart.X)/dx,0,1):.5;
        double y=dy>0?Math.Clamp(dragPhoto.Y-((p.Y-box.Y)*Collage.OutputHeight/box.Height-dragStart.Y)/dy,0,1):.5;
        CropChanged?.Invoke(Selected,x,y);e.Handled=true;
    }
    protected override void OnMouseLeftButtonUp(MouseButtonEventArgs e) { dragPhoto=null;ReleaseMouseCapture(); }
    protected override void OnLostMouseCapture(MouseEventArgs e) { dragPhoto=null; }
}
