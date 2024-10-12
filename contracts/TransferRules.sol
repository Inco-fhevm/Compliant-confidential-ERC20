// SPDX-License-Identifier: BSD-3-Clause-Clear
pragma solidity ^0.8.24;

import "fhevm/lib/TFHE.sol";
import "./Identity.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";

contract TransferRules is Ownable2Step {
    Identity public immutable identityContract;
    uint8 private minimumAge;
    uint64 public constant transferLimit=(20000 * 10**6);
    euint64 public TRANSFER_LIMIT=TFHE.asEuint64(transferLimit); // 20,000 tokens with 6 decimals

    mapping(address => bool) public userBlocklist;

    event BlacklistUpdated(address indexed user, bool isBlacklisted);
    error AddressBlacklisted(address  user);

    constructor(address _identityContract) Ownable(msg.sender) {
        identityContract = Identity(_identityContract);
    }
    function setMinimumAge(uint8 _minimumAge) onlyOwner() external {
        minimumAge = _minimumAge;
    }

    function transfer(address from, address to,einput amount,bytes calldata inputproof)
    public returns (ebool)
    {
        euint64 eamount = TFHE.asEuint64(amount, inputproof);
        return transfer(from, to,eamount);
    }
    function transfer(address from, address to, euint64 amount) public  returns (ebool) {
        // Condition 1: Check that addresses are not blacklisted
        if (userBlocklist[from] || userBlocklist[to]) {
            ebool transferable= TFHE.asEbool(false);
            TFHE.allow(transferable,address(this));
            TFHE.allow(transferable, msg.sender);
            return transferable;

        }
        ebool ageCondition = identityContract.checkAgeRequirement(from,to,minimumAge);
       TFHE.allow(ageCondition,address(this));
      ebool belowLimit = TFHE.le(amount,20000000000);
       TFHE.allow(belowLimit,address(this));
       // check if below limit and age condition is true
         ebool transferAllowed = ageCondition;//TFHE.and(belowLimit, ageCondition);
        // euint64 result = TFHE.select(transferAllowed, amount, TFHE.asEuint64(0));
        TFHE.allow(transferAllowed,address(this));
        TFHE.allow(transferAllowed, msg.sender);
        return transferAllowed;
    }





    function mint(address to, euint64 amount) public returns (ebool) {
        // Condition 1: Check if the user is blacklisted
        if (userBlocklist[to]) {
            revert AddressBlacklisted(to);
        }
        ebool belowMintLimit = TFHE.le(amount, TRANSFER_LIMIT);


        ebool mintAllowed = TFHE.and(TFHE.asEbool(true), belowMintLimit);
        euint64 mintAmount = TFHE.select(mintAllowed, amount, TFHE.asEuint64(0));

        // Allow the result to be accessible
        TFHE.allow(mintAllowed, address(this));
        TFHE.allow(mintAllowed, msg.sender);

        return mintAllowed;
    }

    function setBlacklist(address user, bool isBlacklisted) onlyOwner() external {
        require(user != address(0), "Invalid address");
        userBlocklist[user] = isBlacklisted;
        emit BlacklistUpdated(user, isBlacklisted);
    }
}
