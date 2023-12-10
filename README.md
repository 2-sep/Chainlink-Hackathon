# EggCrowns

An Omnichain Predictive Market Platform

## 0x00 Inspiration and Objectives

Challenge in Blockchain Landscape: EggCrowns addresses a common issue in blockchain technology - the restriction of user activities within a single chain, limiting cross-chain interactions.

Objective: To create an omnichain predictive market platform, removing liquidity segmentation barriers and enhancing user engagement across various blockchains.

## 0x01 Technical Architecture

### Predictive Mechanism

EggCrowns extends the Pancake Swap prediction model (originally BNB chain-based) by incorporating cross-chain features, enabling predictive markets across diverse blockchains.We conduct predictions on the price of ETH on both the Base chain and the OP chain, with each round lasting 20 minutes. The details of each round, including the timestamp, oracle price, and total amount, are recorded using the Struct 'Round' . Additionally, personal information is documented using the Struct'PredictInfo'.

Each round goes through three stages. In the 'Predict' stage, players can either 'Enter UP' or 'Enter Down'. The 'LockPrice' is recorded at the end of this stage. During the 'Live' stage, predicting is prohibited, and the 'ClosedPrice' is recorded at the end of this stage. In the 'Expired' stage, winners are determined by comparing the 'ClosedPrice' with the 'LockPrice'.

We utilize ChainLink Automation to assist with the iteration of Rounds. Additionally, we have incorporated the ChainLink Price Oracle service in our code.

```
// BasePredict.sol & OpPredict.sol
executeRound(){
   _getPriceFromOracle() // ChainkLink Price Oracle
   _safeLockRound()
   _safeEndRound()
   _calculateRewards()
   _safeStartRound()
}

// ChainLink Automation:BaseKeeper.sol & OpKeeper.sol
```

### Cross-Chain

We use the Cross-Chain Interoperability Protocol (CCIP) to facilitate the crucial transfer of user prediction information between the OP (Optimism) chain and the BASE hub chain. This ensures consistent game outcomes across different chains. Predictions made by players on the OP chain are not only recorded on the current chain but are also transmitted to the Base chain via CCIP.

The cross-chain delay between OP and BASE is approximately 17 minutes, so we have set the duration of each round to 20 minutes. During the 'live' stage of a round, it is still possible to accept prediction information coming from cross-chain sources. After the end of the 'live' stage, an admin wallet synchronizes the ratio information of each round's outcome back to the OP chain.

## 0x02 Contracts

### Base Goerli

| name          | address                                      | info                                                                                       |
| ------------- | -------------------------------------------- | ------------------------------------------------------------------------------------------ |
| BaseEggCrowns | `0x6620446D71f2C3BbCa00f6E6B4E2249C205a3bbF` | [scanlink](https://goerli.basescan.org/address/0x6620446D71f2C3BbCa00f6E6B4E2249C205a3bbF) |
| BaseKeeper    | `0x9ca96D8967af98a1cA3179c558640Cb709aC51CD` | [scanlink](https://goerli.basescan.org/address/0x9ca96D8967af98a1cA3179c558640Cb709aC51CD) |
| BaseReceiver  | `0x2F630463096843b0C3709d7bE9D16D69C70E8ad8` | [scanlink](https://goerli.basescan.org/address/0x2F630463096843b0C3709d7bE9D16D69C70E8ad8) |

### OP Goerli

| name        | address                                      | info                                                                                                |
| ----------- | -------------------------------------------- | --------------------------------------------------------------------------------------------------- |
| OPEggCrowns | `0xD8E9f98076418d61532D5880068936F368fe99B2` | [scanlink](https://goerli-optimism.etherscan.io/address/0xD8E9f98076418d61532D5880068936F368fe99B2) |
| OPKeeper    | `0xd5eF66B4F8De6B6913D525380a6e3408174d131D` | [scanlink](https://goerli-optimism.etherscan.io/address/0xd5eF66B4F8De6B6913D525380a6e3408174d131D) |
| OPReceiver  | `0x71C9144A499De3AF10d4f50e920120920F2867e7` | [scanlink](https://goerli-optimism.etherscan.io/address/0x71C9144A499De3AF10d4f50e920120920F2867e7) |
