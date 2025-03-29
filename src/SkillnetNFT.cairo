//to do make sure only org, event and orgs can call the mint function
// use crate::interfaces::IERC20::IERC20;
use crate::interfaces::ISkillnetNft::ISkillnetNft;
#[starknet::contract]
pub mod SkillnetNft {
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc721::{ERC721Component, ERC721HooksEmptyImpl};
    use starknet::ContractAddress;


    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC721Event: ERC721Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        let base_uri = "uri";
        let name = "skill";
        let symbol = "SKN";
        self.erc721.initializer(name, symbol, base_uri);
    }

    #[abi(embed_v0)]
    impl ERC721Impl = ERC721Component::ERC721MixinImpl<ContractState>;

    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl SkillnetNft of super::ISkillnetNft<ContractState> {
        fn mint(ref self: ContractState, recipient: ContractAddress, token_id: u256) {
            self.erc721.mint(recipient, token_id);
        }
        fn is_owner(ref self: ContractState, token_id: u256) -> ContractAddress {
            let owner = self.erc721.ownerOf(token_id);
            owner
        }
        fn get_name(ref self: ContractState) -> ByteArray {
            let name = self.erc721.name();
            name
        }

        fn get_symbol(ref self: ContractState) -> ByteArray {
            let name = self.erc721.symbol();
            name
        }
    }
}
