// SPDX-License-Identifier: MIT
use starknet::ContractAddress;

#[starknet::interface]
trait IMockUsdc<ContractState> {
    fn mint(ref self: ContractState, recipient: ContractAddress, amount: u256);
    fn get_balance(ref self: ContractState, address: ContractAddress) -> u256;
    fn transferFrom(
        ref self: ContractState, sender: ContractAddress, recipient: ContractAddress, amount: u256,
    ) -> bool;
    fn get_symbol(ref self: ContractState) -> ByteArray;
    fn get_name(ref self: ContractState) -> ByteArray;
    fn get_allowance(
        ref self: ContractState, owner: ContractAddress, spender: ContractAddress,
    ) -> u256;
    fn approve_user(ref self: ContractState, spender: ContractAddress, amount: u256);
}

#[starknet::contract]
pub mod MockUsdc {
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::token::erc20::{ERC20Component, ERC20HooksEmptyImpl};
    use starknet::ContractAddress;

    component!(path: ERC20Component, storage: erc20, event: ERC20Event);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);


    #[abi(embed_v0)]
    impl ERC20Impl = ERC20Component::ERC20Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC20MetadataImpl = ERC20Component::ERC20MetadataImpl<ContractState>;
    impl InternalImpl = ERC20Component::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;


    #[storage]
    pub struct Storage {
        #[substorage(v0)]
        pub erc20: ERC20Component::Storage,
        #[substorage(v0)]
        pub ownable: OwnableComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC20Event: ERC20Component::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.erc20.initializer(format!("USDC"), format!("USDC"));
        self.ownable.initializer(owner);

        self.erc20.mint(owner, 1000000_u256);
    }

    #[abi(embed_v0)]
    impl ExternalImpl of super::IMockUsdc<ContractState> {
        fn mint(ref self: ContractState, recipient: ContractAddress, amount: u256) {
            self.erc20.mint(recipient, amount);
        }

        fn get_balance(ref self: ContractState, address: ContractAddress) -> u256 {
            let balance = self.erc20.balance_of(address);
            balance
        }

        fn transferFrom(
            ref self: ContractState,
            sender: ContractAddress,
            recipient: ContractAddress,
            amount: u256,
        ) -> bool {
            let success = self.erc20.transfer_from(sender, recipient, amount);
            success
        }

        fn approve_user(ref self: ContractState, spender: ContractAddress, amount: u256) {
            self.erc20.approve(spender, amount);
        }

        fn get_allowance(
            ref self: ContractState, owner: ContractAddress, spender: ContractAddress,
        ) -> u256 {
            let allowed_amount = self.erc20.allowance(owner, spender);
            allowed_amount
        }

        fn get_name(ref self: ContractState) -> ByteArray {
            let name = self.erc20.name();
            name
        }

        fn get_symbol(ref self: ContractState) -> ByteArray {
            let symbol = self.erc20.symbol();
            symbol
        }
    }
}
