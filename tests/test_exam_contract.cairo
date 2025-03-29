use skillnet_exam::interfaces::IExam::{IExamDispatcher, IExamDispatcherTrait};
use skillnet_exam::interfaces::IMockUsdc::{IMockUsdcDispatcher, IMockUsdcDispatcherTrait};
use skillnet_exam::interfaces::ISkillnetNft::{ISkillnetNftDispatcher, ISkillnetNftDispatcherTrait};
use snforge_std::{
    CheatSpan, ContractClassTrait, DeclareResultTrait, cheat_caller_address, declare,
    start_cheat_caller_address, stop_cheat_caller_address,
};
use starknet::{ContractAddress, contract_address_const};

fn deploy() -> (IExamDispatcher, ContractAddress, ContractAddress) {
    let nft_contract = deploy_nft();
    let nft_address = nft_contract.contract_address;

    let erc20_contract = deploy_erc20();
    let erc20_address = erc20_contract.contract_address;

    let skillnet_account: ContractAddress = contract_address_const::<'skillnet_account'>();

    let contract_class = declare("Exam").unwrap().contract_class();
    let (contract_address, _) = contract_class
        .deploy(@array![erc20_address.into(), skillnet_account.into(), nft_address.into()].into())
        .unwrap();

    (IExamDispatcher { contract_address }, erc20_address, nft_address)
}

fn deploy_erc20() -> IMockUsdcDispatcher {
    let owner: ContractAddress = contract_address_const::<'owner'>();

    let contract_class = declare("MockUsdc").unwrap().contract_class();
    let (contract_address, _) = contract_class.deploy(@array![owner.into()]).unwrap();

    IMockUsdcDispatcher { contract_address }
}

fn deploy_nft() -> ISkillnetNftDispatcher {
    let nft_contract_class = declare("SkillnetNft").unwrap().contract_class();
    let (contract_address, _) = nft_contract_class.deploy(@array![]).unwrap();

    ISkillnetNftDispatcher { contract_address }
}


#[test]
fn test_successful_exam_deployment() {
    let (contract, erc20_address, nft_address) = deploy();

    let (erc20, nft) = contract.get_addresses();

    assert(erc20 == erc20_address, 'ERC20 Error');
    assert(nft == nft_address, 'NFT Error');
}

// #[test]
// fn test_successful_create_exam() {
//     let contract = deploy();
//     let exam = contract.create_exam("Introduction Exams", 5, true);
//     let exam_data = contract.get_exam(exam.exam_id);
//     assert(exam_data.title == "Introduction Exams", 'EXAM_NOT_FOUND');
//     assert(exam_data.duration == 5, 'DURATION_MISMATCH');
//     assert(exam_data.is_active == true, 'ACTIVE_STATUS_MISMATCH');
// }

// #[test]
// fn test_add_and_get_question() {
//     let contract = deploy();
//     contract.create_exam("Science", 90_u64, true);

//     let question_id = contract
//         .add_question(0_u256, "What is H2O?", "Water", "Gold", "Oxygen", "Hydrogen", 1_u8);

//     let question = contract.get_question(0_u256, question_id);
//     assert(question.question == "What is H2O?", 'QUESTION_TEXT_MISMATCH');
//     assert(question.correct_option == 1_u8, 'CORRECT_OPTION_MISMATCH');
// }

// #[test]
// fn test_enrollment_process() {
//     let contract = deploy();
//     let contract_address = contract.contract_address;
//     contract.create_exam("Math", 60_u64, true);

//     // Test student enrollment
//     let student: ContractAddress = 12345.try_into().unwrap();
//     start_cheat_caller_address(contract_address, student);
//     contract.enroll_in_exam(0_u256);
//     stop_cheat_caller_address(student);

//     // Verify enrollment
//     let is_enrolled = contract.is_enrolled(0_u256, student);
//     assert(is_enrolled, 'STUDENT_SHOULD_BE_ENROLLED');

//     // Verify stats
//     let stats = contract.get_exam_stats(0_u256);
//     assert(stats.total_students == 1_u256, 'STUDENT_COUNT_MISMATCH');
// }

// #[test]
// #[should_panic]
// fn test_double_enrollment() {
//     let contract = deploy();
//     let contract_address = contract.contract_address;
//     contract.create_exam("History", 45_u64, true);

//     let student: ContractAddress = 54321.try_into().unwrap();
//     start_cheat_caller_address(contract_address, student);
//     contract.enroll_in_exam(0_u256);
//     // This should panic
//     contract.enroll_in_exam(0_u256);
//     stop_cheat_caller_address(student);
// }

// #[test]
// fn test_exam_status_toggle() {
//     let creator: ContractAddress = 99999.try_into().unwrap();
//     let contract = deploy();
//     let contract_address = contract.contract_address;
//     start_cheat_caller_address(contract_address, creator);

