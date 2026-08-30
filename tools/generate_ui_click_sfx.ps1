param(
	[string]$OutputPath = "assets/audio/ui_click.wav"
)

$sampleRate = 44100
$durationSeconds = 0.085
$sampleCount = [int]($sampleRate * $durationSeconds)
$outputDirectory = Split-Path -Parent $OutputPath

if ($outputDirectory) {
	New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
}

$stream = [System.IO.File]::Open($OutputPath, [System.IO.FileMode]::Create)
$writer = [System.IO.BinaryWriter]::new($stream)
try {
	$bytesPerSample = 2
	$dataSize = $sampleCount * $bytesPerSample
	$writer.Write([System.Text.Encoding]::ASCII.GetBytes("RIFF"))
	$writer.Write([int](36 + $dataSize))
	$writer.Write([System.Text.Encoding]::ASCII.GetBytes("WAVEfmt "))
	$writer.Write([int]16)
	$writer.Write([int16]1)
	$writer.Write([int16]1)
	$writer.Write([int]$sampleRate)
	$writer.Write([int]($sampleRate * $bytesPerSample))
	$writer.Write([int16]$bytesPerSample)
	$writer.Write([int16]16)
	$writer.Write([System.Text.Encoding]::ASCII.GetBytes("data"))
	$writer.Write([int]$dataSize)

	for ($index = 0; $index -lt $sampleCount; $index++) {
		$time = $index / [double]$sampleRate
		$progress = $time / $durationSeconds
		$frequency = 1580.0 - (740.0 * $progress)
		$envelope = [Math]::Exp(-38.0 * $progress)
		$attack = [Math]::Min(1.0, $time / 0.002)
		$body = [Math]::Sin(2.0 * [Math]::PI * $frequency * $time)
		$chime = 0.28 * [Math]::Sin(2.0 * [Math]::PI * ($frequency * 2.01) * $time)
		$sample = [Math]::Tanh(($body + $chime) * $envelope * $attack * 0.42)
		$writer.Write([int16]($sample * [int16]::MaxValue))
	}
}
finally {
	$writer.Dispose()
}
