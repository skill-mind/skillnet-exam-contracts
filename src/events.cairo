#[event]
#[derive(Drop, starknet::Event)]
enum Event {
    ExamCreated: ExamCreated,
    QuestionAdded: QuestionAdded,
    StudentEnrolled: StudentEnrolled,
    ExamStatusChanged: ExamStatusChanged,
    CourseCertClaimed: CourseCertClaimed,
    #[flat]
    AccessControlEvent: AccessControlComponent::Event,
    #[flat]
    SRC5Event: SRC5Component::Event,
}

#[derive(Drop, Serde, starknet::Event)]
pub struct ExamCreated {
    #[key]
    exam_id: u256,
    title: ByteArray,
    creator: ContractAddress,
    datetime: u64,
    duration: u64,
    is_active: bool,
}

#[derive(Drop, Serde, starknet::Event)]
pub struct QuestionAdded {
    #[key]
    exam_id: u256,
    question_id: u256,
}

#[derive(Drop, Serde, starknet::Event)]
pub struct StudentEnrolled {
    #[key]
    exam_id: u256,
    student: ContractAddress,
}

#[derive(Drop, Serde, starknet::Event)]
pub struct ExamStatusChanged {
    #[key]
    exam_id: u256,
    new_status: bool,
}

