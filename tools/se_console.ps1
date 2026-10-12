# Types lines into the Script Extender console window of a running BG3 (WriteConsoleInput; no focus change), each
# followed by Enter. The SE console only takes input after an Enter, so start with an empty line. Output lands in
# the SE runtime log (%LOCALAPPDATA%\Larian Studios\Baldur's Gate 3\Script Extender Logs\Extender Runtime *.log).
# Use "client" at the main menu; commands registered on the server (!fft_*) need "server" and a loaded save.
# Usage: powershell -ExecutionPolicy Bypass -File tools\se_console.ps1 -TargetPid (Get-Process bg3_dx11).Id -Lines "", "server", "!fft_grants"
param([int]$TargetPid, [string[]]$Lines)
Add-Type @"
using System; using System.Runtime.InteropServices;
public class C {
  [DllImport("kernel32.dll")] public static extern bool FreeConsole();
  [DllImport("kernel32.dll")] public static extern bool AttachConsole(uint pid);
  [DllImport("kernel32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr CreateFile(string n, uint a, uint s, IntPtr sa, uint c, uint f, IntPtr t);
  [StructLayout(LayoutKind.Explicit, CharSet=CharSet.Unicode)] public struct KEY {
    [FieldOffset(0)] public ushort EventType;
    [FieldOffset(4)] public int bKeyDown; [FieldOffset(8)] public ushort wRepeatCount;
    [FieldOffset(10)] public ushort wVirtualKeyCode; [FieldOffset(12)] public ushort wVirtualScanCode;
    [FieldOffset(14)] public char UnicodeChar; [FieldOffset(16)] public uint dwControlKeyState; }
  [DllImport("kernel32.dll", CharSet=CharSet.Unicode)] public static extern bool WriteConsoleInput(IntPtr h, KEY[] b, uint n, out uint w);
  public static string Send(uint pid, string text) {
    FreeConsole();
    if (!AttachConsole(pid)) return "attach failed " + Marshal.GetLastWin32Error();
    IntPtr h = CreateFile("CONIN$", 0xC0000000, 3, IntPtr.Zero, 3, 0, IntPtr.Zero);
    var list = new System.Collections.Generic.List<KEY>();
    foreach (char ch in text) {
      ushort vk = (ushort)(ch == '\r' ? 0x0D : 0);
      list.Add(new KEY{EventType=1,bKeyDown=1,wRepeatCount=1,wVirtualKeyCode=vk,UnicodeChar=ch});
      list.Add(new KEY{EventType=1,bKeyDown=0,wRepeatCount=1,wVirtualKeyCode=vk,UnicodeChar=ch});
    }
    uint w; bool ok = WriteConsoleInput(h, list.ToArray(), (uint)list.Count, out w);
    FreeConsole();
    return "wrote " + w + " ok=" + ok;
  }
}
"@
foreach ($l in $Lines) { [C]::Send([uint32]$TargetPid, $l + "`r"); Start-Sleep -Milliseconds 700 }
