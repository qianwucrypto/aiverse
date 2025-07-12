// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BatchTransfer is Ownable(address(this)) {
    event Transfer(address indexed from, address indexed to, uint256 value);

    function balanceOf(address account, address tokenAddress)
        external
        view
        returns (uint256)
    {
        IERC20 token = IERC20(tokenAddress);
        return token.balanceOf(account);
    }


    function multiTransferNativeToken(address[] memory accounts, uint256 simpleAmount) payable public {
        require(accounts.length > 0, "Missing recipient address");
        require(simpleAmount > 0, "Missing amount of transfers");

        uint256 totalAmount = accounts.length * simpleAmount;
        require(totalAmount >= msg.value, "Insufficient native token balance");

        for (uint i = 0; i < accounts.length; i++) {
            // accounts[i].call{value:simpleAmount}("");
            // payable(address(accounts[i])).transfer(simpleAmount);
            (bool success, ) = payable(accounts[i]).call{value: simpleAmount}("");
            require(success, "transfer fail");
        }
    }



    function multiTransferERC20Token(address[] memory accounts, uint256 simpleAmount, address fromToken) public {
        require(accounts.length > 0, "Missing recipient address");
        require(simpleAmount > 0, "Missing amount of transfers");
        require(fromToken != address(0), "ERC20 token must be address");

        uint256 totalAmount = accounts.length * simpleAmount;
        IERC20 token = IERC20(fromToken);
        require(totalAmount <= token.balanceOf(msg.sender), "Insufficient erc20 token balance");

        for (uint i = 0; i < accounts.length; i++) {
            token.transferFrom(msg.sender, accounts[i], simpleAmount);
        }
    }

    // 接收 ETH 退款
    receive() external payable {}
}
