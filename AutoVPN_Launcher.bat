<# : batch script
@echo off
setlocal
set "APP_DIR=%~dp0"
cd /d "%~dp0"

:: 1. Tự động xin quyền Administrator
net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process cmd.exe -ArgumentList '/c \"\"%~f0\"\"' -Verb RunAs"
    exit /b
)

:: 2. Khởi chạy giao diện và tự động giấu cửa sổ CMD
powershell -NoProfile -ExecutionPolicy Bypass -Command "$code = [System.IO.File]::ReadAllText('%~f0'); Invoke-Expression $code"
exit /b
#>

#Requires -Version 5.1

# Ẩn cửa sổ đen CMD ngay lập tức khi mở
Add-Type -Name Win32Utils -Namespace NativeMethods -MemberDefinition '
[DllImport("Kernel32.dll")]
public static extern IntPtr GetConsoleWindow();
[DllImport("user32.dll")]
public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
' -ErrorAction SilentlyContinue

try {
    $consolePtr = [NativeMethods.Win32Utils]::GetConsoleWindow()
    if ($consolePtr -ne [IntPtr]::Zero) {
        [NativeMethods.Win32Utils]::ShowWindow($consolePtr, 0) | Out-Null
    }
} catch { }

Add-Type -AssemblyName PresentationFramework, System.Windows.Forms

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Blue Archive Auto VPN Manager" Height="460" Width="560"
        WindowStartupLocation="CenterScreen" ResizeMode="NoResize"
        Background="#18181B" Foreground="#F4F4F5" FontFamily="Segoe UI">
    <Window.Resources>
        <Style TargetType="TextBox">
            <Setter Property="Background" Value="#27272A"/>
            <Setter Property="Foreground" Value="#FAFAFA"/>
            <Setter Property="BorderBrush" Value="#3F3F46"/>
            <Setter Property="Padding" Value="6,4"/>
            <Setter Property="FontSize" Value="12"/>
            <Setter Property="VerticalContentAlignment" Value="Center"/>
        </Style>
        <Style TargetType="Button">
            <Setter Property="Background" Value="#3B82F6"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Padding" Value="10,6"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Cursor" Value="Hand"/>
        </Style>
    </Window.Resources>

    <Grid Margin="20">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <StackPanel Grid.Row="0" Margin="0,0,0,18">
            <TextBlock Text="Blue Archive Auto VPN" FontSize="20" FontWeight="Bold" Foreground="#60A5FA"/>
            <TextBlock Text="Tự động bật/tắt WireGuard khi phát hiện tiến trình game" FontSize="12" Foreground="#A1A1AA" Margin="0,3,0,0"/>
        </StackPanel>

        <StackPanel Grid.Row="1" Margin="0,0,0,14">
            <TextBlock Text="Đường dẫn WireGuard.exe:" FontSize="12" FontWeight="SemiBold" Margin="0,0,0,5"/>
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="80"/>
                </Grid.ColumnDefinitions>
                <TextBox Name="txtWgExe" Grid.Column="0" Margin="0,0,8,0"/>
                <Button Name="btnBrowseWg" Content="Tìm..." Grid.Column="1" Background="#3F3F46"/>
            </Grid>
        </StackPanel>

        <StackPanel Grid.Row="2" Margin="0,0,0,14">
            <TextBlock Text="File cấu hình WireGuard (.conf):" FontSize="12" FontWeight="SemiBold" Margin="0,0,0,5"/>
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="80"/>
                </Grid.ColumnDefinitions>
                <TextBox Name="txtConf" Grid.Column="0" Margin="0,0,8,0"/>
                <Button Name="btnBrowseConf" Content="Chọn..." Grid.Column="1" Background="#3F3F46"/>
            </Grid>
        </StackPanel>

        <StackPanel Grid.Row="3" Margin="0,0,0,18">
            <TextBlock Text="Tên tiến trình game (mặc định: BlueArchive.exe):" FontSize="12" FontWeight="SemiBold" Margin="0,0,0,5"/>
            <TextBox Name="txtProc" Text="BlueArchive.exe"/>
        </StackPanel>

        <Border Grid.Row="4" Background="#27272A" CornerRadius="6" Padding="12" Margin="0,0,0,18">
            <TextBlock Name="txtStatus" Text="Trạng thái: Đang sẵn sàng..." FontSize="12" Foreground="#34D399" TextWrapping="Wrap" VerticalAlignment="Center"/>
        </Border>

        <!-- Khung 3 nút bấm -->
        <Grid Grid.Row="5">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>
            <Button Name="btnInstall" Content="Cài đặt &amp; Chạy ngầm" Grid.Column="0" Margin="0,0,4,0" Background="#2563EB" Height="36"/>
            <Button Name="btnOpenTask" Content="Mở Task Scheduler" Grid.Column="1" Margin="4,0,4,0" Background="#4B5563" Height="36"/>
            <Button Name="btnUninstall" Content="Gỡ bỏ hoàn toàn" Grid.Column="2" Margin="4,0,0,0" Background="#DC2626" Height="36"/>
        </Grid>
    </Grid>
</Window>
"@

