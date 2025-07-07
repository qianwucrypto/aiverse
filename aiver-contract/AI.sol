// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract AI is ERC20, ERC20Burnable, Ownable {
    // 关键修改：重写 decimals() 函数，将精度设为 6
    function decimals() public pure override returns (uint8) {
        return 6; // 覆盖默认的 18 位精度 [1,6](@ref)
    }

    constructor() 
        ERC20("AI", "AI") 
        Ownable(msg.sender) 
    {
        // 初始供应量计算适配新精度（6 位）
        uint256 initialSupply = 200_000_000_000 * (10 ** decimals());
        _mint(msg.sender, initialSupply);
    }

    // 安全版 approveAndCall
    function approveAndCall(
        address spender, 
        uint256 amount, 
        bytes calldata data
    ) external returns (bool) {
        approve(spender, amount); // 复用 OpenZeppelin 的 approve 逻辑
        
        // 使用低级别 call 替代接口调用，避免未实现函数导致的失败
        (bool success, ) = spender.call(
            abi.encodeWithSignature(
                "receiveApproval(address,uint256,address,bytes)",
                msg.sender,
                amount,
                address(this),
                data
            )
        );
        require(success, "Call failed");
        return true;
    }
}
