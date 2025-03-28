use starknet::ContractAddress;
use crate::base::types::{Exam, ExamStats, Question};

#[starknet::interface]
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
    ) -> Exam;

    // Adds a question to an exam and returns the question ID
    fn add_question(
        ref self: TContractState,
        exam_id: u256,
        question: ByteArray,
        option_a: ByteArray,
        option_b: ByteArray,
        option_c: ByteArray,
        option_d: ByteArray,
        correct_option: u8,
    ) -> u256;
    // Enrolls the caller in an exam
    fn enroll_in_exam(ref self: TContractState, exam_id: u256);

    // Gets exam details by ID
    fn get_exam(ref self: TContractState, exam_id: u256) -> Exam;

    // Gets exam statistics by ID
    fn get_exam_stats(ref self: TContractState, exam_id: u256) -> ExamStats;

    // Gets a specific question from an exam
    fn get_question(ref self: TContractState, exam_id: u256, question_id: u256) -> Question;

    // Checks if a student is enrolled in an exam
    fn is_enrolled(ref self: TContractState, exam_id: u256, student: ContractAddress) -> bool;

    // Toggles an exam's active status
    fn toggle_exam_status(ref self: TContractState, exam_id: u256);

    fn student_have_nft(
        ref self: TContractState, student: ContractAddress, exam_id: u256, nft_contract_address: ContractAddress,
    ) -> bool;

    fn upload_student_score(
        ref self: TContractState,
        address: ContractAddress,
        exam_id: u256,
        score: u256,
        passMark: u256,
    ) -> bool;


    fn claim_certificate(ref self: TContractState, exam_id: u256);

    fn is_result_result(ref self: TContractState, exam_id: u256);

    fn collect_exam_fee(
        ref self: TContractState, payer: ContractAddress, amount: u256,
    );
}



