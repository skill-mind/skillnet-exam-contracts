use starknet::ContractAddress;

#[derive(Drop, Serde, starknet::Store)]
pub struct Exam {
    pub exam_id: u256,
    pub title: ByteArray,
    pub creator: ContractAddress,
    pub datetime: u64,
    pub duration: u64,
    pub is_active: bool,
    pub is_paid: bool,
    pub price: u256,
}

#[derive(Drop, Serde, starknet::Store)]
pub struct Questions {
    pub exam_id: u256,
    pub questions_uri: ByteArray,
}

#[derive(Drop, Serde, starknet::Store)]
pub struct ExamStats {
    pub questions_uri: ByteArray,
    pub total_students: u256,
}

#[derive(Drop, Serde, starknet::Store)]
pub struct Student {
    address: ContractAddress,
    exam_Id: u256,
    is_registered: bool,
}
