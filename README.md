# Uniswap-V2

## IDEAs

1. 没有流动性就无法进行交易。

## Q&A

### Section 1

Q：Uniswap V2 的核心合约是什么？UniswapV2Pair 合约与 Exchange 合约的区别是什么？  
A：1.Uniswap V2 的核心合约是UniswapV2Pair。"Pair"和"Pool"是可以互换使用的术语，它们指的是同一个合约 - UniswapV2Pair 合约。该合约的主要目的是接收用户的 token ，并使用累积的 token 储备进行交换。这就是为什么它被称为 Pool 合约。每个 UniswapV2Pair 合约只能汇集一对 token ，并且只允许在这两种 token 之间进行交换 - 这就是为什么它被称为"pair"的原因。2. Exchange 合约汇集的一种 token 和 ether，UniswapV2Pair 汇集的是一对 token。

Q：Uniswap V2 的 Core 合约部分主要是什么内容？  
A：1.UniswapV2ERC20 ， 一个扩展的ERC20实现，用于LP代币。它还实现了EIP-2612以支持链下转账的批准。2.UniswapV2Factory - 类似于V1，这是一个工厂合约，用于创建配对合约并作为其注册表。注册表使用 create2 来生成配对地址 - 我们将详细了解其工作原理。3.UniswapV2Pair - 主要合约负责核心逻辑。值得注意的是，工厂只允许创建唯一的交易对，以避免流动性的稀释。

Q：Uniswap V2 的 辅助合约部分主要是什么内容？  
A：periphery 存储库包含多个合约，使得使用Uniswap变得更加便捷。其中之一是 UniswapV2Router ，它是Uniswap用户界面以及其他基于Uniswap的网络和去中心化应用的主要入口。该合约的接口与Uniswap V1中的交易合约非常相似。另一个重要的合约是 UniswapV2Library ，它是一组实现重要计算的辅助函数。

Q：Uniswap V2 为什么设置 reserve0 和 reserve1 跟踪池子的储备？  
A：主要原因是仅依赖ERC20余额会导致价格操纵的可能性：想象一下，有人向一个池子发送大量代币，进行有利的交换，最后将其兑现。为了避免这种情况，我们需要在我们这一方追踪池子的储备，并且需要控制它们何时更新。
问GPT：举例子帮助理解如何进行价格操纵套利？

Q：对于初始的LP金额，Uniswap V2 为什么最终采用了存入金额的几何平均值 `Math.sqrt(amount0 * amount1)` ？  
A：这个决定的主要好处是，这样的公式确保了初始流动性比率不会影响资金池份额的价值。（假设Alice和Bob都想在Uniswap创建一个新的流动性池。Alice选择将100个token0和200个token1存入，Bob选择将200个token0和400个token1存入。尽管Bob投入的金额是Alice的两倍，但是他们选择的token0到token1的比率是相同的，所以无论Alice还是Bob，他们获得的流动性代币的数量是由存入的token0和token1的几何平均数决定的。如果Alice和Bob都在相同的价格（token0/token1的比率）下向池中添加流动性，那么他们得到的每个流动性代币代表的池中份额的价值将会是相同的。无论他们各自投入了多少资金，只要他们的投入比率相同，他们的投入都将有相同的价值。这就是为什么我们说这种设计可以确保初始流动性比率不会影响资金池份额的价值。）

Q：uniswap 在使用 `liquidity = Math.sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY` 计算流动性时，为什么选择取较小的那个?  
A：1.在这段代码中，Uniswap是在计算用户提供流动性后，应该铸造多少流动性代币（liquidity）。这个数量应该与用户提供的资金和池子中已有的资金（储备）成比例。也就是说，如果用户投入的资金占了池子总资金的1%，那么他应该得到1%的流动性代币。2.存款金额与储备比率越接近，差异就越小。因此，如果存款金额的比率不同，LP金额也会不同，其中一个会比另一个大。如果我们选择较大的那个，那么我们将通过提供流动性来激励价格变动，这将导致价格操纵。如果我们选择较小的那个，我们将惩罚不平衡流动性的存款（流动性提供者将获得较少的LP代币）。很明显，选择较小的数字更有利，这就是Uniswap正在做的。（这是因为我们希望激励用户提供平衡的流动性。也就是说，用户提供的两种代币的数量应该与池子中两种代币的数量保持相同的比例。如果用户提供的两种代币的比例与池子的比例不同，那么他将会得到较少的流动性代币。这种设计可以防止用户通过大量提供一种代币来操纵价格。）3.假设池子中有100个代币A和200个代币B，如果用户提供50个代币A和50个代币B，那么他提供的代币A和代币B的比例（1:1）就与池子中的比例（1:2）不同。在这种情况下，用户提供的代币A相对过多，所以他将会得到较少的流动性代币。

