use starknet::ContractAddress;
use crate::base::types::{Exam, ExamResult, ExamStats};


#[starknet::interface]
pub trait IExam<TContractState> {
    // Creates a new exam and returns the created exam
    fn create_exam(
        ref self: TContractState,
        title: ByteArray,
        duration: u64,
        is_active: bool,
        is_paid: bool,
        price: u256,
        passmark_percent: u16,
    ) -> Exam;

    // Adds a question to an exam and returns the question ID
    // Uploads all questions for an exam using an IPFS URI
    fn add_questions(
        ref self: TContractState, total_questions: u32, exam_id: u256, questions_uri: ByteArray,
    );

    // Enrolls the caller in an exam
    fn enroll_in_exam(ref self: TContractState, exam_id: u256);

    // Gets exam details by ID
    fn get_exam(ref self: TContractState, exam_id: u256) -> Exam;

    // Gets exam statistics by ID
    fn get_exam_stats(ref self: TContractState, exam_id: u256) -> ExamStats;

    fn get_questions(ref self: TContractState, exam_id: u256) -> ByteArray;

    // Checks if a student is enrolled in an exam
    fn is_enrolled(ref self: TContractState, exam_id: u256, student: ContractAddress) -> bool;

    // Toggles an exam's active status
    fn toggle_exam_status(ref self: TContractState, exam_id: u256);

    fn student_have_nft(
        ref self: TContractState,
        token_id: u256,
        exam_id: u256,
        nft_contract_address: ContractAddress,
        student: ContractAddress,
    ) -> bool;

    fn upload_student_result(
        ref self: TContractState,
        address: ContractAddress,
        exam_id: u256,
        result_uri: ByteArray,
        passed: bool,
    ) -> bool;

    fn get_student_result(
        ref self: TContractState, exam_id: u256, address: ContractAddress,
    ) -> ExamResult;


    fn claim_certificate(ref self: TContractState, exam_id: u256);

    fn is_result_out(ref self: TContractState, exam_id: u256) -> bool;

    fn collect_exam_fee(
        ref self: TContractState, payer: ContractAddress, amount: u256, recipient: ContractAddress,
    );
    fn get_addresses(ref self: TContractState) -> (ContractAddress, ContractAddress);
}

