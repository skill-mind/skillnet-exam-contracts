use starknet::ContractAddress;

#[starknet::interface]
pub trait ISkillnetNft<TContractState> {
    fn mint(ref self: TContractState, recipient: ContractAddress, token_id: u256);
    fn is_owner(ref self: TContractState, token_id: u256) -> ContractAddress;
    fn get_symbol(ref self: TContractState) -> ByteArray;
    fn get_name(ref self: TContractState) -> ByteArray;
}