$reader = (New-Object System.Xml.XmlNodeReader $xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

$txtWgExe      = $window.FindName("txtWgExe")
$txtConf       = $window.FindName("txtConf")
$txtProc       = $window.FindName("txtProc")
$txtStatus     = $window.FindName("txtStatus")
$btnBrowseWg   = $window.FindName("btnBrowseWg")
$btnBrowseConf = $window.FindName("btnBrowseConf")
$btnInstall    = $window.FindName("btnInstall")
$btnOpenTask   = $window.FindName("btnOpenTask")
$btnUninstall  = $window.FindName("btnUninstall")

# Tự dò WireGuard mặc định
$defaultWgPaths = @("C:\Program Files\WireGuard\wireguard.exe", "C:\Program Files (x86)\WireGuard\wireguard.exe")
foreach ($p in $defaultWgPaths) {
    if (Test-Path -LiteralPath $p) {
        $txtWgExe.Text = $p
        break
    }
}

$txtConf.Text = ""

# Tự nhận file .conf cùng thư mục nếu có
$batDir = $env:APP_DIR
if ($batDir -and (Test-Path -LiteralPath $batDir)) {
    $localConf = Get-ChildItem -LiteralPath $batDir -Filter "*.conf" -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -notlike "*DiskSnapshot*" } | Select-Object -First 1
    if ($localConf) { 
        $txtConf.Text = $localConf.FullName 
    }
}

$btnBrowseWg.Add_Click({
    $dlg = New-Object System.Windows.Forms.OpenFileDialog
    $dlg.Filter = "WireGuard Executable (wireguard.exe)|wireguard.exe|All Files (*.*)|*.*"
    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { 
        $txtWgExe.Text = $dlg.FileName 
    }
})

$btnBrowseConf.Add_Click({
    $dlg = New-Object System.Windows.Forms.OpenFileDialog
    $dlg.Filter = "WireGuard Config (*.conf)|*.conf|All Files (*.*)|*.*"
    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { 
        $txtConf.Text = $dlg.FileName 
    }
})

# Nút mở Task Scheduler trực tiếp
$btnOpenTask.Add_Click({
    try {
        Start-Process "taskschd.msc"
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Không thể mở Task Scheduler: $($_.Exception.Message)", "Lỗi", 0, 16)
    }
})

# Nút Cài đặt & Tự dọn sạch bản cũ trước khi chạy
$btnInstall.Add_Click({
    $wg = $txtWgExe.Text.Trim()
    $cf = $txtConf.Text.Trim()
    $pr = $txtProc.Text.Trim() -replace '\.exe$', ''

    if (-not (Test-Path -LiteralPath $wg)) {
        [System.Windows.Forms.MessageBox]::Show("Không tìm thấy wireguard.exe! Hãy bấm nút 'Tìm...' để chọn.", "Thiếu thông tin", 0, 16)
        return
    }
    if ([string]::IsNullOrWhiteSpace($cf) -or -not (Test-Path -LiteralPath $cf)) {
        [System.Windows.Forms.MessageBox]::Show("Bạn chưa chọn file .conf! Hãy bấm nút 'Chọn...' để trỏ tới file VPN.", "Thiếu thông tin", 0, 16)
        return
    }

    $tunnelName = [System.IO.Path]::GetFileNameWithoutExtension($cf)
    $appDataDir = Join-Path $env:APPDATA "BA_AutoVPN"
    if (-not (Test-Path -LiteralPath $appDataDir)) { New-Item -ItemType Directory -Path $appDataDir -Force | Out-Null }

    $targetConf = Join-Path $appDataDir "$tunnelName.conf"
    Copy-Item -LiteralPath $cf -Destination $targetConf -Force

    $runnerScript = Join-Path $appDataDir "runner.ps1"
    $scriptContent = @"
`$mutex = New-Object System.Threading.Mutex(`$false, "BA_AutoVPN_Instance_Mutex")
if (-not `$mutex.WaitOne(0, `$false)) { exit }

`$vpnOn = `$false
while (`$true) {
    `$proc = Get-Process -Name "$pr" -ErrorAction SilentlyContinue
    if (`$proc -and -not `$vpnOn) {
        & "$wg" "/installtunnelservice" "$targetConf"
        `$vpnOn = `$true
    }
    elseif (-not `$proc -and `$vpnOn) {
        & "$wg" "/uninstalltunnelservice" "$tunnelName"
        `$vpnOn = `$false
    }
    Start-Sleep -Seconds 2
}
"@
    Set-Content -LiteralPath $runnerScript -Value $scriptContent -Encoding UTF8

    $taskName = "BA_AutoVPN_Task"
    
    # 1. Dập sạch task và tiến trình ngầm cũ giải phóng Mutex
    Stop-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -like "*BA_AutoVPN*" } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
    Start-Sleep -Milliseconds 500

    # 2. Đăng ký task mới và khởi chạy ngay lập tức
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$runnerScript`""
    $trigger = New-ScheduledTaskTrigger -AtLogOn
    $principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet -Hidden -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit ([TimeSpan]::Zero)

    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings | Out-Null
    Start-ScheduledTask -TaskName $taskName

    $txtStatus.Text = "Trạng thái: ĐÃ CÀI ĐẶT THÀNH CÔNG! Task đang Running."
    $txtStatus.Foreground = [System.Windows.Media.Brushes]::LimeGreen
    [System.Windows.Forms.MessageBox]::Show("Cài đặt thành công! Tiến trình cũ đã được dọn sạch và Task mới đang ở trạng thái Running.", "Thông báo", 0, 64)
})

# Nút Gỡ bỏ
$btnUninstall.Add_Click({
    $taskName = "BA_AutoVPN_Task"
    Stop-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    
    Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -like "*BA_AutoVPN*" } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }

    $appDataDir = Join-Path $env:APPDATA "BA_AutoVPN"
    if (Test-Path -LiteralPath $appDataDir) { Remove-Item -LiteralPath $appDataDir -Recurse -Force -ErrorAction SilentlyContinue }

    $txtStatus.Text = "Trạng thái: Đã gỡ bỏ toàn bộ dịch vụ và tiến trình ngầm."
    $txtStatus.Foreground = [System.Windows.Media.Brushes]::OrangeRed
    [System.Windows.Forms.MessageBox]::Show("Đã gỡ bỏ thành công!", "Thông báo", 0, 64)
})

$window.ShowDialog() | Out-Null