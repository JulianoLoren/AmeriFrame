using System.IO;
using System.Windows;
using System.Windows.Automation;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using Microsoft.Win32;
namespace Mosaic;

internal sealed class MainWindow : Window
{
    private readonly Settings settings=Settings.Load();
    private Collage collage=new([]);
    private int selected;
    private bool busy,png=true,updating;
    private string category="all",customWidth="1",customHeight="1";
    private Preview preview=new();
    private TextBlock status=new(),sizeLabel=new(),photoLabel=new();
    private StackPanel controls=new(),thumbnails=new();
    private Slider zoom=new(),panX=new(),panY=new();
    private UIElement editor=new Grid();
    private Button saveButton=new();
    private readonly Dictionary<string,Button> layoutButtons=new();
    private string T(string vi,string en)=>settings.Language=="vi"?vi:en;
    internal MainWindow()
    {
        Title="Mosaic";Width=1240;Height=850;MinWidth=930;MinHeight=620;
        Icon=BitmapFrame.Create(new Uri("pack://application:,,,/AppIcon.ico"));
        AllowDrop=true;Drop+=async(_,e)=>{if(e.Data.GetData(DataFormats.FileDrop) is string[] files)await Import(files);};
        PreviewDragOver+=(_,e)=>{e.Effects=!busy&&e.Data.GetDataPresent(DataFormats.FileDrop)?DragDropEffects.Copy:DragDropEffects.None;e.Handled=true;};
        PreviewKeyDown+=(_,e)=>{if(Keyboard.Modifiers==ModifierKeys.Control&&e.Key==Key.O){ChoosePhotos();e.Handled=true;}if(Keyboard.Modifiers==ModifierKeys.Control&&e.Key==Key.S){Save();e.Handled=true;}};
        Build();
    }
    private TextBlock Text(string text,double size=13)=>new(){Text=text,FontSize=size,TextWrapping=TextWrapping.Wrap,Margin=new Thickness(0,4,0,6)};
    private Button Button(string title,Action action)
    {
        var b=new Button{Content=title,Margin=new Thickness(0,3,6,3),MinHeight=30};b.Click+=(_,_)=>{if(!busy)action();};AutomationProperties.SetName(b,title);return b;
    }
    private static void Add(Panel panel,params UIElement[] children){foreach(var child in children)panel.Children.Add(child);}
    private void Heading(string text){Add(controls,new Separator{Margin=new Thickness(0,12,0,8)},Text(text,17));}
    private ComboBox Choice(string label,IEnumerable<string> options,int selection,Action<int> action)
    {
        var box=new ComboBox{ItemsSource=options,SelectedIndex=selection,MinWidth=85,Margin=new Thickness(0,3,8,3)};
        AutomationProperties.SetName(box,label);box.SelectionChanged+=(_,_)=>{if(!updating&&!busy&&box.SelectedIndex>=0)action(box.SelectedIndex);};return box;
    }
    private Slider Slider(string label,double min,double max,double value,Action<double> action)
    {
        var slider=new Slider{Minimum=min,Maximum=max,Value=value,Margin=new Thickness(0,3,0,12),TickFrequency=(max-min)/100,IsMoveToPointEnabled=true};
        AutomationProperties.SetName(slider,label);slider.ValueChanged+=(_,_)=>{if(!updating&&!busy)action(slider.Value);};return slider;
    }
    private void Build()
    {
        updating=true;MosaicApplication.ApplyTheme(settings.Dark);
        Background=(Brush)Application.Current.Resources["AppBackground"];Foreground=(Brush)Application.Current.Resources["AppForeground"];
        var root=new DockPanel{Margin=new Thickness(18)};
        var top=new DockPanel{Margin=new Thickness(0,0,0,12)};DockPanel.SetDock(top,Dock.Top);
        var prefs=new StackPanel{Orientation=Orientation.Horizontal,HorizontalAlignment=HorizontalAlignment.Right};DockPanel.SetDock(prefs,Dock.Right);
        Add(prefs,Choice("Language",new[]{"Tiếng Việt","English"},settings.Language=="vi"?0:1,i=>{settings.Language=i==0?"vi":"en";settings.Save();Build();}),
            Choice(T("Giao diện","Theme"),new[]{T("Hệ thống","System"),T("Sáng","Light"),T("Tối","Dark")},settings.Theme=="system"?0:settings.Theme=="light"?1:2,i=>{settings.Theme=new[]{"system","light","dark"}[i];settings.Save();Build();}));
        Add(top,prefs,Text("Mosaic",26));root.Children.Add(top);
        status=Text(T("Ảnh chỉ ở trên thiết bị · Không watermark","On-device processing · No watermark"));DockPanel.SetDock(status,Dock.Bottom);root.Children.Add(status);
        var grid=new Grid();grid.ColumnDefinitions.Add(new ColumnDefinition{Width=new GridLength(365)});grid.ColumnDefinitions.Add(new ColumnDefinition{Width=new GridLength(1,GridUnitType.Star)});
        controls=new StackPanel{Margin=new Thickness(0,0,18,0)};
        var scroll=new ScrollViewer{Content=controls,VerticalScrollBarVisibility=ScrollBarVisibility.Auto,HorizontalScrollBarVisibility=ScrollBarVisibility.Disabled};grid.Children.Add(scroll);
        Add(controls,Text(T("Ghép khoảnh khắc của bạn.","Bring your moments together."),23),Button(T("Thêm ảnh… (Ctrl+O)","Add photos… (Ctrl+O)"),ChoosePhotos));
        photoLabel=Text("");Add(controls,photoLabel,Text(T("Tối đa 24 ảnh · 30 MB/ảnh · Phiên chỉnh sửa không lưu khi đóng app","Up to 24 photos · 30 MB/photo · Sessions are not restored after closing"),11));
        thumbnails=new StackPanel{Orientation=Orientation.Horizontal};Add(controls,new ScrollViewer{Content=thumbnails,HorizontalScrollBarVisibility=ScrollBarVisibility.Auto,VerticalScrollBarVisibility=ScrollBarVisibility.Disabled});
        var photoActions=new WrapPanel();Add(photoActions,Button(T("← Trước","← Previous"),()=>Move(-1)),Button(T("Sau →","Next →"),()=>Move(1)),Button(T("Xóa ảnh","Remove"),Remove));Add(controls,photoActions);
        Heading(T("Tỷ lệ","Ratio"));var ratios=new WrapPanel();
        foreach(var (label,ratio) in new[]{("1:1",1.0),("4:5",.8),("3:2",1.5),("9:16",9.0/16),("16:9",16.0/9)})Add(ratios,Button(label,()=>{collage=collage with{Ratio=ratio};ResetAll();Refresh();}));
        Add(controls,ratios);var custom=new WrapPanel();
        var w=new TextBox{Text=customWidth,Width=65,Margin=new Thickness(0,3,6,3)};var h=new TextBox{Text=customHeight,Width=65,Margin=new Thickness(0,3,6,3)};
        AutomationProperties.SetName(w,T("Rộng","Width"));AutomationProperties.SetName(h,T("Cao","Height"));
        Add(custom,w,Text(":"),h,Button(T("Áp dụng","Apply"),()=>{
            customWidth=w.Text;customHeight=h.Text;
            if(Parse(w.Text,out var a)&&Parse(h.Text,out var b)&&a>=1&&a<=100&&b>=1&&b<=100&&a/b>=.2&&a/b<=5){collage=collage with{Ratio=a/b};ResetAll();Refresh();}
            else Notice(T("Nhập hai số 1–100, tỷ lệ từ 1:5 đến 5:1.","Enter 1–100, with a ratio from 1:5 to 5:1."));
        }));Add(controls,custom);
        Heading(T("Bố cục","Layout"));Add(controls,Choice(T("Nhóm bố cục","Layout category"),new[]{T("Tất cả","All"),T("Cổ điển","Classic"),T("Sáng tạo","Creative")},Array.IndexOf(new[]{"all","classic","creative"},category),i=>{category=new[]{"all","classic","creative"}[i];Build();}));
        var layouts=new WrapPanel();layoutButtons.Clear();
        foreach(var layout in NativeGeometry.Layouts.Where(l=>category=="all"||l.Category==category))
        {
            var b=Button(settings.Language=="vi"?layout.Vi:layout.En,()=>{collage=collage with{Layout=layout.Id};ResetAll();Refresh();});b.Width=98;
            b.ToolTip=layout.Id;layoutButtons[layout.Id]=b;Add(layouts,b);
        }
        Add(controls,layouts);
        Heading(T("Tinh chỉnh","Adjust"));
        Add(controls,Text(T("Zoom ảnh","Photo zoom")));zoom=Slider(T("Zoom ảnh","Photo zoom"),1,4,1,v=>Crop(p=>p with{Zoom=v}));Add(controls,zoom);
        Add(controls,Text(T("Vị trí ngang","Horizontal position")));panX=Slider(T("Vị trí ngang","Horizontal position"),0,1,.5,v=>Crop(p=>p with{X=v}));Add(controls,panX);
        Add(controls,Text(T("Vị trí dọc","Vertical position")));panY=Slider(T("Vị trí dọc","Vertical position"),0,1,.5,v=>Crop(p=>p with{Y=v}));Add(controls,panY,Button(T("Đặt lại ảnh","Reset photo"),()=>{Crop(p=>p with{X=.5,Y=.5,Zoom=1});Refresh();}));
        Add(controls,Text(T("Độ dày khung (px)","Frame thickness (px)")),Slider(T("Độ dày khung","Frame thickness"),0,120,collage.Border,v=>{collage=collage with{Border=v};RefreshPreview();}),Text(T("Khung tự giảm độ dày khi cần để giữ đủ ảnh.","Thickness is reduced when needed to keep every photo visible."),11));
        var hex=new TextBox{Text=(collage.FrameColor??Colors.White).ToString()[3..],Margin=new Thickness(0,3,6,3),Width=95};AutomationProperties.SetName(hex,T("Màu khung HEX","Frame color HEX"));var colors=new WrapPanel();
        Add(colors,hex,Button(T("Màu khung","Frame color"),()=>{try{string v=hex.Text.Trim().TrimStart('#');if(v.Length!=6)throw new FormatException();collage=collage with{FrameColor=(Color)ColorConverter.ConvertFromString("#"+v)};RefreshPreview();}catch{Notice(T("Nhập 6 ký tự HEX, ví dụ FFFFFF.","Enter 6 HEX digits, e.g. FFFFFF."));}}));Add(controls,colors);
        Heading(T("Xuất ảnh","Export"));Add(controls,Choice(T("Định dạng","Format"),new[]{"PNG","JPG"},png?0:1,i=>png=i==0));
        saveButton=Button(T("Lưu ảnh 4K… (Ctrl+S)","Save 4K image… (Ctrl+S)"),Save);Add(controls,saveButton);
        var previewPanel=new DockPanel{Margin=new Thickness(16,0,0,0)};Grid.SetColumn(previewPanel,1);sizeLabel=Text("");DockPanel.SetDock(sizeLabel,Dock.Top);previewPanel.Children.Add(sizeLabel);
        var hint=Text(T("Kéo để căn ảnh · Lăn chuột / Chụm hai ngón để zoom","Drag to crop · Scroll / Pinch to zoom"),12);DockPanel.SetDock(hint,Dock.Bottom);previewPanel.Children.Add(hint);
        preview=new Preview{MinWidth=400,MinHeight=350};preview.CropChanged=(i,photo)=>{if(!busy){selected=i;Crop(_=>photo);RefreshSliders();}};previewPanel.Children.Add(preview);
        grid.Children.Add(previewPanel);editor=grid;root.Children.Add(grid);Content=root;updating=false;Refresh();
    }
    private static bool Parse(string text,out double value)=>double.TryParse(text.Replace(',','.'),System.Globalization.NumberStyles.Float,System.Globalization.CultureInfo.InvariantCulture,out value)&&double.IsFinite(value);
    private void RefreshPreview(){preview.Collage=collage;preview.Selected=selected;preview.InvalidateVisual();sizeLabel.Text=$"{T("BẢN XEM TRƯỚC","LIVE PREVIEW")} · {collage.OutputWidth} × {collage.OutputHeight} px";}
    private void RefreshSliders()
    {
        updating=true;var photo=collage.Photos.ElementAtOrDefault(selected);zoom.Value=photo?.Zoom??1;panX.Value=photo?.X??.5;panY.Value=photo?.Y??.5;
        zoom.IsEnabled=panX.IsEnabled=panY.IsEnabled=photo!=null;updating=false;
    }
    private void Refresh()
    {
        foreach(var (id,button) in layoutButtons){button.FontWeight=id==collage.Layout?FontWeights.Bold:FontWeights.Normal;button.BorderThickness=new Thickness(id==collage.Layout?3:1);}
        RefreshPreview();RefreshSliders();photoLabel.Text=$"{T("Ảnh của bạn","Your photos")} · {collage.Photos.Count}/24";saveButton.IsEnabled=collage.Photos.Count>0;
        thumbnails.Children.Clear();for(int i=0;i<collage.Photos.Count;i++)
        {
            int index=i;var b=Button($"{T("Ảnh","Photo")} {i+1}",()=>{selected=index;Refresh();});b.Content=new Image{Source=collage.Photos[i].Image,Width=58,Height=58,Stretch=Stretch.UniformToFill};
            b.BorderThickness=new Thickness(i==selected?3:1);b.ToolTip=collage.Photos[i].Name;Add(thumbnails,b);
        }
    }
    private void Crop(Func<Photo,Photo> change){if(selected<collage.Photos.Count){var photos=collage.Photos.ToList();photos[selected]=change(photos[selected]);collage=collage with{Photos=photos};RefreshPreview();}}
    private void ResetAll()=>collage=collage with{Photos=collage.Photos.Select(p=>p with{X=.5,Y=.5,Zoom=1}).ToList()};
    private void Move(int delta){int target=selected+delta;if(target<0||target>=collage.Photos.Count)return;var photos=collage.Photos.ToList();(photos[selected],photos[target])=(photos[target],photos[selected]);selected=target;collage=collage with{Photos=photos};Refresh();}
    private void Remove(){if(selected>=collage.Photos.Count)return;var photos=collage.Photos.ToList();photos.RemoveAt(selected);selected=Math.Max(0,Math.Min(selected,photos.Count-1));collage=collage with{Photos=photos};ResetAll();Refresh();}
    private void Notice(string message)=>MessageBox.Show(this,message,T("Thông báo","Notice"),MessageBoxButton.OK,MessageBoxImage.Information);
    private void SetBusy(bool value){busy=value;editor.IsEnabled=!value;status.Text=value?T("Đang xử lý…","Processing…"):T("Ảnh chỉ ở trên thiết bị · Không watermark","On-device processing · No watermark");}
    private async void ChoosePhotos()
    {
        if(busy||collage.Photos.Count>=24)return;
        var dialog=new OpenFileDialog{Multiselect=true,Filter="Images|*.jpg;*.jpeg;*.png;*.bmp;*.tif;*.tiff;*.heic;*.webp;*.avif|All files|*.*"};
        if(dialog.ShowDialog(this)==true)await Import(dialog.FileNames);
    }
    private async Task Import(string[] files)
    {
        if(busy||files.Length==0)return;SetBusy(true);int start=collage.Photos.Count;var original=collage;
        try
        {
            var result=await Worker.Run(()=>{
                double budget=24_000_000.0/Math.Min(24,start+files.Length);int failed=0;
                var photos=original.Photos.Select(p=>p with{Image=PhotoDecoder.Shrink(p.Image,budget)}).ToList();
                foreach(var file in files.Take(24-start)){try{photos.Add(new Photo(PhotoDecoder.Decode(file,budget),Path.GetFileName(file)));}catch(Exception e)when(e is not OutOfMemoryException){failed++;}}
                return (photos,failed);
            });
            collage=collage with{Photos=result.photos};selected=collage.Photos.Count>start?start:selected;ResetAll();Refresh();
            if(result.failed>0||files.Length>24-start)Notice(T("Một số tệp không đọc được hoặc vượt giới hạn 24 ảnh / 30 MB mỗi ảnh.","Some files were unreadable or exceeded the 24-photo / 30 MB per-photo limits."));
        }
        catch(Exception){Notice(T("Không đủ bộ nhớ hoặc không đọc được ảnh. Hãy thử ít ảnh hơn.","Could not read photos or ran out of memory. Try fewer photos."));}
        finally{SetBusy(false);}
    }
    private async void Save()
    {
        if(busy||collage.Photos.Count==0)return;
        var dialog=new SaveFileDialog{Filter=png?"PNG image|*.png":"JPEG image|*.jpg",FileName=$"mosaic-{collage.OutputWidth}x{collage.OutputHeight}",DefaultExt=png?".png":".jpg",AddExtension=true,OverwritePrompt=true};
        if(dialog.ShowDialog(this)!=true)return;
        SetBusy(true);var snapshot=collage;bool format=png;
        try{await Worker.Run(()=>{snapshot.Export(dialog.FileName,format);return true;});status.Text=T("Đã lưu: ","Saved: ")+dialog.FileName;}
        catch(Exception){Notice(T("Không thể lưu ảnh. Hãy thử vị trí khác.","Could not save. Please try another location."));}
        finally{busy=false;editor.IsEnabled=true;}
    }
}
