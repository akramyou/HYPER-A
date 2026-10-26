class BranchConfig {
  const BranchConfig({
    this.branchId = '',
    this.orgCode = '',
    this.branchName = '',
    this.isConfigured = false,
    this.notificationsEnabled = true,
    this.defaultMinStock = 5,
    this.columnMapping = const <String, int>{},
  });

  final String branchId;
  final String orgCode;
  final String branchName;
  final bool isConfigured;
  final bool notificationsEnabled;
  final double defaultMinStock;
  final Map<String, int> columnMapping;

  factory BranchConfig.fromJson(Map<String, dynamic> json) {
    final rawMapping = json['columnMapping'];
    final mapping = <String, int>{};
    if (rawMapping is Map) {
      for (final entry in rawMapping.entries) {
        final value = entry.value;
        if (value is num) mapping[entry.key.toString()] = value.toInt();
      }
    }
    return BranchConfig(
      branchId: (json['branchId'] ?? '').toString(),
      orgCode: (json['orgCode'] ?? '').toString(),
      branchName: (json['branchName'] ?? '').toString(),
      isConfigured: json['isConfigured'] == true,
      notificationsEnabled: json['notificationsEnabled'] != false,
      defaultMinStock: (json['defaultMinStock'] as num?)?.toDouble() ?? 5,
      columnMapping: mapping,
    );
  }

  Map<String, dynamic> toJson() => {
        'branchId': branchId,
        'orgCode': orgCode,
        'branchName': branchName,
        'isConfigured': isConfigured,
        'notificationsEnabled': notificationsEnabled,
        'defaultMinStock': defaultMinStock,
        'columnMapping': columnMapping,
      };
}
