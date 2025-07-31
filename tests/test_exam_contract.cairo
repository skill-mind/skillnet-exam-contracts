use openzeppelin::upgrades::interface::{IUpgradeableDispatcher, IUpgradeableDispatcherTrait};
use openzeppelin::upgrades::upgradeable::UpgradeableComponent::{Event as UpgradeEvent, Upgraded};
use skillnet_exam::base::types::{Exam, ExamSubmitted};
use skillnet_exam::interfaces::IExam::{IExamDispatcher, IExamDispatcherTrait};
use skillnet_exam::interfaces::IMockUsdc::{IMockUsdcDispatcher, IMockUsdcDispatcherTrait};
use skillnet_exam::interfaces::ISkillnetNft::{ISkillnetNftDispatcher, ISkillnetNftDispatcherTrait};
use snforge_std::{
    CheatSpan, ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait,
    cheat_caller_address, declare, spy_events, start_cheat_block_timestamp,
    start_cheat_caller_address, stop_cheat_caller_address,
};
use starknet::{ContractAddress, contract_address_const, get_block_timestamp};

fn OWNER() -> ContractAddress {
    contract_address_const::<'OWNER'>()
}

fn deploy() -> (IExamDispatcher, ContractAddress, ContractAddress) {
    let nft_contract = deploy_nft();
    let nft_address = nft_contract.contract_address;

    let erc20_contract = deploy_erc20();
    let erc20_address = erc20_contract.contract_address;
    let skillnet_revenue_account: ContractAddress = contract_address_const::<'skillnet_account'>();

    let mut calldata = array![];
    erc20_address.serialize(ref calldata);
    skillnet_revenue_account.serialize(ref calldata);
    nft_address.serialize(ref calldata);
    OWNER().serialize(ref calldata);

    let contract_class = declare("Exam").unwrap().contract_class();
    let (contract_address, _) = contract_class.deploy(@calldata).unwrap();

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

#[test]
fn test_successful_create_exam() {
    let (contract, _, _) = deploy();
    let exam = contract.create_exam("Introduction Exams", 5, true, false, 0, 50);
    let exam_data = contract.get_exam(exam.exam_id);
    assert(exam_data.title == "Introduction Exams", 'EXAM_NOT_FOUND');
    assert(exam_data.duration == 5, 'DURATION_MISMATCH');
    assert(exam_data.is_active, 'ACTIVE_STATUS_MISMATCH');
    assert(!exam_data.is_paid, 'paid set correctly');
}

#[test]
fn test_successful_create_paid_exam() {
    let (contract, _, _) = deploy();
    let exam = contract.create_exam("Introduction Exams", 5, true, true, 100, 50);
    let exam_data = contract.get_exam(exam.exam_id);
    assert(exam_data.title == "Introduction Exams", 'EXAM_NOT_FOUND');
    assert(exam_data.duration == 5, 'DURATION_MISMATCH');
    assert(exam_data.is_active, 'ACTIVE_STATUS_MISMATCH');
    assert(exam_data.price == 100, 'Price set correctly');
    assert(exam_data.is_paid, 'paid set correctly');
}
#[test]
#[should_panic]
fn test_successfu_incorrectl_create_exam() {
    let (contract, _, _) = deploy();
    let exam = contract.create_exam("Introduction Exams", 5, true, false, 0, 50);
    let exam_data = contract.get_exam(exam.exam_id);
    assert(exam_data.title == "Introduction Exams", 'EXAM_NOT_FOUND');
    assert(exam_data.duration == 5, 'DURATION_MISMATCH');
    assert(exam_data.is_active, 'ACTIVE_STATUS_MISMATCH');
    assert(exam_data.is_paid, 'paid set correctly');
}

#[test]
#[should_panic]
fn test_successful_incorrect_create_paid_exam() {
    let (contract, _, _) = deploy();
    let exam = contract.create_exam("Introduction Exams", 5, true, true, 100, 50);
    let exam_data = contract.get_exam(exam.exam_id);
    assert(exam_data.title == "Introduction Exams", 'EXAM_NOT_FOUND');
    assert(exam_data.duration == 5, 'DURATION_MISMATCH');
    assert(exam_data.is_active, 'ACTIVE_STATUS_MISMATCH');
    assert(exam_data.price == 100, 'Price set correctly');
    assert(!exam_data.is_paid, 'paid set correctly');
}

#[test]
fn test_add_and_get_questions() {
    let (contract, _, _) = deploy();
    contract.create_exam("Science", 90_u64, true, false, 0, 50);
    contract.add_questions(10, 0_u256, "123456");

    let question = contract.get_questions(0_u256);
    assert(question == "123456", 'QUESTIONS_MISMATCH');
}

#[test]
fn test_enrollment_process() {
    let (contract, _, _) = deploy();
    let contract_address = contract.contract_address;
    contract.create_exam("Math", 60_u64, true, false, 0, 50);

    // Test student enrollment
    let student: ContractAddress = 12345.try_into().unwrap();
    start_cheat_caller_address(contract_address, student);
    contract.enroll_in_exam(0_u256);
    stop_cheat_caller_address(student);

    // Verify enrollment
    let is_enrolled = contract.is_enrolled(0_u256, student);
    assert(is_enrolled, 'STUDENT_SHOULD_BE_ENROLLED');

    // Verify stats
    let stats = contract.get_exam_stats(0_u256);
    assert(stats.total_students == 1_u256, 'STUDENT_COUNT_MISMATCH');
}

#[test]
fn test_enrollment_process_paid_exam() {
    let (contract, erc20_address, _) = deploy();
    let contract_address = contract.contract_address;
    let student: ContractAddress = contract_address_const::<'owner'>();
    let skillnet_revenue_account: ContractAddress = contract_address_const::<'skillnet_account'>();

    contract.create_exam("Math", 60_u64, true, true, 100, 50);

    let token_dispatcher = IMockUsdcDispatcher { contract_address: erc20_address };

    start_cheat_caller_address(erc20_address, student);
    // Make sure approve_user sets the allowance mapping for (owner, contract_address) to 10000.
    token_dispatcher.mint(contract_address, 50000);
    stop_cheat_caller_address(erc20_address);

    // Test student enrollment
    start_cheat_caller_address(erc20_address, student);
    // Make sure approve_user sets the allowance mapping for (owner, contract_address) to 10000.
    token_dispatcher.approve_user(contract_address, 10000);
    token_dispatcher.approve_user(skillnet_revenue_account, 10000);
    stop_cheat_caller_address(erc20_address);

    // Debug: Print allowance to verify it's set correctly.
    let approved_amount = token_dispatcher.get_allowance(student, contract_address);
    println!("Approved allowance for contract: {}", approved_amount);
    // You can add an assertion if needed:
    // assert(approved_amount >= 1850, 'Allowance not high enough');
    let student_allowance = token_dispatcher.get_allowance(student, contract_address);
    let contract_allowance = token_dispatcher
        .get_allowance(contract_address, skillnet_revenue_account);
    println!("Student allowance for contract: {}", student_allowance);
    println!("Contract allowance for skillnet revenue: {}", contract_allowance);

    let student_initial_balance = token_dispatcher.get_balance(student);
    let skillnet_initial_balance = token_dispatcher.get_balance(skillnet_revenue_account);
    let contract_initial_balance = token_dispatcher.get_balance(contract_address);
    println!("Initial balance of Student: {}", student_initial_balance);
    println!("Initial skilnet revenue balance : {}", skillnet_initial_balance);
    println!("Initial Contract bal: {}", contract_initial_balance);

    // // Step 2: Now simulate the approved spender (the contract) making the transfer.
    start_cheat_caller_address(contract_address, student);
    contract.enroll_in_exam(0_u256);
    stop_cheat_caller_address(student);

    // // Verify enrollment
    let is_enrolled = contract.is_enrolled(0_u256, student);
    assert(is_enrolled, 'STUDENT_SHOULD_BE_ENROLLED');

    // // Verify stats
    let stats = contract.get_exam_stats(0_u256);
    assert(stats.total_students == 1_u256, 'STUDENT_COUNT_MISMATCH');

    // // Get final balances.
    let student_final_balance = token_dispatcher.get_balance(student);
    let skillnet_final_balance = token_dispatcher.get_balance(skillnet_revenue_account);
    let contract_final_balance = token_dispatcher.get_balance(contract_address);
    println!("Final balance of Student: {}", student_final_balance);
    println!("Final balance of skillnet_revenue_account: {}", skillnet_final_balance);
    println!("Final contract balance: {}", contract_final_balance);

    assert(skillnet_final_balance > skillnet_initial_balance, 'Transfer  failed');
    assert(student_final_balance < student_initial_balance, 'Sender balance err');
    assert(contract_final_balance > contract_initial_balance, 'contract balance err');
}


#[test]
fn test_enrollment_process_free_exam() {
    let (contract, erc20_address, _) = deploy();
    let contract_address = contract.contract_address;

    contract.create_exam("Math", 60_u64, true, false, 100, 50);

    let token_dispatcher = IMockUsdcDispatcher { contract_address: erc20_address };

    // Test student enrollment
    let student: ContractAddress = contract_address_const::<'owner'>();

    start_cheat_caller_address(contract_address, student);
    start_cheat_caller_address(erc20_address, student);
    // Make sure approve_user sets the allowance mapping for (owner, contract_address) to 10000.
    token_dispatcher.mint(contract_address, 5000);
    stop_cheat_caller_address(erc20_address);

    let contract_initial_balance = token_dispatcher.get_balance(contract_address);

    println!("Initial balance of sender: {}", contract_initial_balance);

    // Step 2: Now simulate the approved spender (the contract) making the transfer.
    // start_cheat_caller_address(erc20_address, contract_address);
    contract.enroll_in_exam(0_u256);
    // stop_cheat_caller_address(student);

    // Verify enrollment
    let is_enrolled = contract.is_enrolled(0_u256, student);
    assert(is_enrolled, 'STUDENT_SHOULD_BE_ENROLLED');

    // Verify stats
    let stats = contract.get_exam_stats(0_u256);
    assert(stats.total_students == 1_u256, 'STUDENT_COUNT_MISMATCH');

    // Get final balances.
    let sender_final_balance = token_dispatcher.get_balance(contract_address);

    println!("Final balance of sender: {}", sender_final_balance);
    assert(sender_final_balance < contract_initial_balance, 'Contract balance err');
}

#[test]
#[should_panic]
fn test_enrollment_process_paid_exam_broke_student() {
    let (contract, _, _) = deploy();
    let contract_address = contract.contract_address;
    contract.create_exam("Math", 60_u64, true, true, 200, 50);

    // Test student enrollment
    let student: ContractAddress = contract_address_const::<'broke'>();
    start_cheat_caller_address(contract_address, student);
    contract.enroll_in_exam(0_u256);
    stop_cheat_caller_address(student);

    // Verify enrollment
    let is_enrolled = contract.is_enrolled(0_u256, student);
    assert(is_enrolled, 'STUDENT_SHOULD_BE_ENROLLED');

    // Verify stats
    let stats = contract.get_exam_stats(0_u256);
    assert(stats.total_students == 1_u256, 'STUDENT_COUNT_MISMATCH');
}

#[test]
#[should_panic]
fn test_double_enrollment() {
    let (contract, _, _) = deploy();
    let contract_address = contract.contract_address;
    contract.create_exam("History", 45_u64, true, false, 0, 50);

    let student: ContractAddress = 54321.try_into().unwrap();
    start_cheat_caller_address(contract_address, student);
    contract.enroll_in_exam(0_u256);
    // This should panic
    contract.enroll_in_exam(0_u256);
    stop_cheat_caller_address(student);
}

#[test]
fn test_exam_status_toggle() {
    let creator: ContractAddress = 99999.try_into().unwrap();
    let (contract, _, _) = deploy();
    let contract_address = contract.contract_address;
    start_cheat_caller_address(contract_address, creator);

    contract.create_exam("Physics", 75_u64, true, false, 0, 50);

    // Toggle status
    contract.toggle_exam_status(0_u256);
    let exam = contract.get_exam(0_u256);
    assert(exam.is_active == false, 'STATUS_SHOULD_BE_INACTIVE');

    // Toggle back
    contract.toggle_exam_status(0_u256);
    let exam = contract.get_exam(0_u256);
    assert(exam.is_active == true, 'STATUS_SHOULD_BE_ACTIVE');

    stop_cheat_caller_address(creator);
}

#[test]
#[should_panic]
fn test_non_creator_toggle_status() {
    let creator: ContractAddress = 11111.try_into().unwrap();
    let non_creator: ContractAddress = 22222.try_into().unwrap();
    let (contract, _, _) = deploy();
    let contract_address = contract.contract_address;
    start_cheat_caller_address(contract_address, creator);
    contract.create_exam("Chemistry", 50_u64, true, false, 0, 50);
    stop_cheat_caller_address(creator);

    start_cheat_caller_address(contract_address, non_creator);
    // This should panic
    contract.toggle_exam_status(0_u256);
    stop_cheat_caller_address(non_creator);
}

#[test]
#[should_panic]
fn test_add_question_to_inactive_exam() {
    let creator: ContractAddress = 33333.try_into().unwrap();
    let (contract, _, _) = deploy();
    let contract_address = contract.contract_address;
    start_cheat_caller_address(contract_address, creator);

    contract.create_exam("Biology", 30_u64, false, false, 0, 50);

    // This should panic
    contract.add_questions(10, 0_u256, "123456");

    stop_cheat_caller_address(creator);
}

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

#[test]
fn test_successful_erc20_transfer() {
    let (contract, erc20_address, _) = deploy();

    // let erc20_addresss = erc20_address.contract_address;
    let owner: ContractAddress = contract_address_const::<'owner'>();

    let beneficiary: ContractAddress = contract_address_const::<'bene'>();
    let contract_address = contract.contract_address;

    // start_cheat_caller_address(contract_address, owner);
    // contract.collect_exam_fee(owner, 10);

    let token_dispatcher = IMockUsdcDispatcher { contract_address: erc20_address };
    let sender_initial_balance = token_dispatcher.get_balance(owner);
    let beneficiary_initial_balance = token_dispatcher.get_balance(beneficiary);
    println!("Initial balance of sender: {}", sender_initial_balance);
    println!("Initial balance of beneficiary: {}", beneficiary_initial_balance);

    // Approve the contract address as spender:
    start_cheat_caller_address(erc20_address, owner);
    token_dispatcher.approve_user(contract_address, 10000);
    stop_cheat_caller_address(erc20_address);

    // Now simulate the approved spender making the transferFrom call:
    start_cheat_caller_address(erc20_address, contract_address);
    let success = token_dispatcher.transferFrom(owner, beneficiary, 1850);
    stop_cheat_caller_address(erc20_address);
    assert(success, 'Unsuccessful Transfer');

    let sender_final_balance = token_dispatcher.get_balance(owner);
    let beneficiary_final_balance = token_dispatcher.get_balance(beneficiary);
    println!("Final balance of sender: {}", sender_final_balance);
    println!("Final balance of beneficiary: {}", beneficiary_final_balance);

    assert(beneficiary_final_balance > beneficiary_initial_balance, 'transfer beneficiary error');
    assert(sender_final_balance < sender_initial_balance, 'transfer senders error');
}


#[test]
fn test_successful_collect_exam_fee() {
    // Deploy the contracts and extract the ERC20 address.
    let (contract, erc20_address, _) = deploy();

    // Owner and fee recipient addresses.
    let owner: ContractAddress = contract_address_const::<'owner'>();
    let skillnet_revenue_account: ContractAddress = contract_address_const::<'skillnet_account'>();

    // The address of the current contract which will be the approved spender.
    let contract_address = contract.contract_address;

    // Create a dispatcher for the ERC20 contract.
    let token_dispatcher = IMockUsdcDispatcher { contract_address: erc20_address };

    // Get initial balances.
    let sender_initial_balance = token_dispatcher.get_balance(owner);
    let beneficiary_initial_balance = token_dispatcher.get_balance(contract_address);
    println!("Initial balance of sender: {}", sender_initial_balance);
    println!("Initial balance of skillnet_revenue_account: {}", beneficiary_initial_balance);

    // Step 1: Approve the contract address (the approved spender) from the owner's account.
    start_cheat_caller_address(erc20_address, owner);
    // Make sure approve_user sets the allowance mapping for (owner, contract_address) to 10000.
    token_dispatcher.approve_user(contract_address, 10000);
    stop_cheat_caller_address(erc20_address);

    // Debug: Print allowance to verify it's set correctly.
    let approved_amount = token_dispatcher.get_allowance(owner, contract_address);
    println!("Approved allowance for contract: {}", approved_amount);
    // You can add an assertion if needed:
    assert(approved_amount >= 1850, 'Allowance not high enough');

    // Step 2: Now simulate the approved spender (the contract) making the transfer.
    start_cheat_caller_address(erc20_address, contract_address);
    // Assuming collect_exam_fee internally calls transferFrom(owner, skillnet_revenue_account,
    // fee_amount)
    // and that it uses the caller as the approved spender.
    contract.collect_exam_fee(owner, 1850, contract_address);
    stop_cheat_caller_address(erc20_address);

    // Get final balances.
    let sender_final_balance = token_dispatcher.get_balance(owner);
    let beneficiary_final_balance = token_dispatcher.get_balance(contract_address);
    println!("Final balance of sender: {}", sender_final_balance);
    println!("Final balance of skillnet_revenue_account: {}", beneficiary_final_balance);

    // Assertions to verify the fee transfer.
    assert(beneficiary_final_balance > beneficiary_initial_balance, 'Transfer  failed');
    assert(sender_final_balance < sender_initial_balance, 'Sender balance err');
}

#[test]
fn test_enrollment_upload_result() {
    let (contract, erc20_address, _) = deploy();
    let contract_address = contract.contract_address;
    let student: ContractAddress = contract_address_const::<'owner'>();
    let skillnet_revenue_account: ContractAddress = contract_address_const::<'skillnet_account'>();

    contract.create_exam("Math", 60_u64, true, true, 100, 50);

    let token_dispatcher = IMockUsdcDispatcher { contract_address: erc20_address };

    start_cheat_caller_address(erc20_address, student);
    // Make sure approve_user sets the allowance mapping for (owner, contract_address) to 10000.
    token_dispatcher.mint(contract_address, 50000);
    stop_cheat_caller_address(erc20_address);

    // Test student enrollment
    start_cheat_caller_address(erc20_address, student);
    // Make sure approve_user sets the allowance mapping for (owner, contract_address) to 10000.
    token_dispatcher.approve_user(contract_address, 10000);
    token_dispatcher.approve_user(skillnet_revenue_account, 10000);
    stop_cheat_caller_address(erc20_address);

    // // Step 2: Now simulate the approved spender (the contract) making the transfer.
    start_cheat_caller_address(contract_address, student);
    contract.enroll_in_exam(0_u256);
    stop_cheat_caller_address(student);

    // // Verify enrollment
    let is_enrolled = contract.is_enrolled(0_u256, student);
    assert(is_enrolled, 'STUDENT_SHOULD_BE_ENROLLED');

    // // Verify stats
    let stats = contract.get_exam_stats(0_u256);
    assert(stats.total_students == 1_u256, 'STUDENT_COUNT_MISMATCH');

    let submit_time = get_block_timestamp();

    contract.upload_student_result(student, 0, "98057", true);

    let result = contract.get_student_result(0, student);

    assert(result.submit_timestamp == submit_time, 'Result not uploaded');
}
#[test]
fn test_enrollment_result_not_uploaded() {
    let (contract, erc20_address, _) = deploy();
    let contract_address = contract.contract_address;
    let student: ContractAddress = contract_address_const::<'owner'>();
    let skillnet_revenue_account: ContractAddress = contract_address_const::<'skillnet_account'>();

    contract.create_exam("Math", 60_u64, true, true, 100, 50);

    let token_dispatcher = IMockUsdcDispatcher { contract_address: erc20_address };

    start_cheat_caller_address(erc20_address, student);
    // Make sure approve_user sets the allowance mapping for (owner, contract_address) to 10000.
    token_dispatcher.mint(contract_address, 50000);
    stop_cheat_caller_address(erc20_address);

    // Test student enrollment
    start_cheat_caller_address(erc20_address, student);
    // Make sure approve_user sets the allowance mapping for (owner, contract_address) to 10000.
    token_dispatcher.approve_user(contract_address, 10000);
    token_dispatcher.approve_user(skillnet_revenue_account, 10000);
    stop_cheat_caller_address(erc20_address);

    // // Step 2: Now simulate the approved spender (the contract) making the transfer.
    start_cheat_caller_address(contract_address, student);
    contract.enroll_in_exam(0_u256);
    stop_cheat_caller_address(student);

    // // Verify enrollment
    let is_enrolled = contract.is_enrolled(0_u256, student);
    assert(is_enrolled, 'STUDENT_SHOULD_BE_ENROLLED');

    // // Verify stats
    let stats = contract.get_exam_stats(0_u256);
    assert(stats.total_students == 1_u256, 'STUDENT_COUNT_MISMATCH');

    let success = contract.is_result_out(0);

    assert(success == false, 'Result not uploaded');
}

#[test]
fn test_enrollment_process_claim_nft() {
    let (contract, erc20_address, nft_address) = deploy();
    let contract_address = contract.contract_address;
    let student: ContractAddress = contract_address_const::<'owner'>();
    let skillnet_revenue_account: ContractAddress = contract_address_const::<'skillnet_account'>();

    contract.create_exam("Math", 60_u64, true, true, 100, 50);

    let token_dispatcher = IMockUsdcDispatcher { contract_address: erc20_address };

    start_cheat_caller_address(erc20_address, student);
    // Make sure approve_user sets the allowance mapping for (owner, contract_address) to 10000.
    token_dispatcher.mint(contract_address, 50000);
    stop_cheat_caller_address(erc20_address);

    // Test student enrollment
    start_cheat_caller_address(erc20_address, student);
    // Make sure approve_user sets the allowance mapping for (owner, contract_address) to 10000.
    token_dispatcher.approve_user(contract_address, 10000);
    token_dispatcher.approve_user(skillnet_revenue_account, 10000);
    stop_cheat_caller_address(erc20_address);

    // // Step 2: Now simulate the approved spender (the contract) making the transfer.
    start_cheat_caller_address(contract_address, student);
    contract.enroll_in_exam(0_u256);
    stop_cheat_caller_address(student);

    // // Verify enrollment
    let is_enrolled = contract.is_enrolled(0_u256, student);
    assert(is_enrolled, 'STUDENT_SHOULD_BE_ENROLLED');

    // // Verify stats
    let stats = contract.get_exam_stats(0_u256);
    assert(stats.total_students == 1_u256, 'STUDENT_COUNT_MISMATCH');

    contract.upload_student_result(student, 0, "98057", true);

    start_cheat_caller_address(contract_address, student);
    contract.claim_certificate(0_u256);
    stop_cheat_caller_address(student);

    let success = contract.student_have_nft(0, 0, nft_address, student);
    assert(success, 'Student do not have NFT');
}

#[test]
#[should_panic]
fn test_enrollment_process_claim_nft_not_eligible() {
    let (contract, erc20_address, nft_address) = deploy();
    let contract_address = contract.contract_address;
    let student: ContractAddress = contract_address_const::<'owner'>();
    let skillnet_revenue_account: ContractAddress = contract_address_const::<'skillnet_account'>();

    contract.create_exam("Math", 60_u64, true, true, 100, 50);

    let token_dispatcher = IMockUsdcDispatcher { contract_address: erc20_address };

    start_cheat_caller_address(erc20_address, student);
    // Make sure approve_user sets the allowance mapping for (owner, contract_address) to 10000.
    token_dispatcher.mint(contract_address, 50000);
    stop_cheat_caller_address(erc20_address);

    // Test student enrollment
    start_cheat_caller_address(erc20_address, student);
    // Make sure approve_user sets the allowance mapping for (owner, contract_address) to 10000.
    token_dispatcher.approve_user(contract_address, 10000);
    token_dispatcher.approve_user(skillnet_revenue_account, 10000);
    stop_cheat_caller_address(erc20_address);

    // // Step 2: Now simulate the approved spender (the contract) making the transfer.
    start_cheat_caller_address(contract_address, student);
    contract.enroll_in_exam(0_u256);
    stop_cheat_caller_address(student);

    // // Verify enrollment
    let is_enrolled = contract.is_enrolled(0_u256, student);
    assert(is_enrolled, 'STUDENT_SHOULD_BE_ENROLLED');

    // // Verify stats
    let stats = contract.get_exam_stats(0_u256);
    assert(stats.total_students == 1_u256, 'STUDENT_COUNT_MISMATCH');

    contract.upload_student_result(student, 0, "98057", true);

    start_cheat_caller_address(contract_address, student);
    contract.claim_certificate(0_u256);
    stop_cheat_caller_address(student);

    let success = contract.student_have_nft(0, 0, nft_address, student);
    assert(!success, 'Student do not have NFT');
}

#[test]
fn test_contract_upgrade() {
    let (exam, _, _) = deploy();
    let dispatcher = IUpgradeableDispatcher { contract_address: exam.contract_address };
    // to change the class hash, we feign this.
    let new_class_hash = declare("MockUsdc").unwrap().contract_class().class_hash;

    cheat_caller_address(exam.contract_address, OWNER(), CheatSpan::TargetCalls(1));

    let mut spy = spy_events();
    dispatcher.upgrade(*new_class_hash);
    let event = UpgradeEvent::Upgraded(Upgraded { class_hash: *new_class_hash });

    spy.assert_emitted(@array![(exam.contract_address, event)]);
}

#[test]
#[should_panic(expected: 'UNAUTHORIZED CALLER')]
fn test_contract_upgrade_should_panic_on_non_owner() {
    let (exam, _, _) = deploy();
    let dispatcher = IUpgradeableDispatcher { contract_address: exam.contract_address };
    // to change the class hash, we feign this.
    let new_class_hash = declare("MockUsdc").unwrap().contract_class().class_hash;

    let non_owner: ContractAddress = 'NON_OWNER'.try_into().unwrap();
    cheat_caller_address(exam.contract_address, non_owner, CheatSpan::TargetCalls(1));
    dispatcher.upgrade(*new_class_hash);
}

#[test]
fn test_get_all_exams() {
    let (contract, _, _) = deploy();

    contract.create_exam("Math", 60_u64, true, true, 100, 50);
    contract.create_exam("Science", 60_u64, true, true, 100, 50);
    contract.create_exam("History", 60_u64, true, true, 100, 50);

    let exams: Array<Exam> = contract.get_all_exams();
    assert(exams.len() == 3, 'EXAMS_COUNT_MISMATCH');
    let exam0: Exam = exams.at(0).clone();
    let exam1: Exam = exams.at(1).clone();
    let exam2: Exam = exams.at(2).clone();

    assert(exam0.title == "Math", 'EXAM0_TITLE_MISMATCH');
    assert(exam1.title == "Science", 'EXAM1_TITLE_MISMATCH');
    assert(exam2.title == "History", 'EXAM2_TITLE_MISMATCH');
}

#[test]
fn test_get_students_enrolled_in_exam() {
    let (contract, _, _) = deploy();
    let contract_address = contract.contract_address;
    contract.create_exam("Math", 60_u64, true, false, 0, 50);

    // Test student enrollment
    let student1: ContractAddress = 12345.try_into().unwrap();
    start_cheat_caller_address(contract_address, student1);
    contract.enroll_in_exam(0_u256);
    stop_cheat_caller_address(contract_address);

    let student2: ContractAddress = 67890.try_into().unwrap();
    start_cheat_caller_address(contract_address, student2);
    contract.enroll_in_exam(0_u256);
    stop_cheat_caller_address(contract_address);

    let students: Array<ContractAddress> = contract.get_students_enrolled_in_exam(0_u256);
    assert(students.len() == 2, 'STUDENTS_COUNT_MISMATCH');
    assert(*students.at(0) == student1, 'STUDENT1_MISMATCH');
    assert(*students.at(1) == student2, 'STUDENT2_MISMATCH');
}

#[test]
fn test_submit_exam_successfully() {
    let (contract, _, _) = deploy();
    let contract_address = contract.contract_address;
    let exam = contract.create_exam("Introduction Exams", 5, true, false, 0, 50);
    let exam_data = contract.get_exam(exam.exam_id);

    contract.add_questions(10, 0_u256, "123456");

    let student: ContractAddress = 12345.try_into().unwrap();
    start_cheat_caller_address(contract_address, student);
    contract.enroll_in_exam(0_u256);

    let submit_time = get_block_timestamp();
    contract.submit_exam(0_u256, "123456", "123456");

    stop_cheat_caller_address(student);

    let exams: Array<ExamSubmitted> = contract.get_exams_submitted_by_student(student);
    assert(exams.len() == 1, 'EXAMS_COUNT_MISMATCH');
    let exam0: ExamSubmitted = exams.at(0).clone();
    assert(exam0.exam_id == 0_u256, 'EXAM0_ID_MISMATCH');
    assert(exam0.student_address == student, 'EXAM0_STUDENT_MISMATCH');
    assert(exam0.submit_timestamp == submit_time, 'EXAM0_SUBMIT_TIMESTAMP_MISMATCH');
    assert(exam0.exam_uri == "123456", 'EXAM0_EXAM_URI_MISMATCH');
    assert(exam0.exam_video == "123456", 'EXAM0_EXAM_VIDEO_MISMATCH');

    let submits: Array<ExamSubmitted> = contract.get_all_submits_for_exam(0_u256);
    assert(submits.len() == 1, 'SUBMITS_COUNT_MISMATCH');
    let submit0: ExamSubmitted = submits.at(0).clone();
    assert(submit0.exam_id == 0_u256, 'SUBMIT0_ID_MISMATCH');
    assert(submit0.student_address == student, 'SUBMIT0_STUDENT_MISMATCH');
    assert(submit0.submit_timestamp == submit_time, 'time stamp mismatch');
    assert(submit0.exam_uri == "123456", 'SUBMIT0_EXAM_URI_MISMATCH');
    assert(submit0.exam_video == "123456", 'SUBMIT0_EXAM_VIDEO_MISMATCH');
}

#[test]
#[should_panic(expected: 'EXAM_NOT_FOUND')]
fn test_submit_exam_should_panic_if_exam_doesnt_exist() {
    let (contract, _, _) = deploy();
    let contract_address = contract.contract_address;

    contract.add_questions(10, 0_u256, "123456");

    let student: ContractAddress = 12345.try_into().unwrap();
    start_cheat_caller_address(contract_address, student);
    contract.enroll_in_exam(0_u256);

    let submit_time = get_block_timestamp();
    contract.submit_exam(0_u256, "123456", "123456");

    stop_cheat_caller_address(student);
}

#[test]
#[should_panic(expected: 'STUDENT_NOT_ENROLLED')]
fn test_submit_exam_should_panic_if_student_not_enrolled() {
    let (contract, _, _) = deploy();
    let contract_address = contract.contract_address;
    let exam = contract.create_exam("Introduction Exams", 5, true, false, 0, 50);
    let exam_data = contract.get_exam(exam.exam_id);

    contract.add_questions(10, 0_u256, "123456");

    let student: ContractAddress = 12345.try_into().unwrap();
    start_cheat_caller_address(contract_address, student);

    let submit_time = get_block_timestamp();
    contract.submit_exam(0_u256, "123456", "123456");

    stop_cheat_caller_address(student);
}


#[test]
#[should_panic(expected: 'EXAM_ALREADY_SUBMITTED')]
fn test_submit_exam_should_panic_if_double_submitting() {
    let (contract, _, _) = deploy();
    let contract_address = contract.contract_address;
    let exam = contract.create_exam("Introduction Exams", 5, true, false, 0, 50);
    let exam_data = contract.get_exam(exam.exam_id);

    contract.add_questions(10, 0_u256, "123456");

    let student: ContractAddress = 12345.try_into().unwrap();
    start_cheat_caller_address(contract_address, student);
    contract.enroll_in_exam(0_u256);

    let submit_time = get_block_timestamp();
    contract.submit_exam(0_u256, "123456", "123456");
    contract.submit_exam(0_u256, "123456", "123456");

    stop_cheat_caller_address(student);
}


#[test]
#[should_panic(expected: 'EXAM_DURATION_EXPIRED')]
fn test_submit_exam_should_panic_if_exam_duration_expired() {
    let (contract, _, _) = deploy();
    let contract_address = contract.contract_address;
    let exam = contract.create_exam("Introduction Exams", 5, true, false, 0, 50);
    let exam_data = contract.get_exam(exam.exam_id);

    contract.add_questions(10, 0_u256, "123456");

    let student: ContractAddress = 12345.try_into().unwrap();
    start_cheat_caller_address(contract_address, student);
    contract.enroll_in_exam(0_u256);

    start_cheat_block_timestamp(contract_address, exam.duration + 1);
    contract.submit_exam(0_u256, "123456", "123456");

    stop_cheat_caller_address(student);
}
