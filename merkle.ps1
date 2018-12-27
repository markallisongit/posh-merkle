Function Get-StringHash
{
<#
.SYNOPSIS 
Gets a hash of a string, default of SHA256

.DESCRIPTION
Returns a hash of an input string as a string

.PARAMETER String
The string you would like to hash

.PARAMETER HashName
The hash algorithm to use, defaults to SHA256

.EXAMPLE   
Get-StringHash "Fox"

returns

f55bd2cdfae7972827638f3691a5bc189199d7cff7188d5ead489afdea0e5403
#>    
    param (
        [String] $String, 
        [String] $HashName = "SHA256"
    )
    $StringBuilder = New-Object System.Text.StringBuilder
    [System.Security.Cryptography.HashAlgorithm]::Create($HashName).ComputeHash([System.Text.Encoding]::UTF8.GetBytes($String)) | foreach {
        [Void]$StringBuilder.Append($_.ToString("x2"))
    }
    $StringBuilder.ToString()
}

Function Get-MerkleRoot {
<#
.SYNOPSIS 
Gets the Merkle Root of a list of hashes

.DESCRIPTION
Returns the root hash of a binary hash tree starting with a list of leaf hashes

.PARAMETER hashList
An array of hashes as strings as the leaf hashes

.EXAMPLE   
Get-MerkleRoot $txids
#> 
    # adapted from https://gist.github.com/shirriff/c9fb5d98e6da79d9a772#file-merkle-py
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
        $hashThis = $hashList[$i] + $hashList[$i+1]
        Write-Verbose "Hashing this: $hashThis"
        $newHash = Get-StringHash($hashThis)
        $newHashList.Add($newHash)
    }

    # we have an odd number of hashes, let's hash the last item twice.
    if ($hashList.Length % 2 -eq 1) {     
        Write-Verbose "Odd number hashes, hashing this one twice: $($hashList[$hashList.Length-1])"
        $oddHash = Get-StringHash($hashList[$hashList.Length-1])        
        $newHashList.Add($oddHash)
    }

    # now run the function again for the next level
    Get-MerkleRoot ($newHashList)
}



Function Get-TxidsForBlock 
{
    [cmdletbinding()]
    param (
        [int]$height,
        [string]$chain="BSV",
        [string]$apiKey = "qzwng80rjs8juu0kukq9zwmx4q7gc83gxyvu9da92p"
    )

    # get all txids for block height $height
    $bitDbQuery = @"
{
    "v": 3,
    "q": {
        "find": { "blk.i": $height },
        "limit": 100
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
    $response.c

    # ewogICAgInYiOiAzLAogICAgInEiOiB7CiAgICAgICAgImZpbmQiOiB7ICJibGsuaSI6IDU2MjY5NiB9LAogICAgICAgICJsaW1pdCI6IDEwMAogICAgfSwKICAgICJyIjogewogICAgICAgICJmIjogIlsgLltdIHwge3R4aWQ6IC50eC5ofV0iCiAgICB9Cn0
}

$txids = Get-TxidsForBlock -height 525471 -Verbose

Get-MerkleRoot $txids.txid -Verbose