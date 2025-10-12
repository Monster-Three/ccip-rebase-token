// SPDX-License-Identifier: MIT

// Layout of Contract:
// version
// imports
// interfaces, libraries, contracts
// errors
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title RebaseToken
 * @author Adam
 * @notice This is a cross-chain rebase token that incentivises users to deposit into a vault and gain interest in rewards.
 * @notice The interest rates in the smart contract can oly decrease.
 * @notice Each user will have their own interest rate that is the global interet rate at the time of depositing.
 */
contract RebaseToken is ERC20, Ownable, AccessControl {
    //////////////
    /// errors ///
    //////////////
    error Rebasetoken__InterestRateCanOnlyDecrease(uint256, uint256);

    ///////////////////////
    /// State variables ///
    ///////////////////////

    // 这里为什么表示了利息是0.5个token每秒呢？按照18个位小数点的计数方式，利息不应该是0.5个token每秒的，视频里面为5e10
    uint256 private s_interestrate = 5e10; //(5 * PRECISION_FACTOR) / 1e8,视频里面这样写的
    uint256 private constant PRECISION_FACTOR = 1e18;
    mapping(address => uint256) private s_userInterestRate;
    mapping(address => uint256) private s_userLastUpdatedTimestamp;

    //bytes32的定义?
    /* 
    在 Solidity 中，bytes32 是一种固定大小的字节数组数据类型。
    主要特性
    固定大小： bytes32 精确地表示一个 **32 字节（256 位）**长的数据序列。这意味着它总是占用 32 字节的存储空间，不多也不少。
    字节序列： 它存储的是原始的字节序列，没有特定的编码（比如 UTF-8 字符串）。可以把它想象成一串由 0 和 1 组成的二进制数据，
    但我们通常以十六进制的形式表示它。 */

    //用数字来举例子，说明32字节是什么样的?
    /*
    1 字节是多大？
    首先，要理解 32 字节，我们得从最基本的单位 1 字节 (Byte) 说起。
    1 字节等于 8 位 (Bits)。
    1 位是计算机存储的最小单位，只能表示 0 或 1。
    所以，1 字节可以存储 2的8次方=256 种不同的值。这通常对应于一个 0 到 255 之间的整数，
    或者一个 ASCII 字符（比如字母 'A'，数字 '5'，符号 '$' 等）。
    32 字节是什么样？
    当我说 32 字节时，我们可以把它想象成一个由 32 个“小格子”组成的序列，每个小格子都能装一个字节的信息。
    在计算机和以太坊中，这些字节通常以十六进制（Hexadecimal）的形式表示，因为十六进制更紧凑，也更容易阅读。
    一个十六进制数字（0-9，A-F）代表 4 位，所以两个十六进制数字就可以表示一个字节（8 位）。
    因此，一个 bytes32 的值会看起来像这样：
    0x 后面跟着 64 个十六进制字符。
    举例说明：
    假设你有一个 bytes32 变量，它可能存储了以下值：
    0x76ad9115f793b8273c51f50a2731c34a02d45c61a7b8e90f23d45e6789abcdef01 */

    //uint256也是储存的32字节的数字，对吧
    /* 
    是的，你的理解是完全正确的！
    uint256 也是存储 32 字节的数字。
    在 Solidity 中：
    uint256 代表一个无符号 256 位整数。
    256 位，根据 1 字节 = 8 位的换算关系，正好等于 256/8=32 字节。
    这意味着，无论你是存储一个 bytes32 类型的值（一串原始字节），还是一个 uint256 类型的值（一个大整数），
    它们在以太坊虚拟机（EVM）的存储和内存中都占用 32 字节（或一个 256 位的“字”）。这是 EVM 最基本的数据处理单元。
    所以，虽然它们的“含义”不同（一个是原始字节序列，一个是有符号整数），但它们在底层的存储大小上是相同的。 */

    //32字节为什么是256位呢
    /* 
    32字节之所以是256位，是因为**字节（Byte）和位（Bit）**之间有一个固定的换算关系：
    1 字节 (Byte) = 8 位 (Bits)
    所以，如果你有 32 个字节，那么对应的位数就是：
    32 字节×8 位/字节=256 位 */

    //keccak256函数的作用?
    /* 
    keccak256 的具体作用
    keccak256 函数就是实现了 Keccak-256 算法的哈希函数。它的输出总是一个 bytes32 类型的值（即 32 字节或 256 比特）。
    在 Solidity 和以太坊生态系统中，keccak256 的应用非常广泛：
    1. 数据完整性验证：
    你可以对任何数据（文本、数字、其他合约地址等）计算哈希值。如果数据的哈希值没有改变，就说明数据没有被篡改。这类似于给数据盖一个“指纹”。
    例子： 存储一个文件的哈希值在链上，之后可以验证链下文件的完整性。
    2. 创建唯一标识符：
    由于其抗碰撞性，keccak256 经常用于为各种实体生成唯一的 ID。
    例子： 给NFT（非同质化代币）生成一个唯一的 tokenId，或者为链下数据创建一个唯一的哈希引用。
    .... */
    bytes32 private constant MINT_AND_BURN_FUNCTION =
        keccak256("MINT_AND_BURN_FUNCTION");

    //////////////
    /// Events ///
    //////////////

    event InterestRateSet(uint256);

    /////////////////
    /// Functions ///
    /////////////////

    constructor() ERC20("Rebase Token", "RBT") Ownable(msg.sender) {}

    function grantMintAndBurnRole(address _account) external onlyOwner {
        _grantRole(MINT_AND_BURN_FUNCTION, _account);
    }

    /**
     * @notice Set the interest rate in the contract.
     * @param _newInteretrate The new interest rate to set.
     * @dev The interet rate can only decrease.
     */
    function setInterestRate(uint256 _newInteretrate) public onlyOwner {
        if (_newInteretrate >= s_interestrate) {
            revert Rebasetoken__InterestRateCanOnlyDecrease(
                s_interestrate,
                _newInteretrate
            );
        }
        s_interestrate = _newInteretrate;
        emit InterestRateSet(_newInteretrate);
    }

    /**
     * @notice Get the principle balance of a user. This is the number of tokens that have currently been minted to the user,not including any interest that has accrued since the last time the user interacted with the protocol.
     * @param _user To get the peinciple balance for the user
     * @return The priciple balance of the user
     */
    function principleBalanceOf(address _user) external view returns (uint256) {
        return super.balanceOf(_user);
    }

    /**
     * @notice Mint the user tokens when they deposit into the vault
     * @param _to The user to mint the tokens to
     * @param _amount The amount of tokens to mint
     */
    function mint(
        address _to,
        uint256 _amount,
        uint256 _userInterestRate
    ) external onlyRole(MINT_AND_BURN_FUNCTION) {
        // 假如A合约继承了B合约，A合约可以直接在自己的函数签名里面调用B合约的modifier吗？
        /* 
        是的，可以。
        如果合约 A 继承了合约 B，那么 A 合约可以直接在自己的函数签名中调用 B 合约中定义的 modifier，
        就像这个 modifier 是在 A 合约自己内部定义的一样。
        工作原理:
        当 A 继承 B 时，B 中所有 public 和 internal 的状态变量和函数（包括 modifier）都会被 A 继承。对于 A 来说，
        这些继承来的成员就像是它自己的一部分。
        所以，你不需要使用 super 关键字来引用父合约的 modifier，直接使用 modifier 的名字就行。 */
        _mintAccruedInterest(_to);
        s_userInterestRate[_to] = _userInterestRate;
        //为什么这里没加super关键字呢？
        /* 只有当你在子合约中对一个 virtual 函数进行了 override，并且你希望在 override 后的函数内部执行父合约的原始逻辑时，
        才需要使用 super。 */
        _mint(_to, _amount);
        // 这里是不是应该添加一个更新s_userLastUpdatedTimestamp的语句？
    }

    /**
     * @notice Burn the user tokens when they withdraw from the vault
     * @param _from The user to burn tokens from
     * @param _amount The amount of tokens to burn
     */
    function burn(
        address _from,
        uint256 _amount
    ) external onlyRole(MINT_AND_BURN_FUNCTION) {
        /* 在现实生活中，由于信号有一定的延迟，_mintAccruedInterest可能会少算到一点利息，我们称为dust。
        如果这里的_amount为type(uint256).max的最大值，则会减轻dust的影响 */
        if (_amount == type(uint256).max) {
            _amount = balanceOf(_from);
        }
        _mintAccruedInterest(_from);
        _burn(_from, _amount);
    }

    /**
     * calculate the balance for the user including the interest rate that has accumulated since the last update
     * principle balance + the interest has accrued
     * @param _user The user to calculate the balance for
     * @return the balance for the user including the interest rate that has accumulated since the last update
     */
    function balanceOf(address _user) public view override returns (uint256) {
        /* 
        get the current principle balance of the user ( the number of tokens that have actually been minted to the user)
        multiply the principle balance by the interst rate that has accumulated in the time since the balance has updated */

        // super关键字的作用是在我们继承的合约中找到balanceOf函数，并使用它
        // 如果在这里不加super关键字，会有什么影响呢？
        /* 1. 编译错误：递归调用（Stack Too Deep） 
        如果你的 balanceOf 函数没有super关键字，编译器会识别出这是一个无限递归调用。你的 balanceOf 函数在内部又调用了它自己。
        在 Solidity 中，这会导致栈溢出错误（Stack Too Deep / Out of Gas），因为每次函数调用都会消耗栈空间，最终耗尽交易的 Gas 限制，
        导致交易失败。 
        这就像一个死循环：为了计算 balanceOf(_user)，它又需要计算 balanceOf(_user)，永远也无法得到一个确定的结果。
        2. 逻辑错误：无法获取基础余额
        即使你通过某种方式避免了直接的无限递归（例如，你没有在 balanceOf 内部再次调用 balanceOf，而是尝试直接访问状态变量），
        如果你不调用 super.balanceOf(_user)，你就无法获取到用户在父合约（ERC20）中记录的原始代币余额。
        ERC20 合约中的 balanceOf 函数通常是直接从 _balances 映射中读取数据的：
        // ERC20 合约中的 balanceOf 函数
        function balanceOf(address account) public view virtual returns (uint256) {
            return _balances[account]; // 这里是实际存储的余额
        }
        你的 Rebase 合约的 balanceOf 函数是为了在原始余额的基础上增加利息。如果它不通过 super.balanceOf(_user) 来获取这个“原始余额”，
        它就不知道该从哪里开始计算利息。
        所以，如果去掉 super 关键字，你的函数就会缺少计算的基准值。它会尝试将一个未定义的或错误的初始值乘以利息因子，导致计算结果完全错误，
        无法返回预期的带有利息的余额。*/

        //那super关键字是不是只能在调用函数签名里面有virtual的函数时使用呢？
        /* 是的，你的理解是正确的！
        super 关键字只能用于调用在父合约中被标记为 virtual，并且在当前子合约中被 override 的函数。
        换句话说，super 关键字的存在，就是为了让你在重写（override）一个父合约的 virtual 函数后，如果还需要执行这个父合约的原始逻辑时，
        能够明确地指明“我要调用父合约的那个实现”。
        如果一个父合约的函数没有 virtual 关键字，那么它就不能被子合约重写。在这种情况下，子合约会直接继承并使用这个函数，
        无需（也无法）使用 super 关键字来调用它，因为没有一个“被重写的父函数”需要 super 来区分。 */
        return
            (super.balanceOf(_user) *
                _calculateUserAccumulatedInterestSinceLastUpdated(_user)) /
            PRECISION_FACTOR;
    }

    /**
     * @notice Transfer tokens from one user to another
     * @param _recipient The user to transfer tokens to
     * @param _amount The amount of token to transfer
     * @return True, if the transfer was successful
     */
    function transfer(
        address _recipient,
        uint256 _amount
    ) public override returns (bool) {
        /* this two '_mintAccruedInterest' solve the problem that when msg.sender transfer balance to the '_recipient', it 
        could change the interest rate for '_recipient' */
        _mintAccruedInterest(msg.sender);
        _mintAccruedInterest(_recipient);
        if (_amount == type(uint256).max) {
            _amount == balanceOf(msg.sender);
        }
        if (balanceOf(_recipient) == 0) {
            s_userInterestRate[_recipient] = s_userInterestRate[msg.sender];
        }
        return super.transfer(_recipient, _amount);
    }

    /**
     * @notice Transfer user from one user to another
     * @param _sender The user to transfer tokens from
     * @param _recipient The user to transfer tokens to
     * @param _amount The amount of tokens to transfer
     * @return True, if the transfer was successful
     */
    function transferFrom(
        address _sender,
        address _recipient,
        uint256 _amount
    ) public override returns (bool) {
        _mintAccruedInterest(_sender);
        _mintAccruedInterest(_recipient);
        if (_amount == type(uint256).max) {
            _amount = balanceOf(_sender);
        }
        if (balanceOf(_recipient) == 0) {
            s_userInterestRate[_recipient] = s_userInterestRate[_sender];
        }
        return super.transferFrom(_sender, _recipient, _amount);
    }

    function _calculateUserAccumulatedInterestSinceLastUpdated(
        address _user
    ) internal view returns (uint256 linearInterest) {
        /* 
        We need to calculate the interest that has accumulated since the last update
        This is going to be linear growth with time
        1. Calculate the time since the last update
        2. Calculate the amount of linear growth
        (principle amount) + (principle amount * interest rate * time elapsed) =
        principle amount * (1 + interest rate * time elapsed) (因为要和balanceOf函数里面的计算式对应)
        deposit: 10 tokens
        interest rate: 0.5 tokens per second
        time elapsed is 2 seconds
        10 + (10 * 0.5 * 2 ) = 20 */
        uint256 timeElapsed = block.timestamp -
            s_userLastUpdatedTimestamp[_user];
        linearInterest =
            PRECISION_FACTOR +
            s_userInterestRate[_user] *
            timeElapsed;
    }

    /**
     * @notice Mint the accrued interest to the user since the last they interacted with the protocol
     * @param _user The user to mint the accrued interest for
     */
    function _mintAccruedInterest(address _user) internal {
        /* 
        (1) find their current balance of rebase tokens that have been minted for the user -> principle balance
        (2) calculate their current balance including any interest -> balanceOf
        calculate the number of tokens that need to be minted to the user -> (2) - (1)
        call _mint to mint tokens to the _user
        see the users last updated timestamp */
        uint256 principleBalance = super.balanceOf(_user);
        uint256 balanceIncludingInteret = balanceOf(_user);
        uint256 accruedInterest = balanceIncludingInteret - principleBalance;
        _mint(_user, accruedInterest);
        s_userLastUpdatedTimestamp[_user] = block.timestamp;
    }

    /**
     * @notice Get the interest rate
     * @return The interest rate for the contract
     */
    function getInterestRate() external view returns (uint256) {
        return s_interestrate;
    }

    /**
     * @notice Get the interest rate for the user
     * @param _user The user to get the interest rate for
     * return: The interest rate for the user
     */
    function getUserInteretsRate(
        address _user
    ) public view returns (uint256 interestRate) {
        return s_userInterestRate[_user];
    }
}
