pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract AI is ERC20, Ownable {
    bool private _paused;
    uint256 private constant TOTAL_SUPPLY = 10_000_000_000 * 10**18; // 100亿，考虑18位小数

    event Paused(address account);
    event Unpaused(address account);

    constructor(string memory name_, string memory symbol_) 
        ERC20(name_, symbol_) 
        Ownable(msg.sender)
    {
        _paused = false;
        _mint(msg.sender, TOTAL_SUPPLY); // 发行100亿代币给合约部署者
    }

    modifier whenNotPaused() {
        require(!_paused, "Pausable: paused");
        _;
    }

    modifier whenPaused() {
        require(_paused, "Pausable: not paused");
        _;
    }

    function paused() public view returns (bool) {
        return _paused;
    }

    function pause() public onlyOwner whenNotPaused {
        _paused = true;
        emit Paused(msg.sender);
    }

    function unpause() public onlyOwner whenPaused {
        _paused = false;
        emit Unpaused(msg.sender);
    }

    function transfer(address recipient, uint256 amount) 
        public 
        virtual 
        override 
        whenNotPaused 
        returns (bool) 
    {
        return super.transfer(recipient, amount);
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override whenNotPaused returns (bool) {
        return super.transferFrom(sender, recipient, amount);
    }
}
