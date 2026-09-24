/// Career-readiness checklist, stored on the user document under
/// `users/{uid}.careerChecklist`.
class CareerChecklistModel {
  final bool cvCreated;
  final bool githubCreated;

  /// 0–3 projects completed.
  final int projectsCompletedCount;
  final bool mockInterviewAttended;
  final bool jobsApplied;

  static const int requiredProjects = 3;

  const CareerChecklistModel({
    this.cvCreated = false,
    this.githubCreated = false,
    this.projectsCompletedCount = 0,
    this.mockInterviewAttended = false,
    this.jobsApplied = false,
  });

  factory CareerChecklistModel.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const CareerChecklistModel();
    return CareerChecklistModel(
      cvCreated: map['cvCreated'] == true,
      githubCreated: map['githubCreated'] == true,
      projectsCompletedCount:
          (int.tryParse('${map['projectsCompletedCount'] ?? 0}') ?? 0)
              .clamp(0, requiredProjects),
      mockInterviewAttended: map['mockInterviewAttended'] == true,
      jobsApplied: map['jobsApplied'] == true,
    );
  }

  Map<String, dynamic> toMap() => {
        'cvCreated': cvCreated,
        'githubCreated': githubCreated,
        'projectsCompletedCount': projectsCompletedCount,
        'mockInterviewAttended': mockInterviewAttended,
        'jobsApplied': jobsApplied,
      };

  bool get projectsCompleted => projectsCompletedCount >= requiredProjects;

  /// Number of the five checklist items done.
  int get completedCount => [
        cvCreated,
        githubCreated,
        projectsCompleted,
        mockInterviewAttended,
        jobsApplied,
      ].where((done) => done).length;

  static const int totalItems = 5;

  double get percentage => (completedCount / totalItems) * 100;

  bool get isJobReady => completedCount == totalItems;

  CareerChecklistModel copyWith({
    bool? cvCreated,
    bool? githubCreated,
    int? projectsCompletedCount,
    bool? mockInterviewAttended,
    bool? jobsApplied,
  }) =>
      CareerChecklistModel(
        cvCreated: cvCreated ?? this.cvCreated,
        githubCreated: githubCreated ?? this.githubCreated,
        projectsCompletedCount:
            (projectsCompletedCount ?? this.projectsCompletedCount)
                .clamp(0, requiredProjects),
        mockInterviewAttended:
            mockInterviewAttended ?? this.mockInterviewAttended,
        jobsApplied: jobsApplied ?? this.jobsApplied,
      );
}
