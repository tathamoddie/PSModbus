[CmdletBinding()]
param
(
    [parameter(Mandatory = $true)]
    [IPAddress]
    $RemoteHost,

    [parameter(Mandatory = $true)]
    [Int32]
    $Port,

    [parameter(Mandatory = $true)]
    [Byte]
    $UnitIdenfitier,

    [parameter(Mandatory = $true)]
    [Int16]
    $Register
)

$ErrorActionPreference = "Stop";

function local:toBytes([Int16]$v)
{
    $b = [System.BitConverter]::GetBytes($v);
    if ([System.BitConverter]::IsLittleEndian)
    {
        # Modbus is always big-endian
        [Array]::Reverse($b);
    }
    return $b;
}

[byte[]] $requestData;
# Unit idenfitier (8-bit)
$requestData += @([byte]$UnitIdenfitier)
# Function code (8-bit)
# 3 = Read Holding Registers
$requestData += @([byte]3)
# Address of first register to read (16-bit)
$requestData += toBytes($Register)
# Number of registers to read (16-bit)
$requestData += (0x00, 0x02)

[byte[]] $request;
# Transaction ID
$request += (0x00, 0x01)
# Protocol = Modbus
$request += (0x00, 0x00)
# Length (16-bit)
$request += toBytes([Int16]($requestData.Length))
# The actual call
$request += $requestData

Write-Debug "Request: $([System.BitConverter]::ToString($request))"

$tcpClient = new-Object System.Net.Sockets.TcpClient($RemoteHost, $Port);
$tcpStream = $tcpClient.GetStream();
$reader = New-Object System.IO.BinaryReader($tcpStream);
$writer = New-Object System.IO.StreamWriter($tcpStream);

Write-Debug "Connected"

$writer.Write([char[]]$request);
$writer.Flush();

Write-Debug "Request sent"

## Read response header
# Transaction ID
$reader.ReadInt16() | Out-Null
# Protocol = Modbus
$reader.ReadInt16() | Out-Null
$responseLength = $reader.ReadInt16()
$responseData = $reader.ReadBytes($responseLength);

Write-Debug "Response: $([System.BitConverter]::ToString($responseData))"

$registerDataByteCount = $responseData[2]
$registerDataBytes = $responseData[3..(3+$registerDataByteCount)]

if ([System.BitConverter]::IsLittleEndian)
{
    # Modbus is always big-endian
    [Array]::Reverse($registerDataBytes);
}

[BitConverter]::ToInt32($registerDataBytes, 0)
