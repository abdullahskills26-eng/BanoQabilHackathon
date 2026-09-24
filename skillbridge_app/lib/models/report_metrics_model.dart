/// Campus statistics shown on the coordinator dashboard.
///
/// Computed rather than stored — see
/// [FirebaseService.fetchCampusMetrics] and the matching backend endpoint
/// `GET /api/v1/coordinator/metrics/{campus_id}`.
class ReportMetricsModel {
  final int applicationsThisMonth;
  final int acceptedStudentsCount;
  final double averageAttendancePercentage;
  final int pendingAssignmentsCount;

  /// Extra context the dashboard shows alongside the four headline numbers.
  final int totalApplications;
  final int activeBatches;
  final int totalStudents;

  const ReportMetricsModel({
    this.applicationsThisMonth = 0,
    this.acceptedStudentsCount = 0,
    this.averageAttendancePercentage = 0,
    this.pendingAssignmentsCount = 0,
    this.totalApplications = 0,
    this.activeBatches = 0,
    this.totalStudents = 0,
  });

  factory ReportMetricsModel.fromMap(Map<String, dynamic> map) {
    return ReportMetricsModel(
      applicationsThisMonth:
          int.tryParse('${map['applicationsThisMonth'] ?? 0}') ?? 0,
      acceptedStudentsCount:
          int.tryParse('${map['acceptedStudentsCount'] ?? 0}') ?? 0,
      averageAttendancePercentage:
          double.tryParse('${map['averageAttendancePercentage'] ?? 0}') ?? 0,
      pendingAssignmentsCount:
          int.tryParse('${map['pendingAssignmentsCount'] ?? 0}') ?? 0,
      totalApplications:
          int.tryParse('${map['totalApplications'] ?? 0}') ?? 0,
      activeBatches: int.tryParse('${map['activeBatches'] ?? 0}') ?? 0,
      totalStudents: int.tryParse('${map['totalStudents'] ?? 0}') ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'applicationsThisMonth': applicationsThisMonth,
        'acceptedStudentsCount': acceptedStudentsCount,
        'averageAttendancePercentage': averageAttendancePercentage,
        'pendingAssignmentsCount': pendingAssignmentsCount,
        'totalApplications': totalApplications,
        'activeBatches': activeBatches,
        'totalStudents': totalStudents,
      };

  String get formattedAttendance =>
      '${averageAttendancePercentage.toStringAsFixed(0)}%';

  /// Share of all applications that were accepted.
  double get acceptanceRate {
    if (totalApplications == 0) return 0;
    return (acceptedStudentsCount / totalApplications) * 100;
  }
}
