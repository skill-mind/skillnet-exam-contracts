use starknet::ContractAddress;

#[starknet::interface]
pub trait IERC20<TContractState> {
    fn mint(ref self: TContractState, amount: u256);
    fn transfer_from(
        ref self: TContractState, sender: ContractAddress, recipient: ContractAddress, amount: u256,
    );
}
