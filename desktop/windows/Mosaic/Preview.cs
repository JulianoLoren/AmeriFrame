using System.Windows;
using System.Windows.Input;
using System.Windows.Media;
namespace Mosaic;
internal sealed class Preview : FrameworkElement
{
    internal Collage Collage = new([]);
    internal int Selected;
    internal Action<int,Photo>? CropChanged;
    private Photo? activePhoto;
    private int activeIndex;
    private Point lastPoint;
    private Rect activeBox;
    private Rect CanvasBox {
        get { double w=Math.Min(ActualWidth,ActualHeight*Collage.Ratio);return new Rect((ActualWidth-w)/2,(ActualHeight-w/Collage.Ratio)/2,w,w/Collage.Ratio); }
    }
    internal Preview() { ClipToBounds=true;Focusable=true;Cursor=Cursors.Hand;IsManipulationEnabled=true; }
    protected override void OnRender(DrawingContext context)
    {
        base.OnRender(context);var box=CanvasBox;
        if(box.Width<=0||box.Height<=0)return;
        context.PushTransform(new TranslateTransform(box.X,box.Y));Collage.Draw(context,box.Width,box.Height,Selected);context.Pop();
    }
    private Point Native(Point point)
    {
        var box=CanvasBox;
        return new Point((point.X-box.X)*Collage.OutputWidth/box.Width,(point.Y-box.Y)*Collage.OutputHeight/box.Height);
    }
    private bool Begin(Point point)
    {
        activePhoto=null;var box=CanvasBox;
        if(Collage.Photos.Count==0||box.Width<=0||box.Height<=0||!box.Contains(point))return false;
        var native=Native(point);var cells=Collage.Cells();int index=cells.FindIndex(c=>c.FillContains(native));if(index<0)return false;
        Selected=activeIndex=index;activePhoto=Collage.Photos[index];lastPoint=native;activeBox=cells[index].Bounds;
        CropChanged?.Invoke(index,activePhoto);return true;
    }
    private void Change(Point from,Point to,double scale)
    {
        if(activePhoto is null||Selected!=activeIndex||activeIndex>=Collage.Photos.Count)return;
        var photo=Collage.Photos[activeIndex];
        if(photo.Image!=activePhoto.Image||Collage.Cells()[activeIndex].Bounds!=activeBox){activePhoto=null;return;}
        CropChanged?.Invoke(activeIndex,Collage.Transform(photo,activeBox,from,to,photo.Zoom*scale));
    }
    protected override void OnMouseLeftButtonDown(MouseButtonEventArgs e)
    {
        if(e.StylusDevice!=null||!Begin(e.GetPosition(this)))return;
        CaptureMouse();Focus();e.Handled=true;
    }
    protected override void OnMouseMove(MouseEventArgs e)
    {
        if(activePhoto is null||!IsMouseCaptured)return;
        var point=Native(e.GetPosition(this));Change(lastPoint,point,1);lastPoint=point;e.Handled=true;
    }
    protected override void OnMouseLeftButtonUp(MouseButtonEventArgs e) { activePhoto=null;ReleaseMouseCapture(); }
    protected override void OnLostMouseCapture(MouseEventArgs e) { activePhoto=null; }
    protected override void OnMouseWheel(MouseWheelEventArgs e)
    {
        if(!Begin(e.GetPosition(this)))return;
        Change(lastPoint,lastPoint,Math.Exp(Math.Clamp(e.Delta,-600,600)*.001));
        if(!IsMouseCaptured)activePhoto=null;
        e.Handled=true;
    }
    protected override void OnTouchDown(TouchEventArgs e)
    {
        if(TouchesOver.Count()==1)Begin(e.GetTouchPoint(this).Position);
        base.OnTouchDown(e);
    }
    protected override void OnManipulationStarting(ManipulationStartingEventArgs e)
    {
        e.ManipulationContainer=this;e.Mode=ManipulationModes.Scale|ManipulationModes.Translate;e.Handled=true;
    }
    protected override void OnManipulationStarted(ManipulationStartedEventArgs e)
    {
        if(activePhoto is null&&!Begin(e.ManipulationOrigin)){e.Complete();return;}
        Focus();e.Handled=true;
    }
    protected override void OnManipulationDelta(ManipulationDeltaEventArgs e)
    {
        if(e.IsInertial){e.Complete();return;}
        var origin=Native(e.ManipulationOrigin);var delta=e.DeltaManipulation;
        var destination=Native(e.ManipulationOrigin+delta.Translation);
        Change(origin,destination,Math.Sqrt(delta.Scale.X*delta.Scale.Y));e.Handled=true;
    }
    protected override void OnManipulationCompleted(ManipulationCompletedEventArgs e) { activePhoto=null;e.Handled=true; }
}
