//SPDX-License-IdentPredictionMaticifier: MIT
pragma solidity ^0.8.0;

// import {Ownable} from "./OpenZeppelin/Ownable.sol";
import {Pausable} from "./OpenZeppelin/Pausable.sol";
import {ReentrancyGuard} from "./OpenZeppelin/ReentrancyGuard.sol";
import {IERC20} from "./OpenZeppelin/IERC20.sol";
import {SafeERC20} from "./OpenZeppelin/SafeERC20.sol";
import {AggregatorV3Interface} from "./OpenZeppelin/AggregatorV3Interface.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {OwnerIsCreator} from "@chainlink/contracts-ccip/src/v0.8/shared/access/OwnerIsCreator.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";

/**
 * @title EggCrowns
 */
contract BaseEggCrowns is Pausable, ReentrancyGuard, OwnerIsCreator {
    using SafeERC20 for IERC20;

    AggregatorV3Interface public oracle;

    bool public genesisLockOnce = false;
    bool public genesisStartOnce = false;

    address public adminAddress; // address of the admin
    address public operatorAddress; // address of the operator
    address public keeperAddress; // address of the keeper

    uint256 public bufferSeconds; // number of seconds for valid execution of a prediction round
    uint256 public intervalSeconds; // interval in seconds between two prediction rounds

    uint256 public minPredictAmount; // minimum predictting amount (denominated in wei)
    uint256 public treasuryFee; // treasury rate (e.g. 200 = 2%, 150 = 1.50%)
    uint256 public treasuryAmount; // treasury amount that was not claimed

    uint256 public currentEpoch; // current epoch for prediction round

    uint256 public oracleLatestRoundId; // converted from uint80 (Chainlink)
    uint256 public oracleUpdateAllowance; // seconds

    uint64 public destinationChainSelector; // 目标链选择器 5790810961207155433
    address public receiver; // 接收者合约地址 0x2F630463096843b0C3709d7bE9D16D69C70E8ad8

    uint256 public constant MAX_TREASURY_FEE = 1000; // 10%

    //        键                  键         值
    mapping(uint256 => mapping(address => PredictInfo)) public ledger;
    //        键        值
    mapping(uint256 => Round) public rounds;
    //        键        值
    mapping(address => uint256[]) public userRounds;

    enum Position {
        Bull,
        Bear
    }

    struct Round {
        uint256 epoch;
        uint256 startTimestamp;
        uint256 lockTimestamp;
        uint256 closeTimestamp;
        int256 lockPrice;
        int256 closePrice;
        uint256 lockOracleId;
        uint256 closeOracleId;
        uint256 totalAmount;
        uint256 bullAmount;
        uint256 bearAmount;
        uint256 rewardBaseCalAmount;
        uint256 rewardAmount;
        bool oracleCalled;
    }

    struct PredictInfo {
        Position position;
        uint256 amount;
        bool claimed; // default false
    }

    event PredictDown(
        address indexed sender,
        uint256 indexed epoch,
        uint256 amount
    );
    event PredictUp(
        address indexed sender,
        uint256 indexed epoch,
        uint256 amount
    );
    event Claim(address indexed sender, uint256 indexed epoch, uint256 amount);
    event EndRound(
        uint256 indexed epoch,
        uint256 indexed roundId,
        int256 price
    );
    event LockRound(
        uint256 indexed epoch,
        uint256 indexed roundId,
        int256 price
    );

    event NewAdminAddress(address admin);
    event NewBufferAndIntervalSeconds(
        uint256 bufferSeconds,
        uint256 intervalSeconds
    );
    event NewMinPredictAmount(uint256 indexed epoch, uint256 minPredictAmount);
    event NewTreasuryFee(uint256 indexed epoch, uint256 treasuryFee);
    event NewOperatorAddress(address operator);
    event NewOracle(address oracle);
    event NewOracleUpdateAllowance(uint256 oracleUpdateAllowance);
    event NewKeeperAddress(address operator);

    event Pause(uint256 indexed epoch);
    event RewardsCalculated(
        uint256 indexed epoch,
        uint256 rewardBaseCalAmount,
        uint256 rewardAmount,
        uint256 treasuryAmount
    );

    event StartRound(uint256 indexed epoch);
    event TokenRecovery(address indexed token, uint256 amount);
    event TreasuryClaim(uint256 amount);
    event Unpause(uint256 indexed epoch);

    // Custom errors to provide more descriptive revert messages.
    error NotEnoughBalance(uint256 currentBalance, uint256 calculatedFees); // Used to make sure contract has enough balance.

    // Event emitted when a message is sent to another chain.
    event MessageSent(
        bytes32 indexed messageId, // The unique ID of the CCIP message.
        uint64 indexed destinationChainSelector, // The chain selector of the destination chain.
        address receiver, // The address of the receiver on the destination chain.
        address feeToken, // the token address used to pay CCIP fees.
        uint256 fees // The fees paid for sending the CCIP message.
    );

    modifier onlyAdmin() {
        require(msg.sender == adminAddress, "Not admin");
        _;
    }

    modifier onlyAdminOrOperatorOrKeeper() {
        require(
            msg.sender == adminAddress ||
                msg.sender == operatorAddress ||
                msg.sender == keeperAddress,
            "Not operator/admin/keeper"
        );
        _;
    }

    modifier onlyKeeperOrOperator() {
        require(
            msg.sender == keeperAddress || msg.sender == operatorAddress,
            "Not keeper/operator"
        );
        _;
    }

    modifier onlyOperator() {
        require(msg.sender == operatorAddress, "Not operator");
        _;
    }

    modifier notContract() {
        require(!_isContract(msg.sender), "Contract not allowed");
        require(msg.sender == tx.origin, "Proxy contract not allowed");
        _;
    }

    IRouterClient private s_router;

    LinkTokenInterface private s_linkToken;

    /**
     * @notice Constructor
     * @param _oracleAddress: oracle address
     * @param _adminAddress: admin address
     * @param _operatorAddress: operator address
     * @param _intervalSeconds: number of time within an interval
     * @param _bufferSeconds: buffer of time for resolution of price
     * @param _minPredictAmount: minimum predict amounts (in wei)
     * @param _oracleUpdateAllowance: oracle update allowance
     * @param _treasuryFee: treasury fee (1000 = 10%)
     */
    constructor(
        address _oracleAddress,
        address _adminAddress,
        address _operatorAddress,
        uint256 _intervalSeconds,
        uint256 _bufferSeconds,
        uint256 _minPredictAmount,
        uint256 _oracleUpdateAllowance,
        uint256 _treasuryFee,
        address _router,
        address _link,
        uint64 _destinationChainSelector,
        address _receiver
    ) {
        require(_treasuryFee <= MAX_TREASURY_FEE, "Treasury fee too high");

        oracle = AggregatorV3Interface(_oracleAddress);
        adminAddress = _adminAddress;
        operatorAddress = _operatorAddress;
        intervalSeconds = _intervalSeconds;
        bufferSeconds = _bufferSeconds;
        minPredictAmount = _minPredictAmount;
        oracleUpdateAllowance = _oracleUpdateAllowance;
        treasuryFee = _treasuryFee;
        s_router = IRouterClient(_router);
        s_linkToken = LinkTokenInterface(_link);
        destinationChainSelector = _destinationChainSelector;
        receiver = _receiver;
    }

    /**
     * @notice Predict bear position
     * @param epoch: epoch
     */
    function predictBear(
        uint256 epoch
    ) external payable whenNotPaused nonReentrant notContract {
        require(epoch == currentEpoch, "Predict is too early/late");
        require(_predictable(epoch), "Round not predictable");
        require(
            msg.value >= minPredictAmount,
            "Predict amount must be greater than minPredictAmount"
        );
        require(
            ledger[epoch][msg.sender].amount == 0,
            "Can only predict once per round"
        );

        // Update round data
        uint256 amount = msg.value;
        Round storage round = rounds[epoch];
        round.totalAmount = round.totalAmount + amount;
        round.bearAmount = round.bearAmount + amount;

        // Update user data
        PredictInfo storage predictInfo = ledger[epoch][msg.sender];
        predictInfo.position = Position.Bear;
        predictInfo.amount = amount;
        userRounds[msg.sender].push(epoch);

        emit PredictDown(msg.sender, epoch, amount);
    }

    function CCIPpredictBear(
        uint256 epoch,
        address user,
        uint256 amount
    ) external nonReentrant {
        // Update round data
        Round storage round = rounds[epoch];
        round.totalAmount = round.totalAmount + amount;
        round.bearAmount = round.bearAmount + amount;

        // Update user data
        PredictInfo storage predictInfo = ledger[epoch][user];
        predictInfo.position = Position.Bear;
        predictInfo.amount = amount;
        userRounds[user].push(epoch);

        emit PredictDown(user, epoch, amount);
    }

    /**
     * @notice Predict bull position
     * @param epoch: epoch
     */
    function predictBull(
        uint256 epoch
    ) external payable whenNotPaused nonReentrant notContract {
        require(epoch == currentEpoch, "Predict is too early/late");
        require(_predictable(epoch), "Round not predictable");
        require(
            msg.value >= minPredictAmount,
            "Predict amount must be greater than minPredictAmount"
        );
        require(
            ledger[epoch][msg.sender].amount == 0,
            "Can only predict once per round"
        );

        // Update round data
        uint256 amount = msg.value;
        Round storage round = rounds[epoch];
        round.totalAmount = round.totalAmount + amount;
        round.bullAmount = round.bullAmount + amount;

        // Update user data
        PredictInfo storage predictInfo = ledger[epoch][msg.sender];
        predictInfo.position = Position.Bull;
        predictInfo.amount = amount;
        userRounds[msg.sender].push(epoch);

        emit PredictUp(msg.sender, epoch, amount);
    }

    function CCIPpredictBull(
        uint256 epoch,
        address user,
        uint256 amount
    ) external nonReentrant {
        // Update round data
        Round storage round = rounds[epoch];
        round.totalAmount = round.totalAmount + amount;
        round.bullAmount = round.bullAmount + amount;

        // Update user data
        PredictInfo storage predictInfo = ledger[epoch][user];
        predictInfo.position = Position.Bull;
        predictInfo.amount = amount;
        userRounds[user].push(epoch);

        emit PredictDown(user, epoch, amount);
    }

    /**
     * @notice Claim reward for an array of epochs
     * @param epochs: array of epochs
     */
    function claim(
        uint256[] calldata epochs
    ) external nonReentrant notContract {
        uint256 reward; // Initializes reward

        for (uint256 i = 0; i < epochs.length; i++) {
            require(
                rounds[epochs[i]].startTimestamp != 0,
                "Round has not started"
            );
            require(
                block.timestamp > rounds[epochs[i]].closeTimestamp,
                "Round has not ended"
            );

            uint256 addedReward = 0;

            // Round valid, claim rewards
            if (rounds[epochs[i]].oracleCalled) {
                require(
                    claimable(epochs[i], msg.sender),
                    "Not eligible for claim"
                );
                Round memory round = rounds[epochs[i]];
                addedReward =
                    (ledger[epochs[i]][msg.sender].amount *
                        round.rewardAmount) /
                    round.rewardBaseCalAmount;
            }
            // Round invalid, refund predict amount
            else {
                require(
                    refundable(epochs[i], msg.sender),
                    "Not eligible for refund"
                );
                addedReward = ledger[epochs[i]][msg.sender].amount;
            }

            ledger[epochs[i]][msg.sender].claimed = true;
            reward += addedReward;

            emit Claim(msg.sender, epochs[i], addedReward);
        }

        if (reward > 0) {
            _safeTransferMatic(address(msg.sender), reward);
        }
    }

    function _sendMessage(
        uint256 epoch,
        uint256 rewardAmount,
        uint256 rewardBaseCalAmount
    ) internal returns (bytes32 messageId) {
        bytes memory functionCall = abi.encodeWithSignature(
            "updateResult(uint256,uint256,uint256)",
            epoch,
            rewardAmount,
            rewardBaseCalAmount
        );
        // Create an EVM2AnyMessage struct in memory with necessary information for sending a cross-chain message
        Client.EVM2AnyMessage memory evm2AnyMessage = Client.EVM2AnyMessage({
            receiver: abi.encode(receiver), // ABI-encoded receiver address
            data: functionCall, // ABI-encoded bytes
            tokenAmounts: new Client.EVMTokenAmount[](0), // Empty array indicating no tokens are being sent
            extraArgs: Client._argsToBytes(
                // Additional arguments, setting gas limit and non-strict sequencing mode
                Client.EVMExtraArgsV1({gasLimit: 200_000, strict: false})
            ),
            // Set the feeToken  address, indicating LINK will be used for fees
            feeToken: address(s_linkToken)
        });

        // Get the fee required to send the message
        uint256 fees = s_router.getFee(
            destinationChainSelector,
            evm2AnyMessage
        );

        if (fees > s_linkToken.balanceOf(address(this)))
            revert NotEnoughBalance(s_linkToken.balanceOf(address(this)), fees);

        // approve the Router to transfer LINK tokens on contract's behalf. It will spend the fees in LINK
        s_linkToken.approve(address(s_router), fees);

        // Send the message through the router and store the returned message ID
        messageId = s_router.ccipSend(destinationChainSelector, evm2AnyMessage);

        // Emit an event with message details
        emit MessageSent(
            messageId,
            destinationChainSelector,
            receiver,
            address(s_linkToken),
            fees
        );

        // Return the message ID
        return messageId;
    }

    /**
     * @notice Start the next round n, lock price for round n-1, end round n-2
     * @dev Callable by operator
     */
    function executeRound() external whenNotPaused onlyKeeperOrOperator {
        require(
            genesisStartOnce && genesisLockOnce,
            "Can only run after genesisStartRound and genesisLockRound is triggered"
        );

        (uint80 currentRoundId, int256 currentPrice) = _getPriceFromOracle();

        oracleLatestRoundId = uint256(currentRoundId);

        // CurrentEpoch refers to previous round (n-1)
        _safeLockRound(currentEpoch, currentRoundId, currentPrice);
        _safeEndRound(currentEpoch - 1, currentRoundId, currentPrice);
        _calculateRewards(currentEpoch - 1);

        // Increment currentEpoch to current round (n)
        currentEpoch = currentEpoch + 1;
        _safeStartRound(currentEpoch);
    }

    /**
     * @notice Lock genesis round
     * @dev Callable by operator
     */
    function genesisLockRound() external whenNotPaused onlyKeeperOrOperator {
        require(
            genesisStartOnce,
            "Can only run after genesisStartRound is triggered"
        );
        require(!genesisLockOnce, "Can only run genesisLockRound once");

        (uint80 currentRoundId, int256 currentPrice) = _getPriceFromOracle();

        oracleLatestRoundId = uint256(currentRoundId);

        _safeLockRound(currentEpoch, currentRoundId, currentPrice);

        currentEpoch = currentEpoch + 1;
        _startRound(currentEpoch);
        genesisLockOnce = true;
    }

    /**
     * @notice Start genesis round
     * @dev Callable by admin or operator
     */
    function genesisStartRound() external whenNotPaused onlyKeeperOrOperator {
        require(!genesisStartOnce, "Can only run genesisStartRound once");

        currentEpoch = currentEpoch + 1;
        _startRound(currentEpoch);
        genesisStartOnce = true;
    }

    /**
     * @notice called by the admin to pause, triggers stopped state
     * @dev Callable by admin or operator
     */
    function pause() external whenNotPaused onlyAdminOrOperatorOrKeeper {
        _pause();

        emit Pause(currentEpoch);
    }

    /**
     * @notice Claim all rewards in treasury
     * @dev Callable by admin
     */
    function claimTreasury() external nonReentrant onlyAdmin {
        uint256 currentTreasuryAmount = treasuryAmount;
        treasuryAmount = 0;
        _safeTransferMatic(adminAddress, currentTreasuryAmount);
        emit TreasuryClaim(currentTreasuryAmount);
    }

    /**
     * @notice called by the admin to unpause, returns to normal state
     * Reset genesis state. Once paused, the rounds would need to be kickstarted by genesis
     * @dev Callable by admin or operator or keeper
     */
    function unpause() external whenPaused onlyAdminOrOperatorOrKeeper {
        genesisStartOnce = false;
        genesisLockOnce = false;
        _unpause();

        emit Unpause(currentEpoch);
    }

    /**
     * @notice Set buffer and interval (in seconds)
     * @dev Callable by admin
     */
    function setBufferAndIntervalSeconds(
        uint256 _bufferSeconds,
        uint256 _intervalSeconds
    ) external whenPaused onlyAdminOrOperatorOrKeeper {
        require(
            _bufferSeconds < _intervalSeconds,
            "bufferSeconds must be inferior to intervalSeconds"
        );
        bufferSeconds = _bufferSeconds;
        intervalSeconds = _intervalSeconds;

        emit NewBufferAndIntervalSeconds(_bufferSeconds, _intervalSeconds);
    }

    /**
     * @notice Set minPredictAmount
     * @dev Callable by admin
     */
    function setMinPredictAmount(
        uint256 _minPredictAmount
    ) external whenPaused onlyAdminOrOperatorOrKeeper {
        require(_minPredictAmount != 0, "Must be superior to 0");
        minPredictAmount = _minPredictAmount;

        emit NewMinPredictAmount(currentEpoch, minPredictAmount);
    }

    /**
     * @notice Set operator address
     * @dev Callable by admin
     */
    function setOperator(address _operatorAddress) external onlyAdmin {
        require(_operatorAddress != address(0), "Cannot be zero address");
        operatorAddress = _operatorAddress;

        emit NewOperatorAddress(_operatorAddress);
    }

    /**
     * @notice Set keeper address
     * @dev Callable by admin
     */
    function setKeeper(
        address _keeperAddress
    ) external onlyAdminOrOperatorOrKeeper {
        require(_keeperAddress != address(0), "Cannot be zero address");
        keeperAddress = _keeperAddress;

        emit NewKeeperAddress(_keeperAddress);
    }

    /**
     * @notice Set Oracle address
     * @dev Callable by admin
     */
    function setOracle(
        address _oracle
    ) external whenPaused onlyAdminOrOperatorOrKeeper {
        require(_oracle != address(0), "Cannot be zero address");
        oracleLatestRoundId = 0;
        oracle = AggregatorV3Interface(_oracle);

        // Dummy check to make sure the interface implements this function properly
        oracle.latestRoundData();

        emit NewOracle(_oracle);
    }

    /**
     * @notice Set oracle update allowance
     * @dev Callable by admin
     */
    function setOracleUpdateAllowance(
        uint256 _oracleUpdateAllowance
    ) external whenPaused onlyAdminOrOperatorOrKeeper {
        oracleUpdateAllowance = _oracleUpdateAllowance;

        emit NewOracleUpdateAllowance(_oracleUpdateAllowance);
    }

    /**
     * @notice Set treasury fee
     * @dev Callable by admin
     */
    function setTreasuryFee(
        uint256 _treasuryFee
    ) external whenPaused onlyAdminOrOperatorOrKeeper {
        require(_treasuryFee <= MAX_TREASURY_FEE, "Treasury fee too high");
        treasuryFee = _treasuryFee;

        emit NewTreasuryFee(currentEpoch, treasuryFee);
    }

    /**
     * @notice It allows the owner to recover tokens sent to the contract by mistake
     * @param _token: token address
     * @param _amount: token amount
     * @dev Callable by owner
     */
    function recoverToken(address _token, uint256 _amount) external onlyOwner {
        IERC20(_token).safeTransfer(address(msg.sender), _amount);

        emit TokenRecovery(_token, _amount);
    }

    /**
     * @notice Set admin address
     * @dev Callable by owner
     */
    function setAdmin(address _adminAddress) external onlyOwner {
        require(_adminAddress != address(0), "Cannot be zero address");
        adminAddress = _adminAddress;

        emit NewAdminAddress(_adminAddress);
    }

    /**
     * @notice Returns round epochs and predict information for a user that has participated
     * @param user: user address
     * @param cursor: cursor
     * @param size: size
     */
    function getUserRounds(
        address user,
        uint256 cursor,
        uint256 size
    ) external view returns (uint256[] memory, PredictInfo[] memory, uint256) {
        uint256 length = size;

        if (length > userRounds[user].length - cursor) {
            length = userRounds[user].length - cursor;
        }

        uint256[] memory values = new uint256[](length);
        PredictInfo[] memory predictInfo = new PredictInfo[](length);

        for (uint256 i = 0; i < length; i++) {
            values[i] = userRounds[user][cursor + i];
            predictInfo[i] = ledger[values[i]][user];
        }

        return (values, predictInfo, cursor + length);
    }

    /**
     * @notice Returns round epochs length
     * @param user: user address
     */
    function getUserRoundsLength(address user) external view returns (uint256) {
        return userRounds[user].length;
    }

    /**
     * @notice Get the claimable stats of specific epoch and user account
     * @param epoch: epoch
     * @param user: user address
     */
    function claimable(uint256 epoch, address user) public view returns (bool) {
        PredictInfo memory predictInfo = ledger[epoch][user];
        Round memory round = rounds[epoch];
        if (round.lockPrice == round.closePrice) {
            return false;
        }
        return
            round.oracleCalled &&
            predictInfo.amount != 0 &&
            !predictInfo.claimed &&
            ((round.closePrice > round.lockPrice &&
                predictInfo.position == Position.Bull) ||
                (round.closePrice < round.lockPrice &&
                    predictInfo.position == Position.Bear));
    }

    /**
     * @notice Get the refundable stats of specific epoch and user account
     * @param epoch: epoch
     * @param user: user address
     */
    function refundable(
        uint256 epoch,
        address user
    ) public view returns (bool) {
        PredictInfo memory predictInfo = ledger[epoch][user];
        Round memory round = rounds[epoch];
        return
            !round.oracleCalled &&
            !predictInfo.claimed &&
            block.timestamp > round.closeTimestamp + bufferSeconds &&
            predictInfo.amount != 0;
    }

    /**
     * @notice Calculate rewards for round
     * @param epoch: epoch
     */
    function _calculateRewards(uint256 epoch) internal {
        require(
            rounds[epoch].rewardBaseCalAmount == 0 &&
                rounds[epoch].rewardAmount == 0,
            "Rewards calculated"
        );
        Round storage round = rounds[epoch];
        uint256 rewardBaseCalAmount;
        uint256 treasuryAmt;
        uint256 rewardAmount;

        // Bull wins
        if (round.closePrice > round.lockPrice) {
            rewardBaseCalAmount = round.bullAmount;
            //no winner , house win
            if (rewardBaseCalAmount == 0) {
                treasuryAmt = round.totalAmount;
            } else {
                treasuryAmt = (round.totalAmount * treasuryFee) / 10000;
            }
            rewardAmount = round.totalAmount - treasuryAmt;
        }
        // Bear wins
        else if (round.closePrice < round.lockPrice) {
            rewardBaseCalAmount = round.bearAmount;
            //no winner , house win
            if (rewardBaseCalAmount == 0) {
                treasuryAmt = round.totalAmount;
            } else {
                treasuryAmt = (round.totalAmount * treasuryFee) / 10000;
            }
            rewardAmount = round.totalAmount - treasuryAmt;
        }
        // House wins
        else {
            rewardBaseCalAmount = 0;
            rewardAmount = 0;
            treasuryAmt = round.totalAmount;
        }
        round.rewardBaseCalAmount = rewardBaseCalAmount;
        round.rewardAmount = rewardAmount;

        // Add to treasury
        treasuryAmount += treasuryAmt;

        _sendMessage(epoch, rewardAmount, rewardBaseCalAmount);

        emit RewardsCalculated(
            epoch,
            rewardBaseCalAmount,
            rewardAmount,
            treasuryAmt
        );
    }

    /**
     * @notice End round
     * @param epoch: epoch
     * @param roundId: roundId
     * @param price: price of the round
     */
    function _safeEndRound(
        uint256 epoch,
        uint256 roundId,
        int256 price
    ) internal {
        require(
            rounds[epoch].lockTimestamp != 0,
            "Can only end round after round has locked"
        );
        require(
            block.timestamp >= rounds[epoch].closeTimestamp,
            "Can only end round after closeTimestamp"
        );
        require(
            block.timestamp <= rounds[epoch].closeTimestamp + bufferSeconds,
            "Can only end round within bufferSeconds"
        );
        Round storage round = rounds[epoch];
        round.closePrice = price;
        round.closeOracleId = roundId;
        round.oracleCalled = true;

        emit EndRound(epoch, roundId, round.closePrice);
    }

    /**
     * @notice Lock round
     * @param epoch: epoch
     * @param roundId: roundId
     * @param price: price of the round
     */
    function _safeLockRound(
        uint256 epoch,
        uint256 roundId,
        int256 price
    ) internal {
        require(
            rounds[epoch].startTimestamp != 0,
            "Can only lock round after round has started"
        );
        require(
            block.timestamp >= rounds[epoch].lockTimestamp,
            "Can only lock round after lockTimestamp"
        );
        require(
            block.timestamp <= rounds[epoch].lockTimestamp + bufferSeconds,
            "Can only lock round within bufferSeconds"
        );
        Round storage round = rounds[epoch];
        round.closeTimestamp = block.timestamp + intervalSeconds;
        round.lockPrice = price;
        round.lockOracleId = roundId;

        emit LockRound(epoch, roundId, round.lockPrice);
    }

    /**
     * @notice Start round
     * Previous round n-2 must end
     * @param epoch: epoch
     */
    function _safeStartRound(uint256 epoch) internal {
        require(
            genesisStartOnce,
            "Can only run after genesisStartRound is triggered"
        );
        require(
            rounds[epoch - 2].closeTimestamp != 0,
            "Can only start round after round n-2 has ended"
        );
        require(
            block.timestamp >= rounds[epoch - 2].closeTimestamp,
            "Can only start new round after round n-2 closeTimestamp"
        );
        _startRound(epoch);
    }

    /**
     * @notice Transfer Matic in a safe way
     * @param to: address to transfer Matic to
     * @param value: Matic amount to transfer (in wei)
     */
    function _safeTransferMatic(address to, uint256 value) internal {
        (bool success, ) = to.call{value: value}("");
        require(success, "TransferHelper: Matic_TRANSFER_FAILED");
    }

    /**
     * @notice Start round
     * Previous round n-2 must end
     * @param epoch: epoch
     */
    function _startRound(uint256 epoch) internal {
        Round storage round = rounds[epoch];
        round.startTimestamp = block.timestamp;
        round.lockTimestamp = block.timestamp + intervalSeconds;
        round.closeTimestamp = block.timestamp + (2 * intervalSeconds);
        round.epoch = epoch;
        round.totalAmount = 0;

        emit StartRound(epoch);
    }

    /**
     * @notice Determine if a round is valid for receiving predicts
     * Round must have started and locked
     * Current timestamp must be within startTimestamp and closeTimestamp
     */
    function _predictable(uint256 epoch) internal view returns (bool) {
        return
            rounds[epoch].startTimestamp != 0 &&
            rounds[epoch].lockTimestamp != 0 &&
            block.timestamp > rounds[epoch].startTimestamp &&
            block.timestamp < rounds[epoch].lockTimestamp;
    }

    /**
     * @notice Get latest recorded price from oracle
     * If it falls below allowed buffer or has not updated, it would be invalid.
     */
    function _getPriceFromOracle() internal view returns (uint80, int256) {
        uint256 leastAllowedTimestamp = block.timestamp + oracleUpdateAllowance;
        (uint80 roundId, int256 price, , uint256 timestamp, ) = oracle
            .latestRoundData();
        require(
            timestamp <= leastAllowedTimestamp,
            "Oracle update exceeded max timestamp allowance"
        );
        // require(
        //     uint256(roundId) > oracleLatestRoundId,
        //     "Oracle update roundId must be larger than oracleLatestRoundId"
        // );
        return (roundId, price);
    }

    /**
     * @notice Returns true if `account` is a contract.
     * @param account: account address
     */
    function _isContract(address account) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }
}
