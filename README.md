# Cross-chain Rebase Token

1. Protocol that allows user to deposit into a vault and in return. receiver rebase 
   tokens that represent their their underlying balance
2. Rebase token -> balanceOf function is dynamic to show the chaging balance with time. 
   1. Balnce increases linearly with time.
   2. Mint tokens to our users every time they perform an action (minting, burning, 
   transferring, or.... bridging)
3. Interest rate 
   1. Indivaully set an interet rate or each user based on some global interest rate of 
   the protocol at the time the user deposits into the vault.
   2. This global interest rate can only decrease to incentivise/reward early adopters.
   3. Increase token adoption!

# 这个协议已知的一些缺陷
1. 当调用ERC20.sol里的totalSupply函数(也就是Rebasetoken.sol里面的principleBalanceOf函数)时，它只会显示已经铸造的代币，而不包括其产生的利息。
2. Owner可以将"MINT_AND_BURN_ROLE"的权限给任何人，包括他自己，这有点中心化。(RebaseToken.sol里面的grantMintAndBurnRole函数)

# bug
1. 假如我们想转账给alice，但是alice并没有往这个协议里存入任何代币，那么Alice就会继承我们的利率(RebaseToken.sol-transfer-if(balanceOf(_recipient == 0))，如果没有这个if语句，就会导致我们转给Alice的代币的利率为0.当然，也可以将s_userInterestRate[msg.sender]设置为当前利率，这时候就需要权衡一下两种方案的利弊了)。 
2. 当调用Rebasetoken.sol里的transfer函数时，账户A转给账户B，假如账户B的利率更低，那么账户A转给账户B的钱将会以账户B的利率存储，那么反过来，如果账户B转给账户A，假如账户A的利率更高，则账户B转给账户A的钱将会以账户A的利率存储。
