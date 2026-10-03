using System.IO;
using System.Text.Json;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using Microsoft.Win32;
namespace Mosaic;

internal sealed class Settings
{
    public string Language { get; set; }="vi";
    public string Theme { get; set; }="system";
    private static string PathName => Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),"Mosaic","settings.json");
    internal static Settings Load() { try{return JsonSerializer.Deserialize<Settings>(File.ReadAllText(PathName))??new();}catch{return new();} }
    internal void Save() { try{Directory.CreateDirectory(Path.GetDirectoryName(PathName)!);File.WriteAllText(PathName,JsonSerializer.Serialize(this));}catch(IOException){}catch(UnauthorizedAccessException){} }
    internal bool Dark => Theme=="dark" || (Theme=="system" && (int?)Registry.GetValue(@"HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize","AppsUseLightTheme",1)==0);
}
internal static class Worker
{
    // Rendering and WIC codec objects stay on one STA; only frozen bitmaps cross threads.
    internal static Task<T> Run<T>(Func<T> action)
    {
        var completion=new TaskCompletionSource<T>(TaskCreationOptions.RunContinuationsAsynchronously);
        var thread=new Thread(()=>{try{completion.SetResult(action());}catch(Exception error){completion.SetException(error);}}){IsBackground=true};
        thread.SetApartmentState(ApartmentState.STA);thread.Start();return completion.Task;
    }
}
internal sealed class MosaicApplication : Application
{
    [STAThread] public static void Main()
    {
        var app=new MosaicApplication();
        app.Run(new MainWindow());
    }
    internal static void ApplyTheme(bool dark)
    {
        var resources=Current.Resources;
        Color bg=dark?Color.FromRgb(28,28,31):Color.FromRgb(250,250,250);
        Color fg=dark?Colors.WhiteSmoke:Color.FromRgb(30,30,33);
        Color surface=dark?Color.FromRgb(47,47,52):Colors.White;
        var background=new SolidColorBrush(bg);var foreground=new SolidColorBrush(fg);var panel=new SolidColorBrush(surface);
        if(SystemParameters.HighContrast){background=SystemColors.WindowBrush;foreground=SystemColors.WindowTextBrush;panel=SystemColors.ControlBrush;}
        resources["AppBackground"]=background;resources["AppForeground"]=foreground;resources["Panel"]=panel;
        foreach(var type in new[]{typeof(Button),typeof(ComboBox),typeof(TextBox),typeof(ListBox)})
        {
            var style=new Style(type);style.Setters.Add(new Setter(Control.ForegroundProperty,foreground));
            style.Setters.Add(new Setter(Control.BackgroundProperty,panel));style.Setters.Add(new Setter(Control.PaddingProperty,new Thickness(8,5,8,5)));
            style.Setters.Add(new Setter(Control.FontSizeProperty,13.0));resources[type]=style;
        }
    }
}
