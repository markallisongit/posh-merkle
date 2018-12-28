function Get-HashcodeFromHexString {
    # Returns a SHA256 Hash from a Hex String input
	[CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true)][string] $HexString
    )
    $Bytes = [byte[]]::new($HexString.Length / 2)

    For($i=0; $i -lt $HexString.Length; $i+=2){
        $Bytes[$i/2] = [convert]::ToByte($HexString.Substring($i, 2), 16)
    }    
    $Bytes = [System.Security.Cryptography.HashAlgorithm]::Create("SHA256").ComputeHash( $Bytes )   
    -join ([byte[]]$Bytes |  foreach {$_.ToString("x2") } )
}

function Reverse-HexString {
    # reverses a Hex String and outputs either a byte array or hex string
	[CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true)][string] $HexString,
        [switch] $AsString
    )
    $Bytes = [byte[]]::new($HexString.Length / 2)

    For($i=0; $i -lt $HexString.Length; $i+=2){
        $Bytes[$i/2] = [convert]::ToByte($HexString.Substring($i, 2), 16)
    }
    [array]::Reverse($Bytes)
    if($AsString) {
        -join ([byte[]]$Bytes |  foreach {$_.ToString("x2") } )
    } else {
        $Bytes
    }
}

Function Get-HashOfTwo
{
    # reverses two input hashes, 
    # concatenates them,
    # then hashes them twice
    # then reverses the byte order before returning as hex string
    [cmdletbinding()]
    param (
        [string]$leftHash,
        [string]$rightHash
    )
    $left = Reverse-HexString ($leftHash) -AsString
    $right = Reverse-HexString ($rightHash) -AsString
    return Get-HashcodeFromHexString (Get-HashcodeFromHexString ($left + $right)) -Reverse
}

Function Get-MerkleRoot {
<#
.SYNOPSIS 
Gets the Merkle Root of a list of hashes - order is very important.

.DESCRIPTION
Returns the root hash of a binary hash tree starting with a list of leaf hashes

.PARAMETER hashList
An array of hashes as strings as the leaf hashes

.NOTES
reference https://gist.github.com/shirriff/c9fb5d98e6da79d9a772#file-merkle-py

.EXAMPLE   
Get-MerkleRoot $txids
#> 

    [cmdletbinding()]
    param (
        [string[]]$hashList # an array of hashes (txids)
    )
    Write-Verbose "Number of hashes in array: $($hashlist.Length)"

    # if we only have 1 item left, return it as the answer
    if ($hashList.Length -eq 1) {
        return $hashList[0]
    }

    # create the next level in the merkle tree
    $newHashList = New-Object System.Collections.Generic.List[System.String]

    # for each pair of hashes, add them together and append the result to a new array
    for ($i = 0; $i -lt ($hashList.Length - 1); $i = $i + 2)  {
        # now double hash the two together and reverse the byte order of the second hash
        $newHash = Get-HashOfTwo $hashList[$i] $hashList[$i+1]
        $newHashList.Add($newHash)
    }

    # we have an odd number of hashes, let's hash the last item twice.
    if (($hashList.Length % 2) -eq 1) {     
        Write-Verbose "Odd number hashes, hashing this one twice: $($hashList[$hashList.Length-1])"
        $oddHash = $hashList[$hashList.Length-1] 
        $newHash = Get-HashOfTwo $oddHash $oddHash
        $newHashList.Add($newHash)
    }

    # now run the function again for the next level
    Get-MerkleRoot ($newHashList)
}

Function Get-TxidsForBlock 
{
    # gets a list of txids from a block
    [cmdletbinding()]
    param (
        [int]$height,
        [string]$apiKey
    )

    # get all txids for block height $height
    $bitDbQuery = @"
{
    "v": 3,
    "q": {
        "find": { "blk.i": $height },
        "limit": 100000
    },
    "r": {
        "f": "[ .[] | {txid: .tx.h}]"
    }
}
"@

    $EncodedText = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($bitDbQuery))
    $uri = "https://bitgraph.network/q/" + $EncodedText
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("key", $apiKey)
    $response = Invoke-RestMethod -Method GET -Uri $uri -Headers $headers
    return $response.c
}


$apiKey = "<insert your api key here - get from bitdb website>"
$txids = (Get-TxidsForBlock -height 562776 -apikey $apiKey).txid
[array]::Reverse($txids) # we need to reverse the tx order from bitdb
$txids.Count # how many tx's are in the block
Get-MerkleRoot $txids 