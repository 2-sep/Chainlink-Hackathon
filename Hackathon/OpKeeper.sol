// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from "./OpenZeppelin/Ownable.sol";
import {Pausable} from "./OpenZeppelin/Pausable.sol";
import "./OpenZeppelin/KeeperCompatible.sol";
import "./OpenZeppelin/IPrediction.sol";

contract OpKeeper is KeeperCompatibleInterface, Ownable, Pausable {
    address public PredictionContract =
        0x412F20f7F218c33f9c45284e6BA82f683D39E310;
    address public register;

    uint256 public constant MaxAheadTime = 30;
    uint256 public aheadTimeForCheckUpkeep = 6;
    uint256 public aheadTimeForPerformUpkeep = 6;

    event NewRegister(address indexed register);
    event NewPredictionContract(address indexed predictionContract);
    event NewAheadTimeForCheckUpkeep(uint256 time);
    event NewAheadTimeForPerformUpkeep(uint256 time);

    constructor() {}

    modifier onlyRegister() {
        require(
            msg.sender == register || register == address(0),
            "Not register"
        );
        _;
    }

    //The logic is consistent with the following performUpkeep function, in order to make the code logic clearer.
    function checkUpkeep(
        bytes calldata
    ) external view override returns (bool upkeepNeeded, bytes memory) {
        if (!paused()) {
            bool genesisStartOnce = IPrediction(PredictionContract)
                .genesisStartOnce();
            bool genesisLockOnce = IPrediction(PredictionContract)
                .genesisLockOnce();
            bool paused = IPrediction(PredictionContract).paused();
            uint256 currentEpoch = IPrediction(PredictionContract)
                .currentEpoch();
            uint256 bufferSeconds = IPrediction(PredictionContract)
                .bufferSeconds();
            IPrediction.Round memory round = IPrediction(PredictionContract)
                .rounds(currentEpoch);
            uint256 lockTimestamp = round.lockTimestamp;

            if (paused) {
                //need to unpause
                upkeepNeeded = true;
            } else {
                if (!genesisStartOnce) {
                    upkeepNeeded = true;
                } else if (!genesisLockOnce) {
                    // Too early for locking of round, skip current job (also means previous lockRound was successful)
                    if (
                        lockTimestamp == 0 ||
                        block.timestamp + aheadTimeForCheckUpkeep <
                        lockTimestamp
                    ) {} else if (
                        lockTimestamp != 0 &&
                        block.timestamp > (lockTimestamp + bufferSeconds)
                    ) {
                        // Too late to lock round, need to pause
                        upkeepNeeded = true;
                    } else {
                        //run genesisLockRound
                        upkeepNeeded = true;
                    }
                } else {
                    if (
                        block.timestamp + aheadTimeForCheckUpkeep >
                        lockTimestamp
                    ) {
                        // Too early for end/lock/start of round, skip current job
                        if (
                            lockTimestamp == 0 ||
                            block.timestamp + aheadTimeForCheckUpkeep <
                            lockTimestamp
                        ) {} else if (
                            lockTimestamp != 0 &&
                            block.timestamp > (lockTimestamp + bufferSeconds)
                        ) {
                            // Too late to end round, need to pause
                            upkeepNeeded = true;
                        } else {
                            //run executeRound
                            upkeepNeeded = true;
                        }
                    }
                }
            }
        }
    }

    function performUpkeep(
        bytes calldata
    ) external override onlyRegister whenNotPaused {
        require(
            PredictionContract != address(0),
            "PredictionContract Not Set!"
        );
        bool genesisStartOnce = IPrediction(PredictionContract)
            .genesisStartOnce();
        bool genesisLockOnce = IPrediction(PredictionContract)
            .genesisLockOnce();
        bool paused = IPrediction(PredictionContract).paused();
        uint256 currentEpoch = IPrediction(PredictionContract).currentEpoch();
        uint256 bufferSeconds = IPrediction(PredictionContract).bufferSeconds();
        IPrediction.Round memory round = IPrediction(PredictionContract).rounds(
            currentEpoch
        );
        uint256 lockTimestamp = round.lockTimestamp;
        if (paused) {
            // unpause operation
            IPrediction(PredictionContract).unpause();
        } else {
            if (!genesisStartOnce) {
                IPrediction(PredictionContract).genesisStartRound();
            } else if (!genesisLockOnce) {
                // Too early for locking of round, skip current job (also means previous lockRound was successful)
                if (
                    lockTimestamp == 0 ||
                    block.timestamp + aheadTimeForPerformUpkeep < lockTimestamp
                ) {} else if (
                    lockTimestamp != 0 &&
                    block.timestamp > (lockTimestamp + bufferSeconds)
                ) {
                    // Too late to lock round, need to pause
                    IPrediction(PredictionContract).pause();
                } else {
                    //run genesisLockRound
                    IPrediction(PredictionContract).genesisLockRound();
                }
            } else {
                if (
                    block.timestamp + aheadTimeForPerformUpkeep > lockTimestamp
                ) {
                    // Too early for end/lock/start of round, skip current job
                    if (
                        lockTimestamp == 0 ||
                        block.timestamp + aheadTimeForPerformUpkeep <
                        lockTimestamp
                    ) {} else if (
                        lockTimestamp != 0 &&
                        block.timestamp > (lockTimestamp + bufferSeconds)
                    ) {
                        // Too late to end round, need to pause
                        IPrediction(PredictionContract).pause();
                    } else {
                        //run executeRound
                        IPrediction(PredictionContract).executeRound();
                    }
                }
            }
        }
    }

    function setRegister(address _register) external onlyOwner {
        //When register is address(0), anyone can execute performUpkeep function
        register = _register;
        emit NewRegister(_register);
    }

    function setPredictionContract(
        address _predictionContract
    ) external onlyOwner {
        require(_predictionContract != address(0), "Cannot be zero address");
        PredictionContract = _predictionContract;
        emit NewPredictionContract(_predictionContract);
    }

    function setAheadTimeForCheckUpkeep(uint256 _time) external onlyOwner {
        require(
            _time <= MaxAheadTime,
            "aheadTimeForCheckUpkeep cannot be more than MaxAheadTime"
        );
        aheadTimeForCheckUpkeep = _time;
        emit NewAheadTimeForCheckUpkeep(_time);
    }

    function setAheadTimeForPerformUpkeep(uint256 _time) external onlyOwner {
        require(
            _time <= MaxAheadTime,
            "aheadTimeForPerformUpkeep cannot be more than MaxAheadTime"
        );
        aheadTimeForPerformUpkeep = _time;
        emit NewAheadTimeForPerformUpkeep(_time);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}
