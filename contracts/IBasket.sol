
// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

enum Status {pending, active, closed }

interface IBasket {
    /**
        * @dev Returns the base token of the basket.
        * @return The address of the base token used within the basket.
        */   
    function baseToken() external view returns(address);

    /**
        * @dev Returns the administrator address of the basket. The admin address must match the ECTA contract address.
        * @return The address of the administrator of the basket.
        */
    function admin() external view returns(address);

    /**
        * @dev Returns the trader address of the basket.
        * @return The address of the trader associated with the basket.
        */
    function trader() external view returns(address);
    
    /**
        * @dev Returns the current status of the basket.
        * @return The status of the basket, which can be one of the following: 'pending', 'active', or 'closed'.
        */
    function status() external view returns(Status);
    
    /**
        * @dev Fetches the admin's (ECTA) share of the basket's profit and transfers the funds to the admin account.
        * @return A uint256 indicates the value of profit gathered.
        */
    function adminShareProfit() external returns(uint256);

    /**
        * @dev Allows the Maintainer of ECTA to set an assistants for each basket, enabling the management of each basket by the designated assistant.
        * @param assitant The address of the assistant to set.
        * @return A boolean indicating the success of the assistant setting.
        */
    function setAssistant(address assitant) external returns(bool);
}
