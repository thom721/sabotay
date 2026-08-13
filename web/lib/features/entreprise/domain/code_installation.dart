class CodeInstallation {
  final String? code;
  final bool utilise;

  const CodeInstallation({required this.code, required this.utilise});

  factory CodeInstallation.fromJson(Map<String, dynamic> json) => CodeInstallation(
        code: json['code'] as String?,
        utilise: json['utilise'] as bool,
      );
}
