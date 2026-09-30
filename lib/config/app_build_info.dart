class AppBuildInfo {
  const AppBuildInfo._();

  static const gitSha = String.fromEnvironment(
    'GIT_SHA',
    defaultValue: 'local',
  );

  static const buildTime = String.fromEnvironment(
    'BUILD_TIME',
    defaultValue: 'dev',
  );

  static const version = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: 'local',
  );
}
