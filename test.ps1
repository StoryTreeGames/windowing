$Uri = [uri]'C:\Users\dorkd\Repo\StoryTree\windowing\examples\assets\mixkit-message-pop-alert-2354.mp3';
$Uri2 = [uri]"C:\Users\dorkd\Music\Albums\Metallica - 72 Seasons\01 72 Seasons.mp3";

$ARGS = @'
$MediaPlayer = [Windows.Media.Playback.MediaPlayer, Windows.Media, ContentType = WindowsRuntime]::New();
$MediaSource = [Windows.Media.Core.MediaSource]::CreateFromUri(\"C:\Users\dorkd\Repo\StoryTree\windowing\examples\assets\mixkit-message-pop-alert-2354.mp3\");
$MediaSource.OpenAsync() | Out-Null
while ($MediaSource.State -eq \"Opening\" -or $MediaSource.State -eq \"Initial\") { Start-Sleep -Milliseconds 50 }
$MediaPlayer.Source = $MediaSource
$MediaPlayer.Play();
Start-Sleep -Seconds $MediaPlayer.NaturalDuration.TotalSeconds
'@;
Start-Process -WindowStyle Hidden -FilePath powershell.exe -ArgumentList "-NoProfile", "-Command", $ARGS

#
# do {
#     Start-Sleep -Milliseconds 100 # Adjust sleep duration as needed
# } while ($MediaPlayer.NaturalDuration.HasTimeSpan -and $MediaPlayer.Position -lt $MediaPlayer.NaturalDuration.TimeSpan)
