function Convert-Base64Image {
    param (
        [Parameter(Mandatory = $true)]
        [string]$base64String,
        [string]$outputPath = [System.IO.Path]::GetTempFileName()
    )
    
    try {
        # Decode the base64 string to a byte array
        $imageBytes = [Convert]::FromBase64String($base64String)
        
        # Write the byte array to a temporary file
        [System.IO.File]::WriteAllBytes($outputPath, $imageBytes)
        
        # Determine platform and use appropriate image resizing approach
        if ($PSVersionTable.PSEdition -eq 'Core') {
            # Check if running on Windows
            if ($IsWindows) {
                # On Windows with PowerShell Core, we can still use System.Drawing
                Add-Type -AssemblyName System.Drawing
                
                $image = [System.Drawing.Image]::FromFile($outputPath)
                $resizedImage = New-Object System.Drawing.Bitmap 64, 64
                $graphics = [System.Drawing.Graphics]::FromImage($resizedImage)
                $graphics.DrawImage($image, 0, 0, 64, 64)
                
                $memoryStream = New-Object System.IO.MemoryStream
                $resizedImage.Save($memoryStream, [System.Drawing.Imaging.ImageFormat]::Png)
                $resizedBytes = $memoryStream.ToArray()
                $resizedBase64 = [Convert]::ToBase64String($resizedBytes)
                
                # Clean up resources
                $graphics.Dispose()
                $resizedImage.Dispose()
                $image.Dispose()
                $memoryStream.Dispose()
            }
            elseif ($IsMacOS) {
                # macOS approach using sips command
                $tempResized = [System.IO.Path]::GetTempFileName()
                $sipsCommand = "sips -Z 64 '$outputPath' --out '$tempResized'"
                $null = Invoke-Expression $sipsCommand
                $resizedBytes = [System.IO.File]::ReadAllBytes($tempResized)
                $resizedBase64 = [Convert]::ToBase64String($resizedBytes)
                
                # Clean up temp file
                if (Test-Path $tempResized) {
                    Remove-Item $tempResized -Force
                }
            }
            else {
                # Linux approach using ImageMagick if available
                if (Get-Command "magick" -ErrorAction SilentlyContinue) {
                    $tempResized = [System.IO.Path]::GetTempFileName()
                    $magickCommand = "magick '$outputPath' -resize 64x64 '$tempResized'"
                    $null = Invoke-Expression $magickCommand
                    $resizedBytes = [System.IO.File]::ReadAllBytes($tempResized)
                    $resizedBase64 = [Convert]::ToBase64String($resizedBytes)
                    
                    # Clean up temp file
                    if (Test-Path $tempResized) {
                        Remove-Item $tempResized -Force
                    }
                }
                else {
                    # Fallback if no image processing tool is available
                    Write-Warning "No image processing library available. Returning original image."
                    $resizedBase64 = [Convert]::ToBase64String($imageBytes)
                }
            }
        }
        else {
            # PowerShell Desktop approach - using System.Drawing
            Add-Type -AssemblyName System.Drawing
            
            $image = [System.Drawing.Image]::FromFile($outputPath)
            $resizedImage = New-Object System.Drawing.Bitmap 64, 64
            $graphics = [System.Drawing.Graphics]::FromImage($resizedImage)
            $graphics.DrawImage($image, 0, 0, 64, 64)
            
            $memoryStream = New-Object System.IO.MemoryStream
            $resizedImage.Save($memoryStream, [System.Drawing.Imaging.ImageFormat]::Png)
            $resizedBytes = $memoryStream.ToArray()
            $resizedBase64 = [Convert]::ToBase64String($resizedBytes)
            
            # Clean up resources
            $graphics.Dispose()
            $resizedImage.Dispose()
            $image.Dispose()
            $memoryStream.Dispose()
        }
        
        return $resizedBase64
    }
    catch {
        Write-Error "Error processing image: $_"
    }
    finally {
        # Clean up temporary file
        if (Test-Path $outputPath) {
            Remove-Item $outputPath -Force
        }
    }
}