//     contract.create_exam("Physics", 75_u64, true);

//     // Toggle status
//     contract.toggle_exam_status(0_u256);
//     let exam = contract.get_exam(0_u256);
//     assert(exam.is_active == false, 'STATUS_SHOULD_BE_INACTIVE');

//     // Toggle back
//     contract.toggle_exam_status(0_u256);
//     let exam = contract.get_exam(0_u256);
//     assert(exam.is_active == true, 'STATUS_SHOULD_BE_ACTIVE');

//     stop_cheat_caller_address(creator);
// }

// #[test]
// #[should_panic]
// fn test_non_creator_toggle_status() {
//     let creator: ContractAddress = 11111.try_into().unwrap();
//     let non_creator: ContractAddress = 22222.try_into().unwrap();
//     let contract = deploy();
//     let contract_address = contract.contract_address;
//     start_cheat_caller_address(contract_address, creator);
//     contract.create_exam("Chemistry", 50_u64, true);
//     stop_cheat_caller_address(creator);

//     start_cheat_caller_address(contract_address, non_creator);
//     // This should panic
//     contract.toggle_exam_status(0_u256);
//     stop_cheat_caller_address(non_creator);
// }

// #[test]
// #[should_panic]
// fn test_add_question_to_inactive_exam() {
//     let creator: ContractAddress = 33333.try_into().unwrap();
//     let contract = deploy();
//     let contract_address = contract.contract_address;
//     start_cheat_caller_address(contract_address, creator);

//     contract.create_exam("Biology", 30_u64, false);

//     // This should panic
//     contract.add_question(0_u256, "Question?", "A", "B", "C", "D", 1_u8);

//     stop_cheat_caller_address(creator);
// }

// #[test]
// fn test_multiple_questions_stats() {
//     let contract = deploy();
//     contract.create_exam("Computer Science", 120_u64, true);

//     // Add 3 questions
//     contract.add_question(0_u256, "Q1", "A1", "B1", "C1", "D1", 1_u8);
//     contract.add_question(0_u256, "Q2", "A2", "B2", "C2", "D2", 2_u8);
//     contract.add_question(0_u256, "Q3", "A3", "B3", "C3", "D3", 3_u8);

//     let stats = contract.get_exam_stats(0_u256);
//     assert(stats.total_questions == 3_u256, 'SHOULD_HAVE_3_QUESTIONS');
// }

// #[test]
// #[should_panic]
// fn test_invalid_correct_option() {
//     let contract = deploy();
//     contract.create_exam("Geography", 40_u64, true);

//     // This should panic (correct_option must be 1-4)
//     contract
//         .add_question(0_u256, "Capital of France?", "London", "Berlin", "Paris", "Madrid", 5_u8);
// }

#[test]
fn test_successful_deploy_nft() {
    let contract = deploy_nft();
    let name = contract.get_name();
    let symbol = contract.get_symbol();

    let name1: ByteArray = "skill";
    let sym: ByteArray = "SKN";

    assert(name == name1, 'Name_NOT_FOUND');
    assert(symbol == sym, 'Symbol');
    println!("name: {}", name);
    println!("symbol: {}", symbol);
}

#[test]
fn test_successful_nft_mint() {
    let contract = deploy_nft();

    let beneficiary: ContractAddress = contract_address_const::<'bene'>();

    contract.mint(beneficiary, 0);

    let owner = contract.is_owner(0);

    assert(owner == beneficiary, 'mint error');
}

#[test]
#[should_panic]
fn test_successful_nft_mint_wrong_owner() {
    let contract = deploy_nft();
    let beneficiary: ContractAddress = contract_address_const::<'bene'>();
    let beneficiary1: ContractAddress = contract_address_const::<'busjne'>();

    contract.mint(beneficiary, 0);

    let owner = contract.is_owner(0);

    assert(owner == beneficiary1, 'mint error');
}

#[test]
fn test_successful_deploy_MockUSDC() {
    let contract = deploy_erc20();
    let name = contract.get_name();
    let symbol = contract.get_symbol();

    println!("name: {}", name);
    println!("symbol: {}", symbol);
}

#[test]
fn test_successful_erc20_mint() {
    let contract = deploy_erc20();
    let erc20_address = contract.contract_address;
    let owner: ContractAddress = contract_address_const::<'owner'>();

    let beneficiary: ContractAddress = contract_address_const::<'bene'>();

    let amount = 1_u256;
    let owner_bal = contract.get_balance(beneficiary);
    // contract.approve_user(erc20_address, 100000);
    cheat_caller_address(erc20_address, owner, CheatSpan::Indefinite);
    contract.mint(beneficiary, amount);

    let owner_bal_after = contract.get_balance(beneficiary);

    println!("beneficiary: {}", owner_bal);
    println!("beneficiary: {}", owner_bal_after);
    assert(owner_bal < owner_bal_after, 'mint error');
}

