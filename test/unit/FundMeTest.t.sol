// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {FundMe} from "../../src/FundMe.sol";
import {DeployFundMe} from "../../script/DeployFundMe.s.sol";

contract FundMeTest is Test {
    FundMe fundMe;

    address USER = makeAddr("user"); // creates a dummy address

    uint256 constant SEND_VALUE = 10e18; // 10 ETH
    uint256 constant STARTING_BALANCE = 100 ether;
    uint256 constant GAS_PRICE = 1; // gas price in gwei

    // set up the contract that will be tested
    function setUp() external {
        // fundMe = new FundMe(0x694AA1769357215DE4FAC081bf1f309aDC325306);
        DeployFundMe deployFundMe = new DeployFundMe();
        fundMe = deployFundMe.run();
        vm.deal(USER, STARTING_BALANCE); // set the balance of user to STARTING_BALANCE
    }

    // Actual testing
    function testMinimumDollarIsFive() public {
        // check that the MINIMUM_USD variable is 5
        assertEq(fundMe.MINIMUM_USD(), 5e18);
    }

    function testOwnerIsMsgSender() public {
        // check that the owner is the new FundMe contract created in setUp()
        assertEq(fundMe.getOwner(), msg.sender);
    }

    // check price feed version
    function testPriceFeedVersionIsAccurate() public {
        uint256 version = fundMe.getVersion();
        console.log(version);
        assertEq(version, 4);
    }

    function testFundFailsWithoutEnoughETH() public {
        vm.expectRevert(); // We expect the next line to revert.abi
        // assert (this tx fails/reverts)
        fundMe.fund(); // sending 0 ETH when funding, to see if  MINIMUM_USD works
    }

    function testFundUpdatesFundedDataStructure() public funded {
        uint256 amountFunded = fundMe.getAddressToAmountFunded(USER);
        assertEq(amountFunded, SEND_VALUE);
    }

    function testAddsFunderToArrayOfFunders() public funded {
        address funder = fundMe.getFunder(0); // get the funder at index 0
        assertEq(funder, USER); // check that the funder is USER
    }

    modifier funded() {
        vm.prank(USER); // set msg.sender to USER for the next tx
        fundMe.fund{value: SEND_VALUE}(); // fund the contract with SEND_VALUE
        _;
    }

    function testOnlyOwnerCanWithdraw() public funded {
        vm.expectRevert(); // expect the next tx to revert
        vm.prank(USER); // set msg.sender to USER who is not the owner for the next tx
        fundMe.withdraw(); // try to withdraw
    }

    function testWithDrawWithASinleFunder() public funded {
        // Arrange
        uint256 startingOwnerBalancer = fundMe.getOwner().balance; // get the owner's balanceabi
        uint256 startingFundMeBalance = address(fundMe).balance; // get the FundMe contract balance
        vm.txGasPrice(GAS_PRICE); // set the gas price for the next tx

        // Act
        vm.prank(fundMe.getOwner()); // set msg.sender to the owner
        fundMe.withdraw(); // withdraw the funds

        // Assert
        uint256 endingOwnerBalance = fundMe.getOwner().balance; // get the owner's ending balance
        uint256 endingFundMeBalance = address(fundMe).balance; // get the FundMe contract's ending balance
        assertEq(endingFundMeBalance, 0);
        assertEq(
            endingOwnerBalance,
            startingOwnerBalancer + startingFundMeBalance
        ); // check that the owner's balance is the same as the starting balance + the FundMe contract's balance
    }

    function testWithdrawFromMultipleFunders() public funded {
        // Arrange
        uint160 numberOfFunders = 10; // uint160 needed for addresses, uint160 have the same bytes has an address
        uint160 startingFunderIndex = 1; // 1 because the 0 address is to be avoided

        for (uint160 i = startingFunderIndex; i < numberOfFunders; i++) {
            hoax(address(i), SEND_VALUE); // create fake address and gives it a balance
            fundMe.fund{value: SEND_VALUE}(); // fund the contract with SEND_VALUE
        }
        uint256 startingOwnerBalance = fundMe.getOwner().balance; // get the owner's balance
        uint256 startingFundMeBalance = address(fundMe).balance; // get the FundMe contract's balance

        // Act
        vm.startPrank(fundMe.getOwner());
        fundMe.withdraw();
        vm.stopPrank();

        // Assert
        assert(address(fundMe).balance == 0);
        assert(
            fundMe.getOwner().balance ==
                startingFundMeBalance + startingOwnerBalance
        );
    }

    function testWithdrawFromMultipleFundersCheaper() public funded {
        // Arrange
        uint160 numberOfFunders = 10; // uint160 needed for addresses, uint160 have the same bytes has an address
        uint160 startingFunderIndex = 1; // 1 because the 0 address is to be avoided

        for (uint160 i = startingFunderIndex; i < numberOfFunders; i++) {
            hoax(address(i), SEND_VALUE); // create fake address and gives it a balance
            fundMe.fund{value: SEND_VALUE}(); // fund the contract with SEND_VALUE
        }
        uint256 startingOwnerBalance = fundMe.getOwner().balance; // get the owner's balance
        uint256 startingFundMeBalance = address(fundMe).balance; // get the FundMe contract's balance

        // Act
        vm.startPrank(fundMe.getOwner());
        fundMe.cheaperWithdraw();
        vm.stopPrank();

        // Assert
        assert(address(fundMe).balance == 0);
        assert(
            fundMe.getOwner().balance ==
                startingFundMeBalance + startingOwnerBalance
        );
    }
}
