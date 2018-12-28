# posh-merkle
Calculates the merkle root of a list of bitcoin transaction hashes. This repo was created so I could learn how to calculate a merkle root hash for bitcoin.

## Function List

### Get-HashcodeFromHexString
This hashes a hash, where the original hash is a hex string.

### Reverse-HexString
There's a lot of big-endian/little-endian reversals going on in bitcoin. This function helps with that.

### Get-HashOfTwo
This function reverses two input hashes using `Reverse-HexString`, then concatenates them. They are then hashed twice and the output reversed.

### Get-MerkleRoot
This function takes an array of transaction Ids as an input and calculates the merkle root using the helper functions above.

### Get-TxIdsForBlock
To make testing easier, this function gets a list of transactions for a block height from bitdb. If you want to try it out, you'll need to get an API key from their website at https://bitdb.network/v3/dashboard

## Example
```PowerShell
$apiKey = "qz9sy33xjt2zgjtsn3klcgy7rzpv0kwlvc2fl3akm8"
$txids = (Get-TxidsForBlock -height 562776 -apikey $apiKey).txid
[array]::Reverse($txids) # we need to reverse the tx order from bitdb
$txids.Count # how many tx's are in the block
Get-MerkleRoot $txids 
```
Output

```
39
a01e9f35707678e7d1405ccfbe49df8152f365eb7891d7f342f75606ebeef48b
```

This means there were 39 transactions in block 562776 on the Bitcoin SV chain and the merkle root hash is `a01e9f35707678e7d1405ccfbe49df8152f365eb7891d7f342f75606ebeef48b`

Verification: https://blockchair.com/bitcoin-sv/block/562776