Q：对于 `uint256 public totalSupply` ，在 UniswapV2Pair 中，直接使用 `totalSupply` ，在 UniswapV2PairTest 中，为什么需要使用 `totalSupply()` ？  
A：1.在 Solidity 中声明为 public 的状态变量，不能直接从外部访问它们的值，因为外部调用必须通过网络和Ethereum虚拟机(EVM)进行。2.当你从另一个合约或从外部访问一个状态变量时，必须通过其对应的getter函数来进行。Solidity为每个public状态变量自动创建一个公共getter函数。3.当你在同一个合约内部访问一个状态变量时，可以直接访问其值，因为这不涉及任何网络通信或EVM的操作。

### Section 2

Q：为什么 `swap(uint256 amount0Out, uint256 amount1Out, address to)` 中设置 amount0Out 和 amount1Out 两个入参？  
A：该函数接受两个输出金额，每个代币对应一个金额。这些金额是调用者想要用他们的代币交换得到的。为什么要这样做呢？因为我们甚至不想强制交换的方向：调用者可以指定其中一个金额或两个金额，我们将只执行必要的检查。

Q：在uniswap v2中，为什么不使用ERC20接口的 `token0.transfer(to, amount0Out)` ，而使用了 `_safeTransfer(token0, to, amount0Out)` ？  
```solidity
function _safeTransfer(
    address token,
    address to,
    uint256 amount
) private {
    (bool success, bytes memory data) = token.call(abi.encodeWithSignature("transfer(address,uint256)", to, amount));
    // require(success && (data.length == 0 || abi.decode(data, (bool))), "TRANSFER_FAILED");
    if (!success || (data.length != 0 && !abi.decode(data, (bool)))) revert TransferFailed();
}
```  
A：1.在配对合约中，在进行代币转账时，我们总是希望确保转账成功。根据ERC20标准， transfer 方法必须返回一个布尔值： true 表示成功， fails 表示失败。大多数代币都正确实现了这一点，但有些代币没有——它们只是返回了空值。当然，我们无法检查代币合约的实现，并不能确定代币转账是否确实完成，但至少我们可以检查转账结果。如果转账失败，我们不希望继续进行。2. call -- 这是一个低级函数，它可以让我们对合约调用有更精细的控制。在这个特定的情况下，它允许我们无论 transfer 方法是否返回结果，都能得到一个转账的结果。

Q：在 `swap(uint256 amount0Out, uint256 amount1Out, address to)` 中，转账前为什么要进行条件检查？  
```solidity
if (amount0Out > 0) _safeTransfer(token0, to, amount0Out);
if (amount1Out > 0) _safeTransfer(token1, to, amount1Out);
```  
A：1.amount0Out和amount1Out是函数参数，表示从资金池中取出的两种代币的数量。2.检查amount0Out > 0和amount1Out > 0是为了避免无意义的转账。如果要转出的代币数量为0，那么调用_safeTransfer函数就没有意义，只会消耗更多的gas。3.对于某些代币合约来说，尝试转移0个代币可能会引发错误。所以这个检查可以避免不必要的问题和费用。

