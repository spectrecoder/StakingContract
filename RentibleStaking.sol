// SPDX-License-Identifier: MIT
pragma solidity 0.6.12; 

// 0.6.12+commit.27d51765

import "./@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "./@openzeppelin/contracts/utils/EnumerableSet.sol";
import "./@openzeppelin/contracts/math/SafeMath.sol";
import "./@openzeppelin/contracts/access/Ownable.sol";

// LP token (ERC20 reward) based staking for Rentible
// 
// See: 
// https://rentible.io/ 
// https://staking.rentible.io/ 
// 
// Inspired by:
// https://github.com/SashimiProject/sashimiswap/blob/master/contracts/MasterChef.sol
// https://github.com/ltonetwork

contract RentibleStaking is Ownable { 

    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    /* -------------------------------------------------------------------- */
    /* --- main variables ------------------------------------------------ */
    /* -------------------------------------------------------------------- */

    // when staking starts, unix time
    uint256 public immutable startTime;
    // when staking ends, unix time
    uint256 public immutable endTime;

    // ------

    // Uniswap V2 liquidity token (the staked token)
    IERC20 public immutable lpToken; 

    // Rentible ERC20 token (in our case RNB, as reward)
    IERC20 public immutable erc20;

    // ------

    // NOTE: in the last changes we made 4 real days into one "contract" day!
    // in sec
    uint256 public immutable dayLength;

    // in sec
    uint256 public immutable stakingProgramTimeLength;

    // ------

    // NOTE (!!!): if you modify the array size, please modify max in getCurrentStakingDayNumber() and updateDailyTotalLptAmount() too (to array size - 1)

    // NOTE: in the last changes we made 4 real days into one "contract" day!
    // how many liquidity tokens were in the staking (per day) (add/subtract happens upon deposit, withdraw) (every user combined)
    uint256[93] public dailyTotalLptAmount;

    // liquidity tokens in the staking as of now (every user combined) (add/subtract happens upon deposit, withdraw) (every user combined)
    uint256 public currentTotalLptAmount;

    // ------

    // NOTE (!!!): if you modify the array size, please modify max in getCurrentStakingDayNumber() and updateDailyTotalLptAmount() too (to array size - 1)

    // NOTE: in the last changes we made 4 real days into one "contract" day!

    // total reward, has to equal the sum of the dailyPlannedErc20RewardAmounts (payed out rewards are not subtracted from this)
    uint256 public immutable totalErc20RewardAmount;

    // total reward per "contract" day, planned (practically treated as fixed/immutable, payed out rewards are not subtracted from this))
    // has to be equal to totalErc20RewardAmount (and after full reward funding equal to fundedErc20RewardAmount)
    // note: there is a starting 0 and a closing 0
    uint256[93] public dailyPlannedErc20RewardAmounts = [0, 5753337571515390000000, 5710955710955710000000, 5668573850392040000000, 5626191989828360000000, 5583810129264680000000, 5541428268701000000000, 5499046408137330000000, 5456664547573650000000, 5414282687009970000000, 5371900826446290000000, 5329518965882620000000, 5287137105318940000000, 5244755244755260000000, 5202373384191580000000, 5159991523627910000000, 5117609663064230000000, 5075227802500550000000, 5032845941936870000000, 4990464081373200000000, 4948082220809520000000, 4905700360245840000000, 4863318499682160000000, 4820936639118490000000, 4778554778554810000000, 4736172917991130000000, 4693791057427450000000, 4651409196863780000000, 4609027336300100000000, 4566645475736420000000, 4524263615172740000000, 4481881754609070000000, 4439499894045390000000, 4397118033481710000000, 4354736172918030000000, 4312354312354360000000, 4269972451790680000000, 4227590591227000000000, 4185208730663320000000, 4142826870099650000000, 4100445009535970000000, 4058063148972290000000, 4015681288408610000000, 3973299427844940000000, 3930917567281260000000, 3888535706717580000000, 3846153846153900000000, 3803771985590230000000, 3761390125026550000000, 3719008264462870000000, 3676626403899190000000, 3634244543335510000000, 3591862682771830000000, 3549480822208150000000, 3507098961644470000000, 3464717101080790000000, 3422335240517110000000, 3379953379953430000000, 3337571519389750000000, 3295189658826080000000, 3252807798262400000000, 3210425937698720000000, 3168044077135040000000, 3125662216571360000000, 3083280356007680000000, 3040898495444000000000, 2998516634880320000000, 2956134774316640000000, 2913752913752960000000, 2871371053189280000000, 2828989192625600000000, 2786607332061920000000, 2744225471498250000000, 2701843610934570000000, 2659461750370890000000, 2617079889807210000000, 2574698029243530000000, 2532316168679850000000, 2489934308116170000000, 2447552447552490000000, 2405170586988810000000, 2362788726425130000000, 2320406865861450000000, 2278025005297770000000, 2235643144734100000000, 2193261284170420000000, 2150879423606740000000, 2108497563043060000000, 2066115702479380000000, 2023733841915700000000, 1981351981352020000000, 1938970120788340000000, 0];

    // total reward funded (so far) (payed out rewards are not subtracted from this), 
    // eventually (after funding) has to be equal to totalErc20RewardAmount
    uint256 public fundedErc20RewardAmount = 0;

    // total reward, at start the same as dailyPlannedErc20RewardAmounts, 
    // daily counter, 
    // not yet tied to any UserInfo object, 
    // subtractions happen when reward is assigned to a UserInfo object
    // (rewards are always payed out through UserInfo object, not directly from here!)
    // note: there is a starting 0 and a closing 0
    uint256[93] public dailyErc20RewardAmounts =        [0, 5753337571515390000000, 5710955710955710000000, 5668573850392040000000, 5626191989828360000000, 5583810129264680000000, 5541428268701000000000, 5499046408137330000000, 5456664547573650000000, 5414282687009970000000, 5371900826446290000000, 5329518965882620000000, 5287137105318940000000, 5244755244755260000000, 5202373384191580000000, 5159991523627910000000, 5117609663064230000000, 5075227802500550000000, 5032845941936870000000, 4990464081373200000000, 4948082220809520000000, 4905700360245840000000, 4863318499682160000000, 4820936639118490000000, 4778554778554810000000, 4736172917991130000000, 4693791057427450000000, 4651409196863780000000, 4609027336300100000000, 4566645475736420000000, 4524263615172740000000, 4481881754609070000000, 4439499894045390000000, 4397118033481710000000, 4354736172918030000000, 4312354312354360000000, 4269972451790680000000, 4227590591227000000000, 4185208730663320000000, 4142826870099650000000, 4100445009535970000000, 4058063148972290000000, 4015681288408610000000, 3973299427844940000000, 3930917567281260000000, 3888535706717580000000, 3846153846153900000000, 3803771985590230000000, 3761390125026550000000, 3719008264462870000000, 3676626403899190000000, 3634244543335510000000, 3591862682771830000000, 3549480822208150000000, 3507098961644470000000, 3464717101080790000000, 3422335240517110000000, 3379953379953430000000, 3337571519389750000000, 3295189658826080000000, 3252807798262400000000, 3210425937698720000000, 3168044077135040000000, 3125662216571360000000, 3083280356007680000000, 3040898495444000000000, 2998516634880320000000, 2956134774316640000000, 2913752913752960000000, 2871371053189280000000, 2828989192625600000000, 2786607332061920000000, 2744225471498250000000, 2701843610934570000000, 2659461750370890000000, 2617079889807210000000, 2574698029243530000000, 2532316168679850000000, 2489934308116170000000, 2447552447552490000000, 2405170586988810000000, 2362788726425130000000, 2320406865861450000000, 2278025005297770000000, 2235643144734100000000, 2193261284170420000000, 2150879423606740000000, 2108497563043060000000, 2066115702479380000000, 2023733841915700000000, 1981351981352020000000, 1938970120788340000000, 0];

    // has to be equal to the sum of the dailyErc20RewardAmounts array, payed out rewards are subtracted from this, this is the remaing unassigned reward, not tied to any UserInfo object
    uint256 public currentTotalErc20RewardAmount = 0;

    // ------

    // info of each user (depositor)
    struct UserInfo {

        // NOTE: in the last changes we made 4 real days into one "contract" day!

        uint256 currentlyAssignedRewardAmount; // reward (ERC20 Rentible token) amount, that was already clearly assigned to this UserInfo object (meaning subtracted from dailyErc20RewardAmounts and currentTotalErc20RewardAmount)
        uint256 rewardCountedUptoDay; // the "contract" day (stakingDayNumber) up to which currentlyAssignedRewardAmount was already handled

        uint256 lptAmount;
    }

    // user (UserInfo) mapping
    mapping (address => UserInfo) public userInfo;

    /* -------------------------------------------------------------------- */
    /* --- events --------------------------------------------------------- */
    /* -------------------------------------------------------------------- */

    event Deposit(address indexed user, uint256 depositedLptAmount);
 
    event WithdrawLptCore(address indexed user, uint256 withdrawnLptAmount);
    event TakeOutSomeOfTheAccumulatedReward(address indexed user, uint256 rewardAmountTakenOut);

    event Fund(address indexed ownerUser, uint256 addedErc20Amount);

    /* -------------------------------------------------------------------- */
    /* --- constructor ---------------------------------------------------- */
    /* -------------------------------------------------------------------- */
    
    // https://abi.hashex.org/#
    // 0000000000000000000000005af3176021e2450850377d4b166364e5c52ae82f000000000000000000000000e764f66e9e165cd29116826b84e943176ac8e91c0000000000000000000000000000000000000000000000000000000000000000

    // _startTime = 0: means start instantly upon deploy
    constructor(IERC20 _erc20, IERC20 _lpToken, uint256 _startTime) public {
       
        require(_startTime == 0 || _startTime > 1621041111, "constructor: _startTime is too small");
          
        // ---

        erc20 = _erc20; // RNB (for rewards)
        lpToken = _lpToken; // RNB/ETH Uni V2 (the staked token)

        // ---

        // NOTE: in the last changes we made 4 real days into one contract day
        // variables were parameterized already (for testing etc.) and were not renamed

        uint256 dayLengthT = 345600; // 86400 sec = one day, 345600 sec = 4 days
        // uint256 dayLengthT = 600; // scaled down, for testing, ratio 10 minutes = 4 day

        dayLength = dayLengthT; // this way it can be immutable
        
        // ---

        uint256 startTimeT;
       
        if (_startTime > 0) {
            startTimeT = _startTime;
        } else {
            startTimeT = block.timestamp; // default is current time
        }
        
        startTime = SafeMath.sub(startTimeT, dayLengthT); // this way it can be immutable, we subtract 1 day to skip day 0

        // ---

        // NOTE: in the last changes we made 4 real days into one "contract" day
        // 364 real days = 91 contract days = staking program length

        uint256 stakingProgramTimeLengthT = SafeMath.mul(dayLengthT, 91);

        stakingProgramTimeLength = stakingProgramTimeLengthT; // this way it can be immutable

        // ---

        uint256 endTimeT = SafeMath.add(startTimeT, stakingProgramTimeLengthT); 

        endTime = endTimeT; // this way it can be immutable
        
        // ---

        uint256 totalErc20RewardAmountT = 350000000000000000000000; // 350000 RNB

        totalErc20RewardAmount = totalErc20RewardAmountT; // this way it can be immutable
             
    }

    /* -------------------------------------------------------------------- */
    /* --- basic write operations for the depositors ---------------------- */
    /* -------------------------------------------------------------------- */
    
    // Deposit LP tokens (by the users/investors/depositors)
    function deposit(uint256 _depositLptAmount) public {

        require(_depositLptAmount > 0, "deposit: _depositLptAmount must be positive");

        require(block.timestamp >= startTime, "deposit: cannot deposit yet, current time is before startTime");
        require(block.timestamp < endTime, "deposit: cannot deposit anymore, current time is after endTime");

        // require(fundedErc20RewardAmount == totalErc20RewardAmount, "deposit: please wait until owner funds the rewards");

        // ---
        
        UserInfo storage user = userInfo[msg.sender];

        addToTheUsersAssignedReward();
        
        // ---

        user.lptAmount = SafeMath.add(user.lptAmount, _depositLptAmount);
        lpToken.safeTransferFrom(msg.sender, address(this), _depositLptAmount);

        currentTotalLptAmount = SafeMath.add(currentTotalLptAmount, _depositLptAmount);
        updateDailyTotalLptAmount();
        
        // ---

        emit Deposit(msg.sender, _depositLptAmount);

    }

    function updateDailyTotalLptAmount() private {
        
        // NOTE: in the last changes we made 4 real days into one "contract" day

        uint256 currentStakingDayNumber = getCurrentStakingDayNumber();

        for (uint256 i = currentStakingDayNumber; i <= 92; i++) {
            dailyTotalLptAmount[i] = currentTotalLptAmount;
        } 

    }

    /*
    
    Withdraw variants:

    1) withdrawLptCore(uint256) = emergency withdraw, user receives the param amount of LPT, does not receive RNB, can unrecoverably loose some reward RNB
    2) withdrawWithoutReward(uint256) = user receives the param amount of LPT, plus the method calculates and updates the reward amount in UserInfo object (but leaves it there)
    3) withdrawAllWithoutReward() = same as 3, amount is fixed/all (user.lptAmount)
    4) takeOutSomeOfTheAccumulatedReward(uint256) = leaves deposited LPT untouched, user receives the param amount of rewards
    5) takeOutTheAccumulatedReward() = same as 4, reward amount is fixed/all (user.currentlyAssignedRewardAmount, it gets refreshed/recalculated before take out)
    6) withdrawWithAllReward(uint256) = method 4, reward amount is fixed/all (user.currentlyAssignedRewardAmount); plus after that method 2
    7) withdrawAllWithAllReward() = method 4, reward amount is fixed/all (user.currentlyAssignedRewardAmount), plus after that method 2, amount is fixed/all (user.lptAmount)
    
    */

    // 1
    // this works as the inner function of all LP token withdraws, but also on its own as a kind of emergency withdraw
    function withdrawLptCore(uint256 _withdrawLptAmount) public {

        require(_withdrawLptAmount > 0, "withdrawLptCore: _withdrawLptAmount must be positive");

        UserInfo storage user = userInfo[msg.sender];
        require(user.lptAmount >= _withdrawLptAmount, "withdrawLptCore: cannot withdraw more than the deposit, _withdrawLptAmount is too big");
         
        lpToken.safeTransfer(msg.sender, _withdrawLptAmount); // send lpt to the user
        
        user.lptAmount = SafeMath.sub(user.lptAmount, _withdrawLptAmount);  // subtract from the user's lpt
        currentTotalLptAmount = SafeMath.sub(currentTotalLptAmount, _withdrawLptAmount); // subtract from the global counter

        updateDailyTotalLptAmount(); // update the global daily (array) counters

        emit WithdrawLptCore(msg.sender, _withdrawLptAmount);

    }

    // 2
    function withdrawWithoutReward(uint256 _withdrawLptAmount) public {
        addToTheUsersAssignedReward(); // updates UserInfo object
        withdrawLptCore(_withdrawLptAmount);
    }

    // 3
    function withdrawAllWithoutReward() public {
        addToTheUsersAssignedReward(); // updates UserInfo object
        withdrawWithoutReward(depositedLptOfTheUser());
    }

    // 4
    function takeOutSomeOfTheAccumulatedReward(uint256 _rewardAmountToBeTakenOut) public returns(uint256) {

        require(_rewardAmountToBeTakenOut > 0, "takeOutSomeOfTheAccumulatedReward: _rewardAmountToBeTakenOut must be positive");

        addToTheUsersAssignedReward(); // updates UserInfo object

        UserInfo storage user = userInfo[msg.sender];
        require(user.currentlyAssignedRewardAmount >= _rewardAmountToBeTakenOut, "withdraw: user.currentlyAssignedRewardAmount is too low for this operation, _rewardAmountToBeTakenOut is too big");

        // note: will always send out only what is currently held inside the UserInfo object (never directly from the global dailyErc20RewardAmounts[] array)
        // (so addToTheUsersAssignedReward() call is needed before transfer)

        erc20.safeTransfer(msg.sender, _rewardAmountToBeTakenOut); // send erc20 reward to the user
        user.currentlyAssignedRewardAmount = SafeMath.sub(user.currentlyAssignedRewardAmount, _rewardAmountToBeTakenOut);

        emit TakeOutSomeOfTheAccumulatedReward(msg.sender, _rewardAmountToBeTakenOut);
        
        return _rewardAmountToBeTakenOut;
        
    }

    // 5
    function takeOutTheAccumulatedReward() public returns(uint256) {
        addToTheUsersAssignedReward(); // updates UserInfo object 
        takeOutSomeOfTheAccumulatedReward(assignedRewardOfTheUser());
    }

    // 6
    function withdrawWithAllReward(uint256 _withdrawLptAmount) public {

        addToTheUsersAssignedReward(); // updates UserInfo object 

        uint256 a = assignedRewardOfTheUser();
        if (a > 0) {
            takeOutSomeOfTheAccumulatedReward(a);
        }

        withdrawWithoutReward(_withdrawLptAmount);
    }

    // 7
    function withdrawAllWithAllReward() public {

        addToTheUsersAssignedReward(); // updates UserInfo object 

        uint256 a = assignedRewardOfTheUser();
        if (a > 0) {
            takeOutSomeOfTheAccumulatedReward(a);
        }

        uint256 d = depositedLptOfTheUser();
        if (d > 0) {
            withdrawWithoutReward(d);
        }

    }

    /* -------------------------------------------------------------------- */
    /* --- reward related read/write operations for the depositors -------- */
    /* -------------------------------------------------------------------- */

    // Updates the current accumulated/assigned reward (RNB) of the user (depositor) 
    // (alters state in the user's UserInfo object and other places).
    function addToTheUsersAssignedReward() public returns(uint256) {

        uint256 currentStakingDayNumber = getCurrentStakingDayNumber();
        uint256 currentStakingDayNumberMinusOne = SafeMath.sub(currentStakingDayNumber, 1);

        if (currentStakingDayNumber == 0) {
            return 0;
        }

        UserInfo storage user = userInfo[msg.sender];
        
        if (user.lptAmount == 0) { 
            // when user.lptAmount was set to 0 we did the calculations and state changes, if lptAmount is still 0, it means no change since then
            // note: important to always call addToTheUsersAssignedReward() before transfers!
            user.rewardCountedUptoDay = currentStakingDayNumberMinusOne;
            return user.currentlyAssignedRewardAmount;
        }
        
        // ---

        // NOTE: in the last changes we made 4 real days into one contract day

        uint256 rewardCountedUptoDay = user.rewardCountedUptoDay;
        uint256 rewardCountedUptoDayNextDay = SafeMath.add(rewardCountedUptoDay, 1);

        if (!(rewardCountedUptoDayNextDay <= currentStakingDayNumberMinusOne)) {
            return user.currentlyAssignedRewardAmount;
        }

        // ---
        
        uint256 usersRewardRecently = 0;
        
        for (uint256 i = rewardCountedUptoDayNextDay; i <= currentStakingDayNumberMinusOne; i++) {
                        
            if (dailyTotalLptAmount[i] == 0) {
                continue;
            }

            // logic used here is because of integer division, we improve precision (not perfect solution, good enough)
            // (sample uses 10^4 instead of 10^19 units)
            // 49.5k = users stake, 80k = total stake, 2k = daily reward)
            // correct value would be = 1237.5
            // (49 500 / 80 000 = 0.61875 = 0) * 2000 = 0; 
            // ((49 500 * 100) / 80 000 = 61,875 = 61) * 2000 = 122000) / 100 = 1220 = 1220
            // ((49 500 * 1000) / 80 000 = 618,75 = 618) * 2000 = 1236000) / 1000 = 1236 = 1236
            // ((49 500 * 10000) / 80 000 = 6187.5 = 6187) * 2000 = 12374000) / 10000 = 1237.4 = 1237

            uint256 raiser = 10000000000000000000; // 10^19
            
            // uint256 rew = (((user.lptAmount.mul(raiser)).div(dailyTotalLptAmount[i])).mul(dailyPlannedErc20RewardAmounts[i])).div(raiser);
            
            // same with SafeMath:

            uint256 rew = SafeMath.mul(user.lptAmount, raiser);
            rew = SafeMath.div(rew, dailyTotalLptAmount[i]);
            rew = SafeMath.mul(rew, dailyPlannedErc20RewardAmounts[i]);
            rew = SafeMath.div(rew, raiser);

            if (dailyErc20RewardAmounts[i] < rew) { 
                // the has to be added amount is less, than the remaining (global), can happen because of slight rounding issues at the very end
                // not really... more likely the oposite (that some small residue gets left behind)
                rew = dailyErc20RewardAmounts[i];
            }

            usersRewardRecently = SafeMath.add(usersRewardRecently, rew);
            dailyErc20RewardAmounts[i] = SafeMath.sub(dailyErc20RewardAmounts[i], rew);
           
        }

        user.currentlyAssignedRewardAmount = SafeMath.add(user.currentlyAssignedRewardAmount, usersRewardRecently);
        currentTotalErc20RewardAmount = SafeMath.sub(currentTotalErc20RewardAmount, usersRewardRecently);
        user.rewardCountedUptoDay = currentStakingDayNumberMinusOne;

        return user.currentlyAssignedRewardAmount;
    }

    // Current additionally assignable reward (RNB) of the user (depositor), meaning what wasn't added to UserInfo, but will be upon the next addToTheUsersAssignedReward() call
    // (read only, does not save/alter state)
    function calculateUsersAssignableReward() public view returns(uint256) {

        // ---
        // --- similar to addToTheUsersAssignedReward(), but without the writes, plus few other modifications
        // ---

        uint256 currentStakingDayNumber = getCurrentStakingDayNumber();
        uint256 currentStakingDayNumberMinusOne = SafeMath.sub(currentStakingDayNumber, 1);

        if (currentStakingDayNumber == 0) {
            return 0;
        }

        UserInfo storage user = userInfo[msg.sender];
        
        if (user.lptAmount == 0) {
            // user.rewardCountedUptoDay = currentStakingDayNumberMinusOne; // different from addToTheUsersAssignedReward
            return 0; // different from addToTheUsersAssignedReward
        }
        
        // ---

        uint256 rewardCountedUptoDay = user.rewardCountedUptoDay;
        uint256 rewardCountedUptoDayNextDay = SafeMath.add(rewardCountedUptoDay, 1);

        if (!(rewardCountedUptoDayNextDay <= currentStakingDayNumberMinusOne)) {
            return 0; // different from addToTheUsersAssignedReward
        }

        // ---
        
        uint256 usersRewardRecently = 0;
        
        for (uint256 i = rewardCountedUptoDayNextDay; i <= currentStakingDayNumberMinusOne; i++) {
                        
            if (dailyTotalLptAmount[i] == 0) {
                continue;
            }

            // logic used here is because of integer division, we improve precision (not perfect solution, good enough)
            // (sample use 10^4 instead of 10^19 units)
            // 49.5k = users stake, 80k = total stake, 2k = daily reward)
            // correct value would be = 1237.5
            // (49 500 / 80 000 = 0.61875 = 0) * 2000 = 0; 
            // ((49 500 * 100) / 80 000 = 61,875 = 61) * 2000 = 122000) / 100 = 1220 = 1220
            // ((49 500 * 1000) / 80 000 = 618,75 = 618) * 2000 = 1236000) / 1000 = 1236 = 1236
            // ((49 500 * 10000) / 80 000 = 6187.5 = 6187) * 2000 = 12374000) / 10000 = 1237.4 = 1237

            uint256 raiser = 10000000000000000000; // 10^19
            
            // uint256 rew = (((user.lptAmount.mul(raiser)).div(dailyTotalLptAmount[i])).mul(dailyPlannedErc20RewardAmounts[i])).div(raiser);
            
            // with SafeMath:

            uint256 rew = SafeMath.mul(user.lptAmount, raiser);
            rew = SafeMath.div(rew, dailyTotalLptAmount[i]);
            rew = SafeMath.mul(rew, dailyPlannedErc20RewardAmounts[i]);
            rew = SafeMath.div(rew, raiser);
            
            if (dailyErc20RewardAmounts[i] < rew) {
                // the has to be added amount is less, than the remaining (global), can happen because of slight rounding issues at the very end
                // not really... more likely the oposite (that some small residue gets left behind)
                rew = dailyErc20RewardAmounts[i];
            }

            usersRewardRecently = SafeMath.add(usersRewardRecently, rew);
            // dailyErc20RewardAmounts[i] = SafeMath.sub(dailyErc20RewardAmounts[i], rew); // different from addToTheUsersAssignedReward
           
        }

        // different from addToTheUsersAssignedReward
        // user.currentlyAssignedRewardAmount = SafeMath.add(user.currentlyAssignedRewardAmount, usersRewardRecently); 
        // currentTotalErc20RewardAmount = SafeMath.sub(currentTotalErc20RewardAmount, usersRewardRecently);
        // user.rewardCountedUptoDay = currentStakingDayNumberMinusOne;
        
        // ---
        // ---
        // ---

        return usersRewardRecently;

    }    

    // user.currentlyAssignedRewardAmount + calculateUsersAssignableReward()
    // (read only, does not save/alter state)
    function calculateCurrentTakeableRewardOfTheUser() public view returns(uint256) {
        UserInfo storage user = userInfo[msg.sender];
        return SafeMath.add(user.currentlyAssignedRewardAmount, calculateUsersAssignableReward());
    }

    // Current clearly accumulated and assigned RNB reward of the user (depositor), meaning what is already in UserInfo
    function assignedRewardOfTheUser() public view returns(uint256) {
        UserInfo storage user = userInfo[msg.sender];
        return user.currentlyAssignedRewardAmount;
    }

    function rewardCountedUptoDayOfTheUser() public view returns(uint256) {
        UserInfo storage user = userInfo[msg.sender];
        return user.rewardCountedUptoDay;
    }

    /* -------------------------------------------------------------------- */
    /* --- other read operations for the depositors ----------------------- */
    /* -------------------------------------------------------------------- */

    // Current Uniswap V2 liquidity token amount of the user (depositor)
    function depositedLptOfTheUser() public view returns(uint256) {
        UserInfo storage user = userInfo[msg.sender];
        return user.lptAmount;
    }

    /* -------------------------------------------------------------------- */
    /* --- write operations for the contract owner ------------------------ */
    /* -------------------------------------------------------------------- */

    // Fund rewards (erc20 RNB) (operation is for Rentible admins)
    function fund(uint256 _fundErc20Amount) public onlyOwner {

        require(_fundErc20Amount > 0, "fund: _fundErc20Amount must be positive");

        require(fundedErc20RewardAmount < totalErc20RewardAmount, "fund: already fully funded");
        require(SafeMath.add(fundedErc20RewardAmount, _fundErc20Amount) <= totalErc20RewardAmount, "fund: _fundErc20Amount too big, sum would exceed totalErc20RewardAmount");

        // we do not check time here, optionally reward funding can be provided any time
        // (in pratice it should happen before start, or very quickly)

        erc20.safeTransferFrom(address(msg.sender), address(this), _fundErc20Amount);

        fundedErc20RewardAmount = SafeMath.add(fundedErc20RewardAmount, _fundErc20Amount);
        currentTotalErc20RewardAmount = SafeMath.add(currentTotalErc20RewardAmount, _fundErc20Amount);

        emit Fund(msg.sender, _fundErc20Amount);
    }

    /* -------------------------------------------------------------------- */
    /* --- misc utils ----------------------------------------------------- */
    /* -------------------------------------------------------------------- */

    function getCurrentStakingDayNumber() public view returns(uint256) {
        
        uint256 elapsedTime = block.timestamp.sub(startTime);
        uint256 dayNumber = SafeMath.div(elapsedTime, dayLength); // integer division, truncated

        if (dayNumber > 92) {
            return 92;
        }
        
        return dayNumber;

    }

}