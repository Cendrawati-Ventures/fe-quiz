enum ExamStudentStatus {
  active('ACTIVE'),
  leftApp('LEFT_APP'),
  finished('FINISHED'),
  offline('OFFLINE');

  const ExamStudentStatus(this.value);

  final String value;

  static ExamStudentStatus fromValue(String? value) {
    final normalized = value?.trim().toUpperCase();
    for (final status in ExamStudentStatus.values) {
      if (status.value == normalized) {
        return status;
      }
    }
    return ExamStudentStatus.offline;
  }
}
