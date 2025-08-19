// SPDX-License-Identifier: MIT-1.1
pragma solidity 0.8.19;

import "./BaseTest.sol";

contract CEDATest is BaseTest {
    CEDA token;

    function _setUp() public override {
        token = new CEDA();
    }

    function testCannotSetMinterIfNotMinter() public {
        vm.prank(address(owner2));
        vm.expectRevert(ICEDA.NotMinter.selector);
        token.setMinter(address(owner3));
    }

    function testSetMinter() public {
        token.setMinter(address(owner3));

        assertEq(token.minter(), address(owner3));
    }

    function testCannotMintIfNotMinter() public {
        vm.prank(address(owner2));
        vm.expectRevert(ICEDA.NotMinter.selector);
        token.mint(address(owner2), TOKEN_1);
    }
}