Q：什么是预言机？  
A：1.将区块链与离链服务连接起来，以便从智能合约中查询现实世界的数据，已经存在了相当长的时间。Chainlink是最大的预言机网络之一，它于2017年创建，如今已成为许多DeFi应用的关键组成部分。2.Uniswap是一个链上应用，同时也可以作为一个预言机。每个经常被交易者使用的Uniswap交易对合约也吸引了套利者，他们通过减小交易所之间的价格差异来赚钱。套利者使得Uniswap的价格尽可能接近中心化交易所的价格，这也可以看作是将中心化交易所的价格输入到区块链中。

Q：Uniswap V2中如何实现预言机？  
A：1.在Uniswap V2中，价格预言机提供的价格类型被称为时间加权平均价格，或者简称为TWAP。它基本上允许在两个时间点之间获得平均价格。为了实现这一点，合约会存储累积价格：在每次交换之前，它会计算当前的边际价格（不包括费用），将其乘以自上次交换以来经过的秒数，并将该数字添加到之前的价格上。2.边际价格 —— 这只是两个储备的关系 `price0 = reserve1 / reserve0, price1 = reserve0 / reserve1`

Q：Uniswap V2中如何实现预言机时为什么使用边际价格？  
A：对于价格预言机功能，Uniswap V2使用边际价格，这些价格不包括滑点和交换费用，也不依赖于交换数量。

Q：Uniswap V2为什么使用 `UQ112.112` 计算边际价格？  
A：Solidity不支持浮点数除法，计算这样的价格可能会很棘手：例如，如果两个储备的比率为 2/3 ，那么价格就是0。在计算边际价格时，我们需要增加精度，而Uniswap V2使用UQ112.112数字来实现这一点。UQ112.112基本上是一个数字，其中112位用于小数部分，112位用于整数部分。

Q：为什么选择112位进行运算？（为什么变量使用类型 uint112 ）
A：气体优化。每个EVM操作都会消耗一定数量的gas。简单的操作，比如算术运算，消耗的gas很少，但有些操作消耗的gas很多。其中最昂贵的操作是 SSTORE -将值保存到合约存储中。它的对应操作 SLOAD 也很昂贵。因此，如果智能合约开发者尝试优化其合约的gas消耗，对用户来说是有益的。使用 uint112 来保留变量正是为了达到这个目的。

Q：为什么在价格计算之前它们被乘以 2**112 ？  
A：`price0CumulativeLast += uint256(UQ112x112.encode(reserve1_).uqdiv(reserve0_)) * timeElapsed` ，储备以UQ112.112数字的整数部分形式存储。UQ112x112.encode 将 uint112 值乘以 2**112 ，使其成为 uint224 值。然后，它被另一个储备除以并乘以 timeElapsed 。结果被加到当前存储的值上，这使其累积。
GPT：举例子帮助理解

Q：计算边际价格时，为什么使用 unchecked 块？  
A：在计算 timeElapsed 和累积价格时，我们使用 unchecked 块。这似乎对合约的安全性不利，但是预计时间戳和累积价格会溢出：当它们中的任何一个溢出时，不会发生任何不良情况。我们希望它们在溢出时不会抛出错误，以便能够正常运行。
GPT：为什么发生溢出不会影响合约？

Q：为什么需要 SafeMath 库？  
A：直到版本0.8.0之前，Solidity没有检查溢出和下溢，于是开发者们想出了一个库：SafeMath。如今，由于Solidity现在在检测到溢出或下溢时会抛出异常，所以这个库已经不再需要了。Solidity 0.8.0还引入了 unchecked 块，顾名思义，它在其范围内禁用了溢出/下溢检测。

### Section 3

Q：为什么需要工厂合约？  
A：1.工厂合约是所有已部署的配对合约的注册表。这个合约是必要的，因为我们**不希望有相同代币的配对，以免流动性分散到多个相同的配对中**。该合约还简化了配对合约的部署过程：不需要手动部署配对合约，只需在工厂合约中调用一个方法即可。2.Uniswap团队只部署了一个工厂合约，该合约作为Uniswap交易对的官方注册表。这在交易对的发现方面也非常有用：我们可以查询合约以通过代币地址找到一个交易对。此外，可以扫描合约事件的历史记录以找到所有部署的交易对。当然，我们也可以手动部署我们的交易对，而不将其注册到工厂合约中。

Q：
